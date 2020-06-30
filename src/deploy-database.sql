CREATE SCHEMA IF NOT EXISTS deploy;

CREATE OR REPLACE FUNCTION deploy.reconcile_database(
    source_schema text, target_schema text)
RETURNS SETOF text AS
$BODY$
DECLARE
    _table record;
    _function record;
BEGIN
    -- preparations
    ---------------
    CREATE TEMP TABLE rank_ddl (rank smallint, ddl text);

    -- table actions
    FOR _table IN
        WITH candidates as (
            SELECT c.relname, c.oid, n.nspname
            FROM pg_catalog.pg_class c
                 LEFT JOIN pg_catalog.pg_namespace n
                     ON n.oid = c.relnamespace
            WHERE relkind = 'r'
            AND (n.nspname = target_schema OR n.nspname = source_schema)
            -- AND relname~ ('^('||object_name||')$')
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
        ) as active
        LEFT JOIN (
            SELECT nspname, relname, oid
            FROM candidates
            WHERE nspname = target_schema
        ) as target
        ON active.relname = target.relname
    LOOP
        RAISE NOTICE '_table: %', _table;

        INSERT INTO rank_ddl
        SELECT
            1,
            deploy.reconcile_constraints(
               _table.s_schema, _table.s_relname, _table.s_oid::integer,
               _table.t_schema, _table.t_relname, _table.t_oid::integer);
    END LOOP;

    -- indices
    ----------
    -- FOR rel in _tables
    -- LOOP

    -- END LOOP;

    -- -- functions / triggers
    -- -----------------------
    -- FOR _function IN
    --     SELECT quote_ident(n.nspname) as schema,
    --            quote_ident(p.proname) as function,
    --            p.oid
    --     FROM pg_catalog.pg_proc p
    --         JOIN pg_catalog.pg_namespace n
    --         ON n.oid = p.pronamespace
    --     WHERE n.nspname not like 'pg%'
    --       AND n.nspname <> 'information_schema'
    -- LOOP
    --     RAISE NOTICE '_function: %', _function;
    -- END LOOP;

    -- -- constraints
    -- --------------
    -- FOR rel IN _tables
    -- LOOP
    --     RAISE NOTICE '_constraints: %', rel; -- FIXME: probably worth burying in `reconsile_constraints`
    --     SELECT INTO rank_ddl
    --
    --         SELECT 1, deploy.reconcile_constraints(
    --             rel.s_schema, rel.s_relname, rel.s_oid,
    --             rel.t_schema, rel.t_relname, rel.t_oid);
    --     RETURN NEXT dll;
    -- END LOOP;

    -- -- tables
    -- ---------
    -- FOR rel IN _tables
    -- LOOP
    --     RAISE NOTICE '_tables: %', rel;
    --     SELECT INTO ddln
    --         SELECT deploy.reconcile_tables(
    --             rel.s_schema, rel.s_relname, rel.t_schema, rel.t_relname);
    --     RETURN NEXT dll;
    -- END LOOP;

-- https://www.postgresql.org/docs/current/functions-info.html

   RAISE NOTICE 'RANK_DDL: %', (select ddl from rank_ddl);
   DROP TABLE rank_ddl;
END
$BODY$
    LANGUAGE plpgsql VOLATILE;
