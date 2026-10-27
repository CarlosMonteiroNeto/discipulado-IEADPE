-- Worship is optional for new converts. The existing CHECK intentionally
-- keeps rejecting non-null blank/trimmed values while allowing SQL NULL.
ALTER TABLE public.converts ALTER COLUMN worship_type DROP NOT NULL;

-- Preserve the currently deployed registration implementation and change only
-- worship validation. CREATE OR REPLACE retains the function signature, owner,
-- security attributes, and grants; the guards fail closed if the expected
-- current definition has drifted.
DO $migration$
DECLARE definition text; updated text; old_piece text; new_piece text;
BEGIN
 SELECT pg_get_functiondef('private.convert_registration_command(text,uuid,jsonb)'::regprocedure)
 INTO definition;
 updated:=definition;

 old_piece:=$old$NOT convert_data ?& ARRAY['landmark','gender','conversion_date','worship_type']$old$;
 new_piece:=$new$NOT convert_data ?& ARRAY['landmark','gender','conversion_date']$new$;
 IF position(new_piece IN updated)>0 THEN NULL;
 ELSIF position(old_piece IN updated)>0 THEN updated:=replace(updated,old_piece,new_piece);
 ELSE RAISE EXCEPTION 'convert registration definition drift: required keys'; END IF;

 old_piece:=$old$jsonb_typeof(convert_data->'worship_type') IS DISTINCT FROM 'string'$old$;
 new_piece:=$new$(convert_data ? 'worship_type' AND jsonb_typeof(convert_data->'worship_type') NOT IN ('string','null'))$new$;
 IF position(new_piece IN updated)>0 THEN NULL;
 ELSIF position(old_piece IN updated)>0 THEN updated:=replace(updated,old_piece,new_piece);
 ELSE RAISE EXCEPTION 'convert registration definition drift: worship JSON type'; END IF;

 old_piece:=$old$btrim(convert_data->>'worship_type',trim_chars)=''$old$;
 new_piece:=$new$(convert_data ? 'worship_type' AND convert_data->'worship_type'<>'null'::jsonb AND btrim(convert_data->>'worship_type',trim_chars)='')$new$;
 IF position(new_piece IN updated)>0 THEN NULL;
 ELSIF position(old_piece IN updated)>0 THEN updated:=replace(updated,old_piece,new_piece);
 ELSE RAISE EXCEPTION 'convert registration definition drift: blank worship'; END IF;

 old_piece:=$old$convert_data->>'worship_type'<>btrim(convert_data->>'worship_type',trim_chars)$old$;
 new_piece:=$new$convert_data ? 'worship_type' AND convert_data->'worship_type'<>'null'::jsonb AND convert_data->>'worship_type'<>btrim(convert_data->>'worship_type',trim_chars)$new$;
 IF position(new_piece IN updated)>0 THEN NULL;
 ELSIF position(old_piece IN updated)>0 THEN updated:=replace(updated,old_piece,new_piece);
 ELSE RAISE EXCEPTION 'convert registration definition drift: worship trimming'; END IF;

 EXECUTE updated;
END
$migration$;

-- Imports use a generic JSON field validator; null remains a valid JSON value,
-- while non-string types and blank strings continue to be rejected.
DO $migration$
DECLARE definition text; updated text; old_piece text; new_piece text;
BEGIN
 SELECT pg_get_functiondef('public.ieadpe_import_convert(uuid,jsonb)'::regprocedure)
 INTO definition;
 updated:=definition;
 old_piece:=$old$ARRAY[row_data.name,row_data.landmark,row_data.worship_type]$old$;
 new_piece:=$new$ARRAY[row_data.name,row_data.landmark]$new$;
 IF position(new_piece IN updated)>0 THEN NULL;
 ELSIF position(old_piece IN updated)>0 THEN updated:=replace(updated,old_piece,new_piece);
 ELSE RAISE EXCEPTION 'import definition drift: required fields'; END IF;

 old_piece:=$old$WHERE v IS NULL OR v='' OR v<>btrim(v,trim_chars)) OR$old$;
 new_piece:=$new$WHERE v IS NULL OR v='' OR v<>btrim(v,trim_chars)) OR
   (row_data.worship_type IS NOT NULL AND (row_data.worship_type='' OR row_data.worship_type<>btrim(row_data.worship_type,trim_chars))) OR$new$;
 IF position(new_piece IN updated)>0 THEN NULL;
 ELSIF position(old_piece IN updated)>0 THEN updated:=replace(updated,old_piece,new_piece);
 ELSE RAISE EXCEPTION 'import definition drift: worship validation'; END IF;
 EXECUTE updated;
END
$migration$;

-- Legacy create/edit remains available with unchanged access checks, receipts,
-- revisions, photo handling, and weekly counter protocol.
DO $migration$
DECLARE definition text; updated text; old_piece text; new_piece text;
BEGIN
 SELECT pg_get_functiondef('private.convert_command(text,uuid,jsonb)'::regprocedure)
 INTO definition;
 updated:=definition;
 -- Keep worship in the broad trim set: NULL elements produce NULL comparison
 -- results and therefore pass the WHERE predicate, while TAB/NBSP stay invalid.

 old_piece:=$old$new_row.worship_type IS NULL OR new_row.worship_type<>btrim(new_row.worship_type) OR new_row.worship_type=''$old$;
 new_piece:=$new$(new_row.worship_type IS NOT NULL AND
    (new_row.worship_type<>btrim(new_row.worship_type) OR new_row.worship_type=''))$new$;
 IF position(new_piece IN updated)>0 THEN NULL;
 ELSIF position(old_piece IN updated)>0 THEN updated:=replace(updated,old_piece,new_piece);
 ELSE RAISE EXCEPTION 'legacy convert definition drift: worship validation'; END IF;

 -- The legacy function predates the revision column and inserts a composite
 -- row, so it must initialize the schema's initial revision explicitly.
 old_piece:=$old$new_row.is_discipleship_completed:=false; new_row.is_deviated:=false;$old$;
 new_piece:=$new$new_row.is_discipleship_completed:=false; new_row.is_deviated:=false; new_row.revision:=1;$new$;
 IF position(new_piece IN updated)>0 THEN NULL;
 ELSIF position(old_piece IN updated)>0 THEN updated:=replace(updated,old_piece,new_piece);
 ELSE RAISE EXCEPTION 'legacy convert definition drift: initial revision'; END IF;
 EXECUTE updated;
END
$migration$;
