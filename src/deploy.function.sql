CREATE SCHEMA IF NOT EXISTS deploy;

DROP FUNCTION IF EXISTS deploy.reconcile_function(
    source_schema name, target_schema name);

CREATE OR REPLACE FUNCTION deploy.reconcile_function(
    source_schema name, target_schema name)
RETURNS SETOF TEXT AS
$BODY$
BEGIN
    RETURN QUERY
    with fun as (
        SELECT quote_ident(n.nspname) as nspname,
               quote_ident(p.proname) as objname,
               p.oid                  as oid,
               p.proname||'('||
                 pg_get_function_identity_arguments(p.oid)||')' as id
        FROM pg_catalog.pg_proc p
            JOIN pg_catalog.pg_namespace n
            ON n.oid = p.pronamespace
        WHERE n.nspname not like 'pg%'
          AND n.nspname <> 'information_schema'
          AND n.nspname IN (source_schema, target_schema)
        ORDER BY n.nspname
    )
    SELECT DISTINCT
          CASE WHEN t_schema IS NULL THEN
            'DROP FUNCTION IF EXISTS '||s_schema||'.'||s_id
               WHEN s_schema IS NULL THEN
            replace(pg_get_functiondef(t_oid),
              target_schema||'.', source_schema||'.')
          ELSE '-- LEFT and RIGHT of '''||s_id||''' are equal' END AS ddl --, COALESCE(s_schema, 'CREATE') as s_schema, s_objname, s_oid, pg_get_functiondef(s_oid) as s_def, pg_get_functions_identity_arguments(s_oid) as s_iargs, s_id, COALESCE(t_schema, 'DROP') as t_schema, t_objname, t_oid, --  ,pg_get_functiondef(t_oid) as t_def, pg_get_function_identity_arguments(t_oid) as t_def, t_id
    FROM (
        WITH ss AS (
            SELECT nspname, objname, oid, id
            FROM fun
            WHERE nspname = source_schema
        ),
        tt AS (
            SELECT nspname, objname, oid, id
            FROM fun
            WHERE nspname = target_schema
        )
        SELECT s.nspname as s_schema,
               s.objname as s_objname,
               s.oid     as s_oid,
               s.id      as s_id,
               t.nspname as t_schema,
               t.objname as t_objname,
               t.oid     as t_oid,
               t.id      as t_id
        FROM ss as s
        LEFT JOIN tt as t ON s.id = t.id
        UNION
        SELECT s.nspname  as s_schema,
               s.objname  as s_objname,
               s.oid      as s_oid,
               s.id       as s_id,
               t.nspname  as t_schema,
               t.objname  as t_objname,
               t.oid      as t_oid,
               t.id as t_id
        FROM tt as t
        LEFT JOIN ss as s ON s.id = t.id
    ) as AAA;
END;
$BODY$
    LANGUAGE plpgsql STABLE;

select deploy.reconcile_function('testp', 'testr');
