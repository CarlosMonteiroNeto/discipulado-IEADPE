CREATE FUNCTION private.business_today() RETURNS date LANGUAGE sql STABLE SET search_path='' AS $$
 SELECT (now() AT TIME ZONE 'America/Sao_Paulo')::date $$;
CREATE FUNCTION private.report_week(server_instant timestamptz) RETURNS date
LANGUAGE sql IMMUTABLE SET search_path='' AS $$
 SELECT date_trunc('week',local_time)::date - CASE
 WHEN extract(isodow FROM local_time)=7 AND local_time::time>=time '20:00' THEN 0 ELSE 7 END
 FROM (SELECT server_instant AT TIME ZONE 'America/Sao_Paulo' AS local_time) t $$;

CREATE FUNCTION private.convert_command(command_name text,operation_id uuid,payload jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE actor uuid:=auth.uid(); target uuid; old_row public.converts; new_row public.converts;
 receipt private.mutation_receipts; digest text; response jsonb; scope_id uuid; week_date date;
 guard record; asset public.photo_assets; key text; value jsonb;
 -- Match the captured JavaScript String.trim whitespace set independently of locale.
 trim_characters CONSTANT text := U&'\0009\000a\000b\000c\000d\0020\00a0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200a\2028\2029\202f\205f\3000\feff';
BEGIN
 IF actor IS NULL THEN RAISE EXCEPTION 'unauthorized' USING ERRCODE='42501'; END IF;
 IF operation_id IS NULL OR payload IS NULL OR jsonb_typeof(payload)<>'object' THEN
  RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
 PERFORM private.lock_access(ARRAY[actor]);
 IF command_name IN ('edit_convert','delete_convert') THEN
  target:=(payload->>'id')::uuid;
  SELECT * INTO old_row FROM public.converts WHERE id=target FOR UPDATE;
  IF old_row.id IS NULL OR NOT private.can_access_congregation(old_row.congregation_id) THEN
   RAISE EXCEPTION 'forbidden' USING ERRCODE='42501'; END IF;
 END IF;
 IF command_name='confirm_zero' THEN
  scope_id:=(payload->>'congregation_id')::uuid;
  IF scope_id IS NULL OR NOT private.can_access_congregation(scope_id) THEN
   RAISE EXCEPTION 'forbidden' USING ERRCODE='42501'; END IF;
 END IF;
 IF command_name='edit_convert' AND payload ? 'congregation_id' AND
 NOT private.can_access_congregation((payload->>'congregation_id')::uuid) THEN
  RAISE EXCEPTION 'forbidden' USING ERRCODE='42501'; END IF;
 digest:=encode(sha256(convert_to(payload::text,'UTF8')),'hex');
 SELECT * INTO receipt FROM private.mutation_receipts r WHERE r.actor_uid=actor AND r.operation_id=convert_command.operation_id;
 IF FOUND THEN
  IF receipt.command<>command_name OR receipt.payload_hash<>digest THEN
   RAISE EXCEPTION 'operation_conflict' USING ERRCODE='22023'; END IF;
  RETURN receipt.result;
 END IF;
 IF command_name IN ('create_convert','edit_convert') THEN
  FOR key,value IN SELECT * FROM jsonb_each(payload) LOOP
   IF key NOT IN ('id','name','landmark','gender','conversion_date','worship_type','congregation_id','photo_asset_id','address','phone','age') OR
    (key='id' AND command_name='create_convert') THEN
    RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
   IF key IN ('name','landmark','gender','conversion_date','worship_type','address','phone','congregation_id','photo_asset_id','id') AND
    value<>'null'::jsonb AND jsonb_typeof(value)<>'string' THEN
    RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
   IF key='age' AND value<>'null'::jsonb AND (jsonb_typeof(value)<>'number' OR value::text !~ '^[0-9]+$') THEN
    RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
  END LOOP;
  IF command_name='create_convert' THEN
   new_row.id:=gen_random_uuid(); new_row.internal_id:=new_row.id::text;
   new_row.created_by:=actor; new_row.created_at:=now(); new_row.was_visited_once:=false;
   new_row.visit_count:=0; new_row.is_in_discipleship:=false;
   new_row.is_discipleship_completed:=false; new_row.is_deviated:=false;
  ELSE
   IF old_row.deleted_at IS NOT NULL THEN RAISE EXCEPTION 'convert_deleted' USING ERRCODE='22023'; END IF;
   new_row:=old_row;
  END IF;
  new_row:=jsonb_populate_record(new_row,payload-'id');
  -- Source required-text validation treats tabs/newlines as whitespace too.
  IF EXISTS(SELECT FROM unnest(ARRAY[new_row.name,new_row.landmark,new_row.worship_type]) required(value)
    WHERE required.value<>btrim(required.value,trim_characters)) OR
   new_row.name IS NULL OR new_row.name<>btrim(new_row.name) OR new_row.name='' OR
   new_row.landmark IS NULL OR new_row.landmark<>btrim(new_row.landmark) OR new_row.landmark='' OR
   new_row.gender IS NULL OR new_row.gender NOT IN ('male','female') OR
   new_row.worship_type IS NULL OR new_row.worship_type<>btrim(new_row.worship_type) OR new_row.worship_type='' OR
   new_row.conversion_date IS NULL OR new_row.conversion_date>private.business_today() OR
   new_row.age NOT BETWEEN 0 AND 150 OR
   (payload ? 'conversion_date' AND payload->>'conversion_date' !~ '^\d{4}-\d{2}-\d{2}$') THEN
   RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
  IF new_row.congregation_id IS NOT NULL AND NOT EXISTS(SELECT FROM public.congregations WHERE id=new_row.congregation_id AND archived_at IS NULL) THEN
   RAISE EXCEPTION 'invalid_congregation' USING ERRCODE='22023'; END IF;
  -- Convert row precedes all photo rows; photo IDs are always locked in order.
  PERFORM 1 FROM public.photo_assets WHERE id IN (old_row.photo_asset_id,new_row.photo_asset_id) ORDER BY id FOR UPDATE;
  IF new_row.photo_asset_id IS DISTINCT FROM old_row.photo_asset_id AND new_row.photo_asset_id IS NOT NULL THEN
   SELECT * INTO asset FROM public.photo_assets WHERE id=new_row.photo_asset_id;
   IF asset.id IS NULL OR asset.owner_id<>actor OR asset.status<>'pending' OR asset.expires_at<=now() OR
    NOT EXISTS(SELECT FROM storage.objects WHERE bucket_id='convert-photos' AND name=asset.path) THEN
    RAISE EXCEPTION 'invalid_photo' USING ERRCODE='22023'; END IF;
  END IF;
  new_row.updated_at:=now();
 ELSIF command_name='delete_convert' THEN
  IF payload-'id'<>'{}'::jsonb OR target IS NULL OR old_row.deleted_at IS NOT NULL THEN
   RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
  PERFORM 1 FROM public.photo_assets WHERE id=old_row.photo_asset_id FOR UPDATE;
 ELSIF command_name='confirm_zero' THEN
  IF payload-'congregation_id'<>'{}'::jsonb OR NOT EXISTS(SELECT FROM public.congregations WHERE id=scope_id AND archived_at IS NULL) THEN
   RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
  week_date:=private.report_week(now());
 END IF;
 -- Insert and lock both old/new guards in one stable order, including date moves.
 FOR guard IN SELECT DISTINCT congregation_id,week_start FROM (
  SELECT old_row.congregation_id, date_trunc('week',old_row.conversion_date)::date AS week_start
  UNION ALL SELECT new_row.congregation_id,date_trunc('week',new_row.conversion_date)::date
  UNION ALL SELECT scope_id,week_date) s WHERE congregation_id IS NOT NULL AND week_start IS NOT NULL
  ORDER BY congregation_id,week_start LOOP
  INSERT INTO private.congregation_week_guards(congregation_id,week_start,conversion_count)
   SELECT guard.congregation_id,guard.week_start,count(*) FROM public.converts
   WHERE congregation_id=guard.congregation_id AND conversion_date BETWEEN guard.week_start AND guard.week_start+6 AND deleted_at IS NULL
   ON CONFLICT DO NOTHING;
  PERFORM 1 FROM private.congregation_week_guards WHERE congregation_id=guard.congregation_id AND week_start=guard.week_start FOR UPDATE;
 END LOOP;
 IF command_name='confirm_zero' THEN
  IF EXISTS(SELECT FROM private.congregation_week_guards WHERE congregation_id=scope_id AND week_start=week_date AND conversion_count<>0) THEN
   RAISE EXCEPTION 'week_has_conversions' USING ERRCODE='22023'; END IF;
  INSERT INTO public.weekly_reports(congregation_id,week_start,confirmed_by_email,confirmed_by_name,created_by)
   SELECT scope_id,week_date,u.email,p.display_name,actor FROM auth.users u JOIN public.profiles p ON p.id=u.id WHERE u.id=actor
   ON CONFLICT(congregation_id,week_start) DO NOTHING;
  SELECT jsonb_build_object('id',id) INTO response FROM public.weekly_reports WHERE congregation_id=scope_id AND week_start=week_date;
 ELSE
  IF old_row.id IS NOT NULL THEN
   UPDATE private.congregation_week_guards SET conversion_count=conversion_count-1
    WHERE congregation_id=old_row.congregation_id AND week_start=date_trunc('week',old_row.conversion_date)::date;
  END IF;
  IF command_name='delete_convert' THEN
   UPDATE public.converts SET deleted_at=now(),updated_at=now() WHERE id=target;
   UPDATE public.photo_assets SET status='detached' WHERE id=old_row.photo_asset_id;
   response:=jsonb_build_object('id',target);
  ELSE
   IF command_name='create_convert' THEN
    new_row.last_visit_date:=new_row.conversion_date;
    INSERT INTO public.converts SELECT new_row.*;
   ELSE
    UPDATE public.converts SET name=new_row.name,landmark=new_row.landmark,gender=new_row.gender,
     conversion_date=new_row.conversion_date,worship_type=new_row.worship_type,congregation_id=new_row.congregation_id,
     photo_asset_id=new_row.photo_asset_id,address=new_row.address,phone=new_row.phone,age=new_row.age,updated_at=now() WHERE id=target;
   END IF;
   UPDATE public.photo_assets SET status='detached' WHERE id=old_row.photo_asset_id AND id IS DISTINCT FROM new_row.photo_asset_id;
   UPDATE public.photo_assets SET status='attached',convert_id=new_row.id WHERE id=new_row.photo_asset_id;
   UPDATE private.congregation_week_guards SET conversion_count=conversion_count+1
    WHERE congregation_id=new_row.congregation_id AND week_start=date_trunc('week',new_row.conversion_date)::date;
   DELETE FROM public.weekly_reports WHERE congregation_id=new_row.congregation_id AND week_start=date_trunc('week',new_row.conversion_date)::date;
   response:=jsonb_build_object('id',new_row.id);
  END IF;
 END IF;
 INSERT INTO private.mutation_receipts(actor_uid,operation_id,command,payload_hash,result) VALUES(actor,operation_id,command_name,digest,response);
 RETURN response;
END $$;
CREATE FUNCTION public.ieadpe_create_convert(operation_id uuid,payload jsonb) RETURNS jsonb
LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$ SELECT private.convert_command('create_convert',operation_id,payload) $$;
CREATE FUNCTION public.ieadpe_edit_convert(operation_id uuid,payload jsonb) RETURNS jsonb
LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$ SELECT private.convert_command('edit_convert',operation_id,payload) $$;
CREATE FUNCTION public.ieadpe_delete_convert(operation_id uuid,payload jsonb) RETURNS jsonb
LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$ SELECT private.convert_command('delete_convert',operation_id,payload) $$;
CREATE FUNCTION public.ieadpe_confirm_zero(operation_id uuid,payload jsonb) RETURNS jsonb
LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$ SELECT private.convert_command('confirm_zero',operation_id,payload) $$;
REVOKE ALL ON FUNCTION private.convert_command(text,uuid,jsonb),private.business_today(),private.report_week(timestamptz) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.ieadpe_create_convert(uuid,jsonb),public.ieadpe_edit_convert(uuid,jsonb),public.ieadpe_delete_convert(uuid,jsonb),public.ieadpe_confirm_zero(uuid,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.ieadpe_create_convert(uuid,jsonb),public.ieadpe_edit_convert(uuid,jsonb),public.ieadpe_delete_convert(uuid,jsonb),public.ieadpe_confirm_zero(uuid,jsonb) TO authenticated;
