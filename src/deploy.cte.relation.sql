DROP FUNCTION IF EXISTS deploy.cte_relation(
    source_schema name, target_schema name);

CREATE FUNCTION deploy.cte_relation(
    source_schema name, target_schema name)
RETURNS TABLE(
    nspname name, objname name, oid oid, id text) AS
$BODY$
BEGIN
    RETURN QUERY
    SELECT
        n.nspname AS nspname,
        c.relname AS objname,
        c.oid     AS oid,
        c.relname||'' AS id
    FROM pg_catalog.pg_class c
    INNER JOIN pg_catalog.pg_namespace n
      ON n.oid = c.relnamespace
    WHERE relkind = 'r'
      AND (n.nspname = source_schema OR n.nspname = target_schema)
    ORDER BY n.nspname;
END;
$BODY$
    LANGUAGE plpgsql STABLE;

SELECT * FROM deploy.cte_relation('testp', 'testr');
