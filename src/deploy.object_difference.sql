-- deploy.object_difference.sql
--
-- ARGUMENT `cte_fun':
--   must return a set of `(nspname name, objname name, oid oid, id text)' that
--   corresponds to the relevant properties of each object. See
--   `./deploy.cte.function.sql` for an example.

DROP FUNCTION IF EXISTS deploy.object_difference(
    source_schema name, target_schema name, cte_fun text, soid oid, toid oid);

CREATE OR REPLACE FUNCTION deploy.object_difference(
    source_schema name, target_schema name, cte_fun text,
    soid oid default NULL, toid oid default NULL)
RETURNS TABLE(
    s_schema name, s_objname name, s_oid oid, s_id text,
    t_schema name, t_objname name, t_oid oid, t_id text
) AS $BODY$
DECLARE
    oids text := '';
BEGIN
    IF (soid IS NOT NULL AND toid IS NOT NULL) THEN
        oids := ' ,'||soid||','||toid;
    END IF;

    RETURN QUERY EXECUTE FORMAT('
    with fun as (
        select * from %1$s($1,$2'||oids||')
    )
    SELECT DISTINCT
        s_schema, s_objname, s_oid, s_id,
        t_schema, t_objname, t_oid, t_id
    FROM (
        WITH ss AS (
            SELECT nspname, objname, oid, id
            FROM fun
            WHERE nspname = $1
        ),   tt AS (
            SELECT nspname, objname, oid, id
            FROM fun
            WHERE nspname = $2
        )
        SELECT s.nspname as s_schema,
               s.objname as s_objname,
               s.oid     as s_oid,
               s.id      as s_id,
               t.nspname as t_schema,
               t.objname as t_objname,
               t.oid     as t_oid,
               t.id      as t_id
        FROM ss as s
        LEFT JOIN tt as t ON s.id = t.id
        UNION ALL
        SELECT s.nspname  as s_schema,
               s.objname  as s_objname,
               s.oid      as s_oid,
               s.id       as s_id,
               t.nspname  as t_schema,
               t.objname  as t_objname,
               t.oid      as t_oid,
               t.id as t_id
        FROM tt as t
        LEFT JOIN ss as s ON s.id = t.id
    ) as AAA', cte_fun, source_schema, target_schema) USING source_schema, target_schema;
END; $BODY$ LANGUAGE plpgsql STABLE;

SELECT * FROM deploy.object_difference('testp'::name, 'testr'::name, 'deploy.cte_function'::text);


WITH info AS (
  SELECT distinct
    t.oid, n.nspname, t.typname, t.typlen, t.typrelid,
    s_schema, s_objname, t_schema, t_objname, 
    COALESCE(s_schema, t_schema) AS schemata
  FROM deploy.object_difference('testp'::name, 'testr'::name, 'deploy.cte_type')
  INNER JOIN pg_type t ON t.oid = s_oid OR t.oid = t_oid
  INNER JOIN pg_namespace n ON n.oid = t.typnamespace
), range AS (
  SELECT i.oid, array_to_string(ARRAY[
    'subtype = '||(SELECT typname FROM pg_type t2 WHERE t2.oid = r.rngsubtype),
     CASE WHEN opcdefault <> 't' THEN 'subtype_opclass = '||'testp'||'.'||opcname ELSE NULL END,
     CASE WHEN rngsubdiff::text <> '-' THEN 'subtype_diff = ' || rngsubdiff ELSE NULL END,
     CASE WHEN rngcanonical::text <> '-' THEN 'canonical = ' || rngcanonical ELSE NULL END,
     CASE WHEN rngcollation <> 0 THEN 'collation = ' || rngcollation ELSE NULL END], E',\n  ') AS range_body
  FROM pg_catalog.pg_range r
  INNER JOIN info i on i.oid = r.rngtypid
  LEFT JOIN pg_catalog.pg_type st ON st.oid = r.rngsubtype
  LEFT JOIN pg_catalog.pg_opclass opc ON r.rngsubopc = opc.oid
), enumitems AS (
  SELECT i.oid, i.nspname, ''''||e.enumlabel||'''' AS label, e.enumsortorder as sort, i.typname
  FROM pg_catalog.pg_enum e
  INNER JOIN info i ON e.enumtypid = i.oid
  ORDER BY e.enumsortorder
)
select distinct * from (
SELECT distinct ei.label, ei.sort, ei.typname
FROM enumitems AS ei
WHERE ei.nspname = 'testp'
  AND NOT EXISTS(
  SELECT 1 FROM enumitems AS et
  WHERE et.nspname = 'testr'
    AND et.typname = ei.typname
    AND et.label = ei.label
    AND et.sort = ei.sort
)
UNION SELECT DISTINCT ei.label, ei.sort, ei.typname
FROM enumitems AS ei
WHERE ei.nspname = 'testr'
  AND NOT EXISTS(
  SELECT 1 FROM enumitems AS et
  WHERE et.nspname = 'testp'
    AND et.typname = ei.typname
    AND et.label = ei.label
    AND et.sort = ei.sort
)
) u
order by typname, sort
-- --for each (enum0, enum1)
