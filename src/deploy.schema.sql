CREATE SCHEMA IF NOT EXISTS deploy;

DROP FUNCTION IF EXISTS deploy.reconcile_schema(
    source_schema name, target_schema name);

CREATE OR REPLACE FUNCTION deploy.reconcile_schema(
    source_schema name, target_schema name)
RETURNS TABLE(priority int, ddl text) AS
$BODY$
BEGIN
    RAISE NOTICE '%', (select CASE WHEN 'testr'::name = target_schema THEN 'y' else 'n' end);
    
    RETURN QUERY
    with candidates as (
        SELECT * FROM deploy.object_difference(
            source_schema, target_schema, 'deploy.cte_relation')
        WHERE s_schema IS NOT NULL AND t_schema IS NOT NULL
    )
    SELECT 1 AS priority, deploy.reconcile_relation(source_schema, target_schema) AS ddl
    -- UNION  -- attributes
    -- SELECT 2 AS priority, deploy.reconcile_table_attributes(
    --     s_schema, s_objname, s_oid,
    --     t_schema, t_objname, t_oid) AS ddl
    -- FROM candidates
    UNION  -- constraints
    SELECT 3 AS priority, deploy.reconcile_constraints(
        s_schema, s_objname, s_oid,
        t_schema, t_objname, t_oid) AS ddl
    FROM candidates
    -- UNION ALL -- triggers
    -- SELECT 4, deploy.reconcile_triggers(
    --     s_schema, s_objname, s_oid,
    --     t_schema, s_objname, s_oid)
    -- ) FROM candidates
    UNION  -- indices
    SELECT 5, deploy.reconcile_index(s_schema, s_oid, t_schema, t_oid)
    FROM candidates
    UNION  -- functions
    SELECT 6, deploy.reconcile_function(source_schema, target_schema);
    -- types
    -- enums
    -- sequences
END;
$BODY$
    LANGUAGE plpgsql STABLE;

select * from deploy.reconcile_schema('testp'::name, 'testr'::name) order by priority, ddl desc;
