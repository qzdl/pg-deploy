CREATE SCHEMA IF NOT EXISTS deploy;

DROP FUNCTION IF EXISTS deploy.reconcile_relation(
    source_schema name, target_schema name);

CREATE OR REPLACE FUNCTION deploy.reconcile_relation(
    source_schema name, target_schema name)
RETURNS SETOF TEXT AS
$BODY$
BEGIN
    RETURN QUERY
    SELECT DISTINCT
        CASE WHEN t_schema IS NULL THEN
          'DROP TABLE IF EXISTS '||s_schema||'.'||s_id
             WHEN s_schema IS NULL THEN
          'CREATE TABLE '||source_schema||'.'||t_objname||'(LIKE '||t_schema||'.'||t_objname||' including all);'
             ELSE
          '-- LEFT and RIGHT of '''||s_id||''' are equal' END AS ddl
    FROM deploy.object_difference(source_schema, target_schema, 'deploy.cte_relation')
    order by ddl desc; -- comments and drops first
END;
$BODY$
    LANGUAGE plpgsql STABLE;

select * from deploy.reconcile_relation('testp', 'testr');
