CREATE FUNCTION pgdeploy.cte_function(
    source_schema name, target_schema name)
RETURNS TABLE(
    nspname name, objname name, oid oid, id text) AS
$BODY$
BEGIN
    RETURN QUERY
    SELECT
        n.nspname AS nspname,
        p.proname AS objname,
        p.oid     AS oid,
        replace((CASE WHEN l.lanname = 'internal'
           THEN p.proname||p.prosrc||pg_get_function_arguments(p.oid)
           ELSE pg_get_functiondef(p.oid) END),
          target_schema||'.', source_schema||'.') AS id
      FROM pg_catalog.pg_proc p
      INNER JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
      LEFT JOIN pg_language l ON p.prolang = l.oid
      WHERE n.nspname NOT LIKE 'pg%'
        AND n.nspname <> 'information_schema'
        AND n.nspname IN (source_schema, target_schema)
      ORDER BY n.nspname;
END;
$BODY$
    LANGUAGE plpgsql STABLE;

--SELECT *  FROM pgdeploy.cte_function('testp', 'testr');

-- select p.prosrc, p.* from pg_aggregate a
-- inner join pg_proc p on a.aggfnoid = p.oid
-- where p.proname = 'cavg'
