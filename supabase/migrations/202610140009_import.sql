CREATE FUNCTION public.ieadpe_import_convert(operation_id uuid,payload jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE actor uuid:=auth.uid(); row_data public.converts; existing public.converts;
 receipt private.mutation_receipts; digest text; response jsonb; key text; value jsonb;
 catalog_count integer; scope_id uuid; week_date date; warning text;
 trim_chars CONSTANT text:=U&'\0009\000a\000b\000c\000d\0020\00a0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200a\2028\2029\202f\205f\3000\feff';
BEGIN
 IF actor IS NULL THEN RAISE EXCEPTION 'unauthorized' USING ERRCODE='42501'; END IF;
 PERFORM private.lock_access(ARRAY[actor]);
 IF NOT private.is_global_manager() THEN RAISE EXCEPTION 'forbidden' USING ERRCODE='42501'; END IF;
 IF operation_id IS NULL OR payload IS NULL OR jsonb_typeof(payload)<>'object' THEN
  RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
 FOR key,value IN SELECT * FROM jsonb_each(payload) LOOP
  IF key NOT IN ('internal_id','name','landmark','gender','conversion_date','worship_type','congregation_name','address','phone','age',
   'last_visit_date','was_visited_once','visit_count','is_in_discipleship','discipleship_start_date','is_discipleship_completed','is_deviated') THEN
   RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
  IF key IN ('was_visited_once','is_in_discipleship','is_discipleship_completed','is_deviated') THEN
   IF jsonb_typeof(value)<>'boolean' THEN RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
  ELSIF key IN ('age','visit_count') THEN
   IF value<>'null'::jsonb AND (jsonb_typeof(value)<>'number' OR value::text !~ '^[0-9]+$') THEN
    RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
  ELSIF value<>'null'::jsonb AND jsonb_typeof(value)<>'string' THEN
   RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023';
  END IF;
 END LOOP;
 IF payload->>'internal_id' IS NULL OR length(payload->>'internal_id') NOT BETWEEN 1 AND 200 OR
  payload->>'internal_id'<>btrim(payload->>'internal_id',trim_chars) THEN
  RAISE EXCEPTION 'invalid_internal_id' USING ERRCODE='22023'; END IF;
 digest:=encode(sha256(convert_to(payload::text,'UTF8')),'hex');
 -- Only stable identifiers and a digest enter the receipt; no imported personal values.
 SELECT * INTO receipt FROM private.mutation_receipts r WHERE r.actor_uid=actor AND r.operation_id=ieadpe_import_convert.operation_id;
 IF FOUND THEN
  IF receipt.command<>'import_convert' OR receipt.payload_hash<>digest THEN
   RAISE EXCEPTION 'operation_conflict' USING ERRCODE='22023'; END IF;
  RETURN receipt.result;
 END IF;
 -- Serialize competing legacy IDs before catalog and week locks. No grant discovery here.
 PERFORM pg_advisory_xact_lock(hashtextextended('ieadpe-import:'||(payload->>'internal_id'),0));
 SELECT * INTO existing FROM public.converts WHERE internal_id=payload->>'internal_id' FOR UPDATE;
 IF FOUND THEN
  response:=jsonb_build_object('id',existing.id,'status',CASE WHEN existing.deleted_at IS NULL THEN 'duplicate' ELSE 'tombstone' END);
 ELSE
  row_data:=jsonb_populate_record(row_data,payload-'congregation_name');
  row_data.id:=gen_random_uuid(); row_data.created_by:=actor; row_data.created_at:=now(); row_data.updated_at:=now();
  row_data.visit_count:=coalesce(row_data.visit_count,0); row_data.was_visited_once:=coalesce(row_data.was_visited_once,row_data.visit_count>0);
  row_data.is_in_discipleship:=coalesce(row_data.is_in_discipleship,false);
  row_data.is_discipleship_completed:=coalesce(row_data.is_discipleship_completed,false); row_data.is_deviated:=coalesce(row_data.is_deviated,false);
  row_data.last_visit_date:=coalesce(row_data.last_visit_date,row_data.conversion_date);
  IF EXISTS(SELECT FROM unnest(ARRAY[row_data.name,row_data.landmark,row_data.worship_type]) required(v)
    WHERE v IS NULL OR v='' OR v<>btrim(v,trim_chars)) OR
   row_data.gender IS NULL OR row_data.gender NOT IN ('male','female') OR
   row_data.conversion_date IS NULL OR row_data.conversion_date>private.business_today() OR
   row_data.age NOT BETWEEN 0 AND 150 OR row_data.visit_count<0 OR
   row_data.last_visit_date>private.business_today() OR
   row_data.discipleship_start_date>private.business_today() OR
   EXISTS(SELECT FROM jsonb_each_text(payload) d(k,v) WHERE k IN ('conversion_date','last_visit_date','discipleship_start_date') AND v IS NOT NULL AND v !~ '^\d{4}-\d{2}-\d{2}$') THEN
   RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
  -- Lock all matching catalog candidates in stable order, including archived labels.
  PERFORM 1 FROM public.congregations WHERE name=btrim(payload->>'congregation_name',trim_chars) ORDER BY id FOR SHARE;
  SELECT count(*),(array_agg(id ORDER BY id))[1] INTO catalog_count,scope_id FROM public.congregations
   WHERE name=btrim(payload->>'congregation_name',trim_chars) AND archived_at IS NULL;
  IF catalog_count>1 THEN RAISE EXCEPTION 'ambiguous_congregation' USING ERRCODE='22023'; END IF;
  IF catalog_count=0 AND coalesce(btrim(payload->>'congregation_name',trim_chars),'')<>'' THEN warning:='unknown_congregation'; END IF;
  row_data.congregation_id:=scope_id;
  week_date:=date_trunc('week',row_data.conversion_date)::date;
  IF scope_id IS NOT NULL THEN
   INSERT INTO private.congregation_week_guards(congregation_id,week_start,conversion_count)
    SELECT scope_id,week_date,count(*) FROM public.converts WHERE congregation_id=scope_id
     AND conversion_date BETWEEN week_date AND week_date+6 AND deleted_at IS NULL ON CONFLICT DO NOTHING;
   PERFORM 1 FROM private.congregation_week_guards WHERE congregation_id=scope_id AND week_start=week_date FOR UPDATE;
  END IF;
  INSERT INTO public.converts SELECT row_data.* ON CONFLICT(internal_id) DO NOTHING;
  IF FOUND THEN
   UPDATE private.congregation_week_guards SET conversion_count=conversion_count+1 WHERE congregation_id=scope_id AND week_start=week_date;
   DELETE FROM public.weekly_reports WHERE congregation_id=scope_id AND week_start=week_date;
   response:=jsonb_build_object('id',row_data.id,'status','created','warning',warning);
  ELSE
   SELECT * INTO existing FROM public.converts WHERE internal_id=row_data.internal_id;
   response:=jsonb_build_object('id',existing.id,'status',CASE WHEN existing.deleted_at IS NULL THEN 'duplicate' ELSE 'tombstone' END);
  END IF;
 END IF;
 INSERT INTO private.mutation_receipts(actor_uid,operation_id,command,payload_hash,result)
 VALUES(actor,operation_id,'import_convert',digest,response);
 RETURN response;
EXCEPTION WHEN invalid_datetime_format OR datetime_field_overflow OR numeric_value_out_of_range THEN
 RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023';
END $$;
REVOKE ALL ON FUNCTION public.ieadpe_import_convert(uuid,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.ieadpe_import_convert(uuid,jsonb) TO authenticated;
