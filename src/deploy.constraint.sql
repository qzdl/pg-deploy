/*
    reconcile_constraints:
    - diff of constraints for tables through anti-join
    - mark for ALTER

*/

DROP FUNCTION IF EXISTS deploy.reconcile_constraints(
    source_schema name, source_rel name, source_oid oid,
    target_schema name, target_rel name, target_oid oid);
    
CREATE OR REPLACE FUNCTION deploy.reconcile_constraints(
    source_schema name, source_rel name, source_oid oid,
    target_schema name, target_rel name, target_oid oid)
RETURNS SETOF text AS
$BODY$
DECLARE
    _constraints record;
    ddl text;
BEGIN
    RETURN QUERY
    SELECT DISTINCT
        CASE WHEN t_schema IS NULL THEN
          'ALTER TABLE '||source_schema||'.'||source_rel
          ||' DROP CONSTRAINT IF EXISTS '||s_objname||';'
             WHEN s_schema IS NULL THEN
          'ALTER TABLE '||source_schema||'.'||source_rel
          ||' ADD CONSTRAINT '||t_objname||' '||pg_get_constraintdef(t_oid)||';'
             ELSE
          '-- LEFT and RIGHT of '''||s_id||''' are equal'
        END AS ddl
    FROM deploy.object_difference(
      source_schema, target_schema,
      'deploy.cte_constraint',
      source_oid, target_oid)
    order by ddl desc;
END;
$BODY$
    LANGUAGE plpgsql STABLE;

select * from deploy.reconcile_constraints(
    'testp'::name, 'con'::name, (SELECT c.oid FROM pg_class c INNER JOIN pg_namespace n ON n.oid = c.relnamespace and c.relname = 'con' and n.nspname = 'testp'),
    'testr'::name, 'con'::name, (SELECT c.oid FROM pg_class c INNER JOIN pg_namespace n ON n.oid = c.relnamespace and c.relname = 'con' and n.nspname = 'testr'));
