CREATE SCHEMA IF NOT EXISTS deploy;

CREATE FUNCTION deploy.reconcile_database(
    source_schema text,
    target_schema text)
RETURNS SETOF text AS
$BODY$
DECLARE
    ddl text;
    _tables record;
    _functions record;
BEGIN
    -- preparations
    ---------------
    SELECT INTO _tables
    WITH candidates as (
       SELECT c.relname, c.oid, n.nspname
       FROM pg_catalog.pg_class c
           LEFT JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
       WHERE relkind = 'r'
           AND (n.nspname = target_schema OR n.nspname = source_schema)
           -- AND relname~ ('^('||object_name||')$')
       ORDER BY c.relname
    )
    SELECT active.nspname as s_schema,
           active.relname as s_relname,
           active.oid     as s_oid,
           target.nspname as t_schema,
           target.relname as t_relname
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
    ) as target ON active.relname = target.relname


    -- indices
    ----------

  -- functions / triggers
    -----------------------
    FOR _function IN
        SELECT quote_ident(n.nspname) as schema,
               quote_ident(p.proname) as function,
               p.oid
        FROM pg_catalog.pg_proc p
            JOIN pg_catalog.pg_namespace n
            ON n.oid = p.pronamespace
        WHERE n.nspname not like 'pg%'
          AND n.nspname <> 'information_schema'
    LOOP
        RAISE NOTICE '_function: %', _function;
    END LOOP;

    -- constraints
    --------------
    FOR rel IN _tables
    LOOP
        RAISE NOTICE '_constraints: %', rel; -- FIXME: probably worth burying in `reconsile_constraints`
        SELECT INTO ddl
            SELECT deploy.reconcile_constraints(
                rel.s_schema, rel.s_relname, rel.s_oid,
                rel.t_schema, rel.t_relname, rel.t_oid);
        RETURN NEXT dll;
    END LOOP;



    -- tables
    ---------
    FOR rel IN _tables
    LOOP
        RAISE NOTICE '_tables: %', rel;
        SELECT INTO ddln
            SELECT deploy.reconcile_tables(
                rel.s_schema, rel.s_relname, rel.t_schema, rel.t_relname);
        RETURN NEXT dll;
    END LOOP;

-- https://www.postgresql.org/docs/current/functions-info.html



    select pg_get_functiondef(oid)
    from pg_proc
    where proname = 'reconcile_tables'





END
$BODY$
    LANGUAGE plpgsql STABLE;
