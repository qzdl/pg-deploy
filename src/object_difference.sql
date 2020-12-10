-- pgdeploy.object_difference.sql
--
-- ARGUMENT `cte_fun':
--   must return a set of `(nspname name, objname name, oid oid, id text)' that
--   corresponds to the relevant properties of each object. See
--   `./pgdeploy.cte.function.sql` for an example.

CREATE OR REPLACE FUNCTION pgdeploy.object_difference(
    source_schema name, target_schema name, cte_fun text,
    soid oid default NULL, toid oid default NULL)
RETURNS TABLE(
    s_schema name, s_objname name, s_oid oid, s_id text,
    t_schema name, t_objname name, t_oid oid, t_id text
) AS $BODY$
DECLARE
    oids text := '';
BEGIN
    IF (soid IS NOT NULL AND toid IS NOT NULL) THEN
        oids := ' ,'||soid||','||toid;
    END IF;

    RETURN QUERY EXECUTE FORMAT('
    with fun as (
        select * from %1$s($1,$2'||oids||')
    )
    SELECT DISTINCT
        s_schema, s_objname, s_oid, s_id,
        t_schema, t_objname, t_oid, t_id
    FROM (
        WITH ss AS (
            SELECT nspname, objname, oid, id
            FROM fun
            WHERE nspname = $1
        ),   tt AS (
            SELECT nspname, objname, oid, id
            FROM fun
            WHERE nspname = $2
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
        UNION ALL
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
    ) as AAA', cte_fun, source_schema, target_schema) USING source_schema, target_schema;
END; $BODY$ LANGUAGE plpgsql STABLE;

--SELECT * FROM pgdeploy.object_difference('testp'::name, 'testr'::name, 'pgdeploy.cte_function'::text);
