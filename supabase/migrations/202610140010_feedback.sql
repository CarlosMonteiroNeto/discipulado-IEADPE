-- Serialize current actor authorization before touching receipts or business rows.
CREATE FUNCTION private.change_feedback(command_name text,operation_id uuid,payload jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE receipt private.mutation_receipts; digest text; result jsonb; feedback_id uuid; message_text text; status_text text;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'unauthorized' USING ERRCODE='42501'; END IF;
 PERFORM private.lock_access(ARRAY[auth.uid()]);
 IF NOT EXISTS(SELECT FROM auth.users WHERE id=auth.uid()) OR
  (command_name='update_feedback' AND NOT private.is_global_manager()) THEN
  RAISE EXCEPTION 'forbidden' USING ERRCODE='42501'; END IF;
 IF operation_id IS NULL OR payload IS NULL OR jsonb_typeof(payload)<>'object' THEN
  RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
 IF command_name='submit_feedback' THEN
  IF payload-'message'<>'{}'::jsonb OR jsonb_typeof(payload->'message') IS DISTINCT FROM 'string' THEN
   RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
  -- Match Dart String.trim's Unicode whitespace set; length() counts code points.
  message_text:=btrim(payload->>'message',E'\t\n\v\f\r '||chr(133)||chr(160)||chr(5760)||
   chr(8192)||chr(8193)||chr(8194)||chr(8195)||chr(8196)||chr(8197)||chr(8198)||chr(8199)||chr(8200)||chr(8201)||chr(8202)||
   chr(8232)||chr(8233)||chr(8239)||chr(8287)||chr(12288)||chr(65279));
  IF length(message_text) NOT BETWEEN 1 AND 5000 THEN RAISE EXCEPTION 'invalid_message' USING ERRCODE='22023'; END IF;
 ELSE
  IF payload-ARRAY['id','status']<>'{}'::jsonb OR jsonb_typeof(payload->'id') IS DISTINCT FROM 'string' OR
   jsonb_typeof(payload->'status') IS DISTINCT FROM 'string' THEN RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
  feedback_id:=(payload->>'id')::uuid; status_text:=payload->>'status';
  IF status_text NOT IN ('pending','read','resolved') THEN RAISE EXCEPTION 'invalid_status' USING ERRCODE='22023'; END IF;
 END IF;
 digest:=encode(sha256(convert_to(payload::text,'UTF8')),'hex');
 SELECT * INTO receipt FROM private.mutation_receipts r WHERE r.actor_uid=auth.uid() AND r.operation_id=change_feedback.operation_id;
 IF FOUND THEN
  IF receipt.command<>command_name OR receipt.payload_hash<>digest THEN RAISE EXCEPTION 'operation_conflict' USING ERRCODE='22023'; END IF;
  RETURN receipt.result;
 END IF;
 IF command_name='submit_feedback' THEN
  INSERT INTO public.feedback(message,created_by,user_email,user_name)
   SELECT message_text,u.id,u.email,p.display_name FROM auth.users u LEFT JOIN public.profiles p ON p.id=u.id WHERE u.id=auth.uid()
   RETURNING id INTO feedback_id;
 ELSE
  UPDATE public.feedback SET status=status_text WHERE id=feedback_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'feedback_not_found' USING ERRCODE='22023'; END IF;
 END IF;
 result:=jsonb_build_object('id',feedback_id);
 INSERT INTO private.mutation_receipts(actor_uid,operation_id,command,payload_hash,result)
 VALUES(auth.uid(),operation_id,command_name,digest,result);
 RETURN result;
END $$;
CREATE FUNCTION public.ieadpe_submit_feedback(operation_id uuid,payload jsonb) RETURNS jsonb
LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$ SELECT private.change_feedback('submit_feedback',operation_id,payload) $$;
CREATE FUNCTION public.ieadpe_update_feedback(operation_id uuid,payload jsonb) RETURNS jsonb
LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$ SELECT private.change_feedback('update_feedback',operation_id,payload) $$;
REVOKE ALL ON FUNCTION private.change_feedback(text,uuid,jsonb) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.ieadpe_submit_feedback(uuid,jsonb),public.ieadpe_update_feedback(uuid,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.ieadpe_submit_feedback(uuid,jsonb),public.ieadpe_update_feedback(uuid,jsonb) TO authenticated;
