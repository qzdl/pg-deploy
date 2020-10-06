CREATE FUNCTION pgdeploy.cte_index(
    source_schema name, target_schema name,
    source_oid oid, target_oid oid)
RETURNS TABLE(
    nspname name, objname name, oid oid, id text) AS
$BODY$
BEGIN
    RETURN QUERY
    SELECT
        n.nspname AS nspname,
        ic.relname AS objname,
        indexrelid AS oid,
        replace(pg_get_indexdef(indexrelid), target_schema||'.', source_schema||'.') AS id
    FROM pg_catalog.pg_index AS i
    INNER JOIN pg_catalog.pg_class AS ic ON ic.oid = i.indexrelid
    INNER JOIN pg_catalog.pg_namespace AS n ON n.oid = ic.relnamespace
    WHERE i.indrelid = source_oid or i.indrelid = target_oid
    ORDER BY n.nspname;
END;
$BODY$
    LANGUAGE plpgsql STABLE;

--SELECT * FROM pgdeploy.cte_index('testp', 'testr',
--  (select c.oid from pg_class c inner join pg_namespace n on c.relnamespace = n.oid and n.nspname = 'testp' where relname = 'lnr'),
--  (select c.oid from pg_class c inner join pg_namespace n on c.relnamespace = n.oid and n.nspname = 'testr' where relname = 'lnr'));
