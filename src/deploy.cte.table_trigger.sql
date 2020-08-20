DROP FUNCTION IF EXISTS pg_deploy.cte_trigger(
    source_schema name, target_schema name,
    source_oid oid, target_oid oid);

CREATE FUNCTION pg_deploy.cte_trigger(
    source_schema name, target_schema name,
    source_oid oid, target_oid oid)
RETURNS TABLE(
    nspname name, objname name, oid oid, id text) AS
$BODY$
BEGIN
    RETURN QUERY
    SELECT n.nspname  AS nspname,
           tg.tgname AS objname,
           tg.oid     AS oid,
           replace(pg_get_triggerdef(tg.oid), target_schema||'.', source_schema||'.')
                      AS id
      FROM pg_catalog.pg_trigger AS tg
      INNER JOIN pg_catalog.pg_class AS ic ON ic.oid = tg.tgrelid
      INNER JOIN pg_catalog.pg_namespace AS n ON n.oid = ic.relnamespace
      WHERE tg.tgrelid = source_oid OR tg.tgrelid = target_oid
      ORDER BY n.nspname;
END;
$BODY$
    LANGUAGE plpgsql STABLE;

SELECT * FROM pg_deploy.cte_trigger('testp'::name, 'testr'::name,
  (select c.oid from pg_class c inner join pg_namespace n on c.relnamespace = n.oid and n.nspname = 'testp' where relname = 'nlr'),
  (select c.oid from pg_class c inner join pg_namespace n on c.relnamespace = n.oid and n.nspname = 'testr' where relname = 'nlr'));


-- SELECT * FROM pg_deploy.object_difference('testp'::name, 'testr'::name, 'cte_trigger'::name,
--   (select c.oid from pg_class c inner join pg_namespace n on c.relnamespace = n.oid and n.nspname = 'testp' where relname = 'lrnm2'),
--   (select c.oid from pg_class c inner join pg_namespace n on c.relnamespace = n.oid and n.nspname = 'testr' where relname = 'lrnm2'));
