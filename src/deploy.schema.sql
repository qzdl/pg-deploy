CREATE SCHEMA IF NOT EXISTS deploy;

DROP FUNCTION IF EXISTS deploy.reconcile_schema(
    source_schema name, target_schema name);

CREATE OR REPLACE FUNCTION deploy.reconcile_schema(
    source_schema name, target_schema name)
RETURNS TABLE(priority int, ddl text) AS
$BODY$
DECLARE
    _table record;
    _function record;
BEGIN
    -- preparations
    --------------- FIXME: create & modify distinct attrs.

    DROP TABLE IF EXISTS acc_ddl;
    CREATE TEMPORARY TABLE acc_ddl (priority int, ddl text);

    -- table actions
    -- FIXME: covering NULLS from LEFT and RIGHT
    FOR _table IN
        WITH candidates as (
            SELECT c.relname, c.oid, n.nspname
            FROM pg_catalog.pg_class c
                 LEFT JOIN pg_catalog.pg_namespace n
                     ON n.oid = c.relnamespace
            WHERE relkind = 'r'
            AND (n.nspname = source_schema OR n.nspname = target_schema)
            ORDER BY c.relname
        )
        SELECT
            active.nspname as s_schema,
            active.relname as s_relname,
            active.oid     as s_oid,
            target.nspname as t_schema,
            target.relname as t_relname,
            target.oid     as t_oid
        FROM (
            SELECT nspname, relname, oid
            FROM candidates
            WHERE nspname = source_schema
        ) AS active
        LEFT JOIN (
            SELECT nspname, relname, oid
            FROM candidates
            WHERE nspname = target_schema
        ) AS target
        ON active.relname = target.relname
    LOOP
        RAISE NOTICE 'LOOP TOPLEVEL: %', _table;

        -- tables
        ---------
        INSERT INTO acc_ddl
        SELECT 1, deploy.reconcile_table_attributes(
            _table.s_schema, _table.s_relname, _table.s_oid,
            _table.t_schema, _table.t_relname, _table.t_oid);

        -- constraints
        --------------
        INSERT INTO acc_ddl
        SELECT 2, deploy.reconcile_constraints(
            _table.s_schema, _table.s_relname, _table.s_oid,
            _table.t_schema, _table.t_relname, _table.t_oid);

        -- triggers
        -----------------------
        -- INSERT INTO acc_ddl
        -- SELECT 3, deploy.reconcile_triggers(

        -- )

        -- indices
        ----------
        INSERT INTO acc_ddl
        SELECT 4, deploy.reconcile_index(
            _table.s_schema, _table.s_oid,
            _table.t_schema, _table.t_oid);
    END LOOP;

    -- types
    --------

    -- enums
    --------

    -- sequences
    ------------

    -- functions
    ------------
    INSERT INTO acc_ddl
    SELECT 5, deploy.reconcile_function(source_schema, target_schema);

    RETURN QUERY
        SELECT d.priority, d.ddl FROM acc_ddl d
        ORDER BY d.priority ASC;

    DROP TABLE IF EXISTS acc_dll;
END;
$BODY$
    LANGUAGE plpgsql VOLATILE;

select deploy.reconcile_schema('testp'::name, ' testr'::name);
