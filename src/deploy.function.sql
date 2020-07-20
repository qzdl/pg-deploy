CREATE SCHEMA IF NOT EXISTS deploy;

DROP FUNCTION IF EXISTS deploy.reconcile_function(
    source_schema name, target_schema name);

CREATE OR REPLACE FUNCTION deploy.reconcile_function(
    source_schema name, target_schema name)
RETURNS SETOF TEXT AS
$BODY$
BEGIN
    RETURN QUERY
    SELECT DISTINCT
          CASE WHEN t_schema IS NULL THEN
            'DROP FUNCTION IF EXISTS '||s_schema||'.'||s_id
               WHEN s_schema IS NULL THEN
            replace(pg_get_functiondef(t_oid),
              target_schema||'.', source_schema||'.')
          ELSE '-- LEFT and RIGHT of '''||s_id||''' are equal' END AS ddl --, COALESCE(s_schema, 'CREATE') as s_schema, s_objname, s_oid, pg_get_functiondef(s_oid) as s_def, pg_get_functions_identity_arguments(s_oid) as s_iargs, s_id, COALESCE(t_schema, 'DROP') as t_schema, t_objname, t_oid, --  ,pg_get_functiondef(t_oid) as t_def, pg_get_function_identity_arguments(t_oid) as t_def, t_id
    FROM deploy.object_difference(source_schema, target_schema, 'deploy.cte_function');
END;
$BODY$
    LANGUAGE plpgsql STABLE;

select * from deploy.reconcile_function('testp', 'testr');
