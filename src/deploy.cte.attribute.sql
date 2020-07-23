DROP FUNCTION IF EXISTS deploy.cte_attribute(
    source_schema name, target_schema name, soid oid, toid oid);

CREATE OR REPLACE FUNCTION deploy.cte_attribute(
    source_schema name, target_schema name, soid oid, toid oid)
RETURNS TABLE(
    nspname name, objname name, oid oid, id text) AS
$BODY$
BEGIN
    RETURN QUERY
    SELECT DISTINCT
        n.nspname AS nspname,
        a.attname AS objname,
        cl.oid    AS oid,
        a.attname||atttypid AS id
    FROM pg_attribute AS a
    INNER JOIN pg_class AS cl
      ON cl.oid = a.attrelid AND cl.oid IN (soid, toid)
    INNER JOIN (
      SELECT n.nspname, n.oid
      FROM pg_namespace n
      WHERE n.nspname IN (source_schema, target_schema)
    ) AS n ON n.oid = cl.relnamespace
    WHERE a.attnum > 0; -- columns only;
END;
$BODY$
    LANGUAGE plpgsql STABLE;

select * from deploy.cte_attribute(
    'testp'::name, 'testr'::name,
    (SELECT c.oid FROM pg_class c INNER JOIN pg_namespace n ON n.oid = c.relnamespace and c.relname = 'con' and n.nspname = 'testp'),
    (SELECT c.oid FROM pg_class c INNER JOIN pg_namespace n ON n.oid = c.relnamespace and c.relname = 'con' and n.nspname = 'testr'));
