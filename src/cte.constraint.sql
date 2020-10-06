CREATE OR REPLACE FUNCTION pgdeploy.cte_constraint(
    source_schema name, target_schema name, soid oid, toid oid)
RETURNS TABLE(
    nspname name, objname name, oid oid, id text) AS
$BODY$
BEGIN
    RETURN QUERY
    SELECT DISTINCT
        n.nspname AS nspname,
        c.conname AS objname,
        c.oid     AS oid,
        c.conname ||' '||pg_get_constraintdef(c.oid)
                  AS id
    FROM pg_constraint AS c
    INNER JOIN pg_class AS cl ON cl.oid = c.conrelid AND cl.oid IN (soid, toid)
    INNER JOIN pg_attribute AS a ON a.attrelid = cl.oid
    INNER JOIN (
      SELECT n.nspname, n.oid
      FROM pg_namespace n
      WHERE n.nspname IN (source_schema, target_schema)
    ) AS n ON n.oid = cl.relnamespace;
END;
$BODY$
    LANGUAGE plpgsql STABLE;

--select * from pgdeploy.cte_constraint(
--    'testp'::name, 'testr'::name,
--    (SELECT c.oid FROM pg_class c INNER JOIN pg_namespace n ON n.oid = c.relnamespace and c.relname = 'con' and n.nspname = 'testp'),
--    (SELECT c.oid FROM pg_class c INNER JOIN pg_namespace n ON n.oid = c.relnamespace and c.relname = 'con' and n.nspname = 'testr'));
