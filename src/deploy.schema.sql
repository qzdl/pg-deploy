/*
pg_deploy.reconcile_schema is the main function of pg_deploy. The function returns the final product
of transformation rules ordered by priority (order of execution).
The role of priority follows the object type dependency.
For instance a table can be dependent on a type or a function,
a function can be dependent on a type, thus the order is table, function, type.
*/

CREATE SCHEMA IF NOT EXISTS pg_deploy;
DROP FUNCTION IF EXISTS pg_deploy.reconcile_schema(
    source_schema name, target_schema name);

CREATE OR REPLACE FUNCTION pg_deploy.reconcile_schema(
    source_schema name, target_schema name)
RETURNS TABLE(priority int, ddl text) AS
$BODY$
BEGIN
    RAISE NOTICE '%', (select CASE WHEN 'testr'::name = target_schema THEN 'y' else 'n' end);

    RETURN QUERY
    with candidates as (
        SELECT * FROM pg_deploy.object_difference(
            source_schema, target_schema, 'pg_deploy.cte_relation')
        WHERE s_schema IS NOT NULL AND t_schema IS NOT NULL
    )
    SELECT 1 AS priority, pg_deploy.reconcile_relation(source_schema, target_schema) AS ddl
    UNION  -- attributes
    SELECT 2 AS priority, pg_deploy.reconcile_table_attributes(
        s_schema, s_objname, s_oid,
        t_schema, t_objname, t_oid) AS ddl
    FROM candidates
    UNION  -- constraints
    SELECT 3 AS priority, pg_deploy.reconcile_constraints(
        s_schema, s_objname, s_oid,
        t_schema, t_objname, t_oid) AS ddl
    FROM candidates
    -- UNION ALL -- triggers
    -- SELECT 4, pg_deploy.reconcile_triggers(
    --     s_schema, s_objname, s_oid,
    --     t_schema, s_objname, s_oid)
    -- ) FROM candidates
    UNION  -- indices
    SELECT 5, pg_deploy.reconcile_index(s_schema, s_oid, t_schema, t_oid)
    FROM candidates
    UNION  -- functions
    SELECT 6, pg_deploy.reconcile_function(source_schema, target_schema);
    -- types
    -- enums
    -- sequences
END;
$BODY$
    LANGUAGE plpgsql STABLE;

select * from pg_deploy.reconcile_schema('testp'::name, 'testr'::name) order by priority, ddl desc;
