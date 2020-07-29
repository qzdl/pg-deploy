DROP FUNCTION IF EXISTS deploy.reconcile_trigger(
    source_schema name, source_oid oid,
    target_schema name, target_oid oid);

CREATE OR REPLACE FUNCTION deploy.reconcile_trigger(
    source_schema name, source_oid oid,
    target_schema name, target_oid oid)
RETURNS SETOF TEXT AS
$BODY$
BEGIN
    RETURN QUERY
    SELECT DISTINCT CASE
        WHEN t_schema IS NULL THEN
          'DROP TRIGGER IF EXISTS '||s_objname||' ON '||s_schema||'.'||c.relname||';'
        WHEN s_schema IS NULL THEN
          replace(pg_get_triggerdef(t_oid),
            target_schema||'.', source_schema||'.')
        ELSE
          '-- TRIGGER: LEFT and RIGHT of '''||s_objname||''' are equal'
        END AS ddl
    FROM deploy.object_difference(
      source_schema, target_schema,
      'deploy.cte_trigger', source_oid, target_oid) AS od
    INNER JOIN pg_trigger as tg ON tg.oid = od.s_oid OR tg.oid = od.t_oid
    INNER JOIN pg_class AS c ON c.oid = tg.tgrelid
    ORDER BY ddl DESC; -- comments and drops first
END;
$BODY$
    LANGUAGE plpgsql STABLE;

select * from deploy.reconcile_trigger(
'testp'::name, (select c.oid from pg_class c inner join pg_namespace n on c.relnamespace = n.oid and n.nspname = 'testp' where relname = 'nlr'),
'testr'::name, (select c.oid from pg_class c inner join pg_namespace n on c.relnamespace = n.oid and n.nspname = 'testr' where relname = 'nlr'))