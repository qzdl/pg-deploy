DROP FUNCTION IF EXISTS deploy.cte_function(
    source_schema name, target_schema name);

CREATE FUNCTION deploy.cte_function(
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
        replace(pg_get_functiondef(p.oid), target_schema||'.', source_schema||'.')
                  AS id
    FROM pg_catalog.pg_proc p
        JOIN pg_catalog.pg_namespace n
        ON n.oid = p.pronamespace
    WHERE n.nspname NOT LIKE 'pg%'
      AND n.nspname <> 'information_schema'
      AND n.nspname IN (source_schema, target_schema)
    ORDER BY n.nspname;
END;
$BODY$
    LANGUAGE plpgsql STABLE;

SELECT *  FROM deploy.cte_function('testp', 'testr');
