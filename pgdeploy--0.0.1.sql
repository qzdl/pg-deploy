/*
pgdeploy.reconcile_schema is the main function of pgdeploy. The function returns the final product
of transformation rules ordered by priority (order of execution).
The role of priority follows the object type dependency.
For instance a table can be dependent on a type or a function,
a function can be dependent on a type, thus the order is table, function, type.
*/

CREATE SCHEMA IF NOT EXISTS pgdeploy;
CREATE OR REPLACE FUNCTION pgdeploy.reconcile_schema(
    source_schema name, target_schema name)
RETURNS TABLE(priority int, ddl text) AS
$BODY$
BEGIN
    RAISE NOTICE '%', (select CASE WHEN 'testr'::name = target_schema THEN 'y' else 'n' end);

    RETURN QUERY
    with candidates as (
        SELECT * FROM pgdeploy.object_difference(
            source_schema, target_schema, 'pgdeploy.cte_relation')
        WHERE s_schema IS NOT NULL AND t_schema IS NOT NULL
    )
    SELECT 1 AS priority, pgdeploy.reconcile_relation(source_schema, target_schema) AS ddl
    UNION  -- attributes
    SELECT 2 AS priority, pgdeploy.reconcile_table_attributes(
        s_schema, s_objname, s_oid,
        t_schema, t_objname, t_oid) AS ddl
    FROM candidates
    UNION  -- constraints
    SELECT 3 AS priority, pgdeploy.reconcile_constraints(
        s_schema, s_objname, s_oid,
        t_schema, t_objname, t_oid) AS ddl
    FROM candidates
    -- UNION ALL -- triggers
    -- SELECT 4, pgdeploy.reconcile_triggers(
    --     s_schema, s_objname, s_oid,
    --     t_schema, s_objname, s_oid)
    -- ) FROM candidates
    UNION  -- indices
    SELECT 5, pgdeploy.reconcile_index(s_schema, s_oid, t_schema, t_oid)
    FROM candidates
    UNION  -- functions
    SELECT 6, pgdeploy.reconcile_function(source_schema, target_schema);
    -- types
    -- enums
    -- sequences
END;
$BODY$
    LANGUAGE plpgsql STABLE;
CREATE OR REPLACE FUNCTION pgdeploy.cte_attribute(
    source_schema name, target_schema name, soid oid, toid oid)
RETURNS TABLE(
    nspname name, objname name, oid oid, id text) AS
$BODY$
BEGIN
    RETURN QUERY
    SELECT DISTINCT
        n.nspname AS nspname,
        a.attname AS objname,
        cl.oid    AS oid,
        a.attname||atttypid AS id
      FROM pg_attribute AS a
      INNER JOIN pg_class AS cl ON cl.oid = a.attrelid AND cl.oid IN (soid, toid)
      INNER JOIN (
        SELECT n.nspname, n.oid FROM pg_namespace n
          WHERE n.nspname IN (source_schema, target_schema)
      ) AS n ON n.oid = cl.relnamespace
      WHERE a.attnum > 0; -- columns only;
END;
$BODY$
    LANGUAGE plpgsql STABLE;

--select * from pgdeploy.cte_attribute(
--    'testp'::name, 'testr'::name,
--    (SELECT c.oid FROM pg_class c INNER JOIN pg_namespace n ON n.oid = c.relnamespace and c.relname = 'con' and n.nspname = 'testp'),
--    (SELECT c.oid FROM pg_class c INNER JOIN pg_namespace n ON n.oid = c.relnamespace and c.relname = 'con' and n.nspname = 'testr'));
CREATE OR REPLACE FUNCTION pgdeploy.cte_constraint(
    source_schema name, target_schema name, soid oid, toid oid)
RETURNS TABLE(
    nspname name, objname name, oid oid, id text) AS
$BODY$
BEGIN
    RETURN QUERY
    SELECT DISTINCT
        n.nspname AS nspname,
        c.conname AS objname,
        c.oid     AS oid,
        c.conname ||' '||pg_get_constraintdef(c.oid)
                  AS id
    FROM pg_constraint AS c
    INNER JOIN pg_class AS cl ON cl.oid = c.conrelid AND cl.oid IN (soid, toid)
    INNER JOIN pg_attribute AS a ON a.attrelid = cl.oid
    INNER JOIN (
      SELECT n.nspname, n.oid
      FROM pg_namespace n
      WHERE n.nspname IN (source_schema, target_schema)
    ) AS n ON n.oid = cl.relnamespace;
END;
$BODY$
    LANGUAGE plpgsql STABLE;

--select * from pgdeploy.cte_constraint(
--    'testp'::name, 'testr'::name,
--    (SELECT c.oid FROM pg_class c INNER JOIN pg_namespace n ON n.oid = c.relnamespace and c.relname = 'con' and n.nspname = 'testp'),
--    (SELECT c.oid FROM pg_class c INNER JOIN pg_namespace n ON n.oid = c.relnamespace and c.relname = 'con' and n.nspname = 'testr'));
CREATE FUNCTION pgdeploy.cte_event_trigger(_ name, __ name)
RETURNS TABLE(
    nspname name, objname name, oid oid, id text) AS
$BODY$
BEGIN
    RETURN QUERY
    SELECT
      (CASE WHEN STRPOS(evtname, '__deploy__') > 0
        THEN 'target'
        ELSE 'source' END)::name AS nspname,
          split_part(evtname, '__deploy__', 1)::name AS objname,
          e.oid AS oid,
          split_part(evtname, '__deploy__', 1)||evtevent||evtenabled
            ||array_to_string(
              ARRAY( SELECT quote_literal(x) FROM UNNEST(evttags) AS t(x)),'') AS id
      FROM pg_catalog.pg_event_trigger AS e
      ORDER BY nspname;
END;
$BODY$
    LANGUAGE plpgsql STABLE;

--SELECT * FROM pgdeploy.cte_event_trigger(''::name,''::name);
--
--SELECT * FROM pgdeploy.object_difference(
--  'source'::name,'target'::name,'pgdeploy.cte_event_trigger'::name)
CREATE FUNCTION pgdeploy.cte_function(
    source_schema name, target_schema name)
RETURNS TABLE(
    nspname name, objname name, oid oid, id text) AS
$BODY$
BEGIN
    RETURN QUERY
    SELECT
        n.nspname AS nspname,
        p.proname AS objname,
        p.oid     AS oid,
        replace((CASE WHEN l.lanname = 'internal'
           THEN p.proname||p.prosrc||pg_get_function_arguments(p.oid)
           ELSE pg_get_functiondef(p.oid) END),
          target_schema||'.', source_schema||'.') AS id
      FROM pg_catalog.pg_proc p
      INNER JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
      LEFT JOIN pg_language l ON p.prolang = l.oid
      WHERE n.nspname NOT LIKE 'pg%'
        AND n.nspname <> 'information_schema'
        AND n.nspname IN (source_schema, target_schema)
      ORDER BY n.nspname;
END;
$BODY$
    LANGUAGE plpgsql STABLE;

--SELECT *  FROM pgdeploy.cte_function('testp', 'testr');

-- select p.prosrc, p.* from pg_aggregate a
-- inner join pg_proc p on a.aggfnoid = p.oid
-- where p.proname = 'cavg'
CREATE FUNCTION pgdeploy.cte_index(
    source_schema name, target_schema name,
    source_oid oid, target_oid oid)
RETURNS TABLE(
    nspname name, objname name, oid oid, id text) AS
$BODY$
BEGIN
    RETURN QUERY
    SELECT
        n.nspname AS nspname,
        ic.relname AS objname,
        indexrelid AS oid,
        replace(pg_get_indexdef(indexrelid), target_schema||'.', source_schema||'.') AS id
    FROM pg_catalog.pg_index AS i
    INNER JOIN pg_catalog.pg_class AS ic ON ic.oid = i.indexrelid
    INNER JOIN pg_catalog.pg_namespace AS n ON n.oid = ic.relnamespace
    WHERE i.indrelid = source_oid or i.indrelid = target_oid
    ORDER BY n.nspname;
END;
$BODY$
    LANGUAGE plpgsql STABLE;

--SELECT * FROM pgdeploy.cte_index('testp', 'testr',
--  (select c.oid from pg_class c inner join pg_namespace n on c.relnamespace = n.oid and n.nspname = 'testp' where relname = 'lnr'),
--  (select c.oid from pg_class c inner join pg_namespace n on c.relnamespace = n.oid and n.nspname = 'testr' where relname = 'lnr'));
CREATE FUNCTION pgdeploy.cte_relation(
    source_schema name, target_schema name)
RETURNS TABLE(
    nspname name, objname name, oid oid, id text) AS
$BODY$
BEGIN
    RETURN QUERY
    SELECT
        n.nspname AS nspname,
        c.relname AS objname,
        c.oid     AS oid,
        c.relname||'' AS id
      FROM pg_catalog.pg_class c
      INNER JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
      WHERE relkind = 'r'
        AND (n.nspname = source_schema OR n.nspname = target_schema)
      ORDER BY n.nspname;
END;
$BODY$
    LANGUAGE plpgsql STABLE;

--SELECT * FROM pgdeploy.cte_relation('testp', 'testr');
DROP FUNCTION IF EXISTS pgdeploy.cte_trigger(
    source_schema name, target_schema name,
    source_oid oid, target_oid oid);

CREATE FUNCTION pgdeploy.cte_trigger(
    source_schema name, target_schema name,
    source_oid oid, target_oid oid)
RETURNS TABLE(
    nspname name, objname name, oid oid, id text) AS
$BODY$
BEGIN
    RETURN QUERY
    SELECT n.nspname  AS nspname,
           tg.tgname AS objname,
           tg.oid     AS oid,
           replace(pg_get_triggerdef(tg.oid), target_schema||'.', source_schema||'.')
                      AS id
      FROM pg_catalog.pg_trigger AS tg
      INNER JOIN pg_catalog.pg_class AS ic ON ic.oid = tg.tgrelid
      INNER JOIN pg_catalog.pg_namespace AS n ON n.oid = ic.relnamespace
      WHERE tg.tgrelid = source_oid OR tg.tgrelid = target_oid
      ORDER BY n.nspname;
END;
$BODY$
    LANGUAGE plpgsql STABLE;

--SELECT * FROM pgdeploy.cte_trigger('testp'::name, 'testr'::name,
--  (select c.oid from pg_class c inner join pg_namespace n on c.relnamespace = n.oid and n.nspname = 'testp' where relname = 'nlr'),
--  (select c.oid from pg_class c inner join pg_namespace n on c.relnamespace = n.oid and n.nspname = 'testr' where relname = 'nlr'));


-- SELECT * FROM pgdeploy.object_difference('testp'::name, 'testr'::name, 'cte_trigger'::name,
--   (select c.oid from pg_class c inner join pg_namespace n on c.relnamespace = n.oid and n.nspname = 'testp' where relname = 'lrnm2'),
--   (select c.oid from pg_class c inner join pg_namespace n on c.relnamespace = n.oid and n.nspname = 'testr' where relname = 'lrnm2'));
CREATE OR REPLACE FUNCTION pgdeploy.cte_type(
    source_schema name, target_schema name)
RETURNS TABLE(
    nspname name, objname name, oid oid, id text) AS
$BODY$
BEGIN
    RETURN QUERY
    SELECT DISTINCT
        n.nspname AS nspname,
        t.typname AS objname,
        t.oid     AS oid,
        (array_to_string(array[ -- all identifying type props (typrelid, typarray)
          typname, typlen::text, typbyval::text, typtype::text,
          typcategory::text, typispreferred::text, typisdefined::text,
          typdelim::text, typelem::text, typinput::text, typoutput::text,
          typreceive::text, typsend ::text, typmodin::text, typmodout::text,
          typanalyze::text, typalign::text, typstorage::text, typnotnull::text,
          typbasetype::text, typtypmod::text, typndims::text,
          typcollation::text, typdefaultbin::text, typdefault::text,
          typacl::text], ',')
        -- ||array_to_string(array(
        --     SELECT e.enumlabel FROM pg_catalog.pg_enum e WHERE e.enumtypid = t.oid), ',')
        -- ||COALESCE((SELECT rngsubtype||opcname||rngsubdiff||rngcanonical||rngcollation
        --             FROM pg_catalog.pg_range r
        --               LEFT JOIN pg_catalog.pg_type st ON st.oid = r.rngsubtype
        --               LEFT JOIN pg_catalog.pg_opclass opc ON r.rngsubopc = opc.oid
        --             WHERE r.rngtypid = t.oid),''))
        )     AS id
    FROM pg_catalog.pg_type t
      LEFT JOIN pg_catalog.pg_namespace n ON n.oid = t.typnamespace
    WHERE (t.typrelid = 0 OR (SELECT c.relkind = 'c' FROM pg_catalog.pg_class c WHERE c.oid = t.typrelid))
      AND NOT EXISTS (SELECT 1 FROM pg_catalog.pg_type el WHERE el.oid = t.typelem AND el.typarray = t.oid)
      AND n.nspname <> 'pg_catalog'
      AND n.nspname <> 'information_schema'
      AND n.nspname IN (source_schema, target_schema);
END;
$BODY$
    LANGUAGE plpgsql STABLE;

--select * from pgdeploy.cte_type('testp'::name, 'testr'::name);
--select * from pgdeploy.object_difference('testp'::name, 'testr'::name, 'pgdeploy.cte_type');
-- split / replace '--deploy--' as signifier for deploy owned event triggers
CREATE OR REPLACE FUNCTION pgdeploy.reconcile_event_trigger()
RETURNS SETOF TEXT AS
$BODY$
BEGIN
    RETURN QUERY
    WITH tr AS (
      SELECT DISTINCT
          t_schema,
          s_schema,
          s_objname,
          e.oid,
          evtname,
          evtenabled,
          evtevent,
          array_to_string(
            ARRAY(SELECT quote_literal(x)
                  FROM UNNEST(evttags) AS t(x)), ', ') AS evttags,
          e.evtfoid::regproc AS evtfname
      FROM pgdeploy.object_difference(
        'source'::name,'target'::name,'pgdeploy.cte_event_trigger'::name) AS od
      INNER JOIN pg_catalog.pg_event_trigger AS e
        ON e.oid = od.s_oid OR e.oid = od.t_oid
    )
    SELECT CASE
      WHEN t_schema IS NULL THEN
        'DROP EVENT TRIGGER IF EXISTS '||s_objname||';'
      WHEN s_schema IS NULL THEN
        'CREATE EVENT TRIGGER '||evtname||' ON '||evtevent       -- event listener
        ||(CASE WHEN evttags IS NOT NULL AND LENGTH(evttags) > 0 -- tags
           THEN ' WHEN TAG IN ('||evttags||') '                  -- tags
           ELSE '' END)                                          -- tags
        ||' EXECUTE FUNCTION '||evtfname||'();'                  -- event function
        ||(CASE WHEN evtenabled = 'O' THEN '' ELSE '
    ALTER EVENT TRIGGER '||evtname||' '||(                       -- second ddl statement,
            CASE WHEN evtenabled = 'D' THEN 'DISABLE'            -- for enabling trigger
                 WHEN evtenabled = 'A' THEN 'ENABLE ALWAYS'
                 WHEN evtenabled = 'R' THEN 'ENABLE REPLICA'
                 ELSE 'ENABLE' END)||';' END)
      ELSE
        '-- EVENT TRIGGER: LEFT and RIGHT of '''||s_objname||''' on '''||evtevent||''' are equal'
      END AS ddl
    FROM tr
    ORDER BY ddl DESC; -- comments and drops first
END;
$BODY$
    LANGUAGE plpgsql STABLE;

--select * from pgdeploy.reconcile_event_trigger();
CREATE OR REPLACE FUNCTION pgdeploy.reconcile_function(
    source_schema name, target_schema name)
RETURNS SETOF TEXT AS
$BODY$
BEGIN
    RETURN QUERY
    SELECT DISTINCT CASE
      WHEN t_schema IS NULL THEN
        'DROP '|| (CASE WHEN a.aggfnoid IS NOT NULL THEN 'AGGREGATE' ELSE 'FUNCTION' END)
         ||' IF EXISTS '||s_schema||'.'||s_objname||';'
      WHEN s_schema IS NULL THEN
        replace((CASE WHEN l.lanname = 'internal'
           THEN '-- unsupported function definition ('||t_objname||') '||p.prosrc
           ELSE pg_get_functiondef(t_oid) END),
          target_schema||'.', source_schema||'.')
      ELSE
        '-- LEFT and RIGHT of '''||s_objname||''' are equal'
      END AS ddl
    FROM pgdeploy.object_difference(source_schema, target_schema, 'pgdeploy.cte_function')
    INNER JOIN pg_proc p ON p.oid = s_oid OR p.oid = t_oid
    LEFT JOIN pg_language l ON p.prolang = l.oid
    LEFT JOIN pg_aggregate a ON a.aggfnoid = p.oid
    ORDER BY ddl DESC; -- comments and drops first
END;
$BODY$
    LANGUAGE plpgsql STABLE;

--select * from pgdeploy.reconcile_function('testp', 'testr');
-- https://www.postgresql.org/docs/current/catalog-pg-index.html
-- Is index for foo.bar(a b c) equal to foop.bar(a b c)?
-- algorithm (hash gist gin)
-- # of attrs covered
-- # of key attrs
-- collation
-- expression trees (indexprs, indpred); if not nil, s=t? dispatch t, pass
-- indices can be referenced by SCHEMA.INDEX_NAME, as they have to be unique per namespace
CREATE OR REPLACE FUNCTION pgdeploy.reconcile_index(
    source_schema name, source_oid oid,
    target_schema name, target_oid oid)
RETURNS SETOF TEXT AS
$BODY$
BEGIN
    RETURN QUERY
    SELECT DISTINCT CASE
        WHEN t_schema IS NULL THEN
          'DROP INDEX IF EXISTS '||s_schema||'.'||s_objname
        WHEN s_schema IS NULL THEN
          replace(pg_get_indexdef(t_oid),
            target_schema||'.', source_schema||'.')
        ELSE
          '-- LEFT and RIGHT of '''||s_objname||''' are equal'
        END AS ddl
    FROM pgdeploy.object_difference(
      source_schema, target_schema, 'pgdeploy.cte_index', source_oid, target_oid);
END;
$BODY$
    LANGUAGE plpgsql STABLE;

--select * from pgdeploy.reconcile_index(
--  'testp'::name, (select c.oid from pg_class c inner join pg_namespace n on c.relnamespace = n.oid and n.nspname = 'testp' where relname = 'lnr'),
--  'testr'::name, (select c.oid from pg_class c inner join pg_namespace n on c.relnamespace = n.oid and n.nspname = 'testr' where relname = 'lnr'));
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
CREATE OR REPLACE FUNCTION pgdeploy.reconcile_relation(
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
      FROM pgdeploy.object_difference(source_schema, target_schema, 'pgdeploy.cte_relation')
      ORDER BY ddl DESC; -- comments and drops first
END;
$BODY$
    LANGUAGE plpgsql STABLE;

--select * from pgdeploy.reconcile_relation('testp', 'testr');
CREATE OR REPLACE FUNCTION pgdeploy.reconcile_table_attributes(
    source_schema name, source_rel name, source_oid oid,
    target_schema name, target_rel name, target_oid oid)
RETURNS SETOF text AS
$BODY$
BEGIN
    RETURN QUERY
    WITH info AS (
        SELECT
            od.*,
            pg_catalog.format_type(a.atttypid, a.atttypmod) as column_type,
          CASE WHEN (
            SELECT substring(pg_catalog.pg_get_expr(d.adbin, d.adrelid) for 128)
              FROM   pg_catalog.pg_attrdef d
              WHERE  d.adrelid = a.attrelid AND d.adnum = a.attnum AND a.atthasdef
          ) IS NOT NULL THEN
              'DEFAULT '|| (
              SELECT substring(pg_catalog.pg_get_expr(d.adbin, d.adrelid) for 128)
                FROM   pg_catalog.pg_attrdef d
                WHERE  d.adrelid = a.attrelid AND d.adnum = a.attnum AND a.atthasdef
          ) ELSE NULL
          END AS column_default_value,
          CASE WHEN a.attnotnull = true THEN 'NOT NULL' ELSE 'NULL' END AS column_not_null
          FROM pgdeploy.object_difference(
             source_schema, target_schema,
             'pgdeploy.cte_attribute', source_oid, target_oid) AS od
          LEFT JOIN pg_catalog.pg_attribute a
            ON ((a.attrelid = od.t_oid and a.attname = od.t_objname)
             OR (a.attrelid = od.s_oid AND a.attname = od.s_objname))
          WHERE a.attnum > 0
            AND NOT a.attisdropped
    ) -- eo info
    SELECT DISTINCT CASE
      WHEN t_schema IS NULL THEN
        'ALTER TABLE '||source_schema||'.'||source_rel||
        ' DROP COLUMN '||s_objname||';'

      WHEN s_schema IS NULL THEN
        'ALTER TABLE '||source_schema||'.'||source_rel||
        ' ADD COLUMN '||array_to_string(ARRAY[t_objname, column_type,
        column_default_value, column_not_null],' ')||';'

      ELSE '-- COLUMN: no change for '||s_objname END AS ddl
    FROM info;
END;
$BODY$
    LANGUAGE plpgsql STABLE;

-- select * FROM pgdeploy.object_difference(
--   'testp'::name, 'testr'::name, 'pgdeploy.cte_attribute',
--    (SELECT c.oid FROM pg_class c INNER JOIN pg_namespace n
--       ON n.oid = c.relnamespace and c.relname = 'a' and n.nspname = 'testp'),
--    (SELECT c.oid FROM pg_class c INNER JOIN pg_namespace n
--       ON n.oid = c.relnamespace and c.relname = 'a' and n.nspname = 'testr'))
--       order by s_objname, t_objname;

-- select * from pgdeploy.reconcile_table_attributes(
--     'testp'::name, 'a'::name, (SELECT c.oid FROM pg_class c INNER JOIN pg_namespace n ON n.oid = c.relnamespace and c.relname = 'a' and n.nspname = 'testp'),
--     'testr'::name, 'a'::name, (SELECT c.oid FROM pg_class c INNER JOIN pg_namespace n ON n.oid = c.relnamespace and c.relname = 'a' and n.nspname = 'testr'));
/*
    reconcile_constraints:
    - diff of constraints for tables through general logic
    - mark for ALTER / DROP
    - barf a sensible comment for that which remains unchanged

*/
CREATE OR REPLACE FUNCTION pgdeploy.reconcile_constraints(
    source_schema name, source_rel name, source_oid oid,
    target_schema name, target_rel name, target_oid oid)
RETURNS SETOF text AS
$BODY$
DECLARE
    _constraints record;
    ddl text;
BEGIN
    RAISE NOTICE 'RECONCILE CONSTRAINT: %', source_schema||':'||source_rel||':'||source_oid||'|'||target_schema||':'||target_rel||':'||target_oid;

    RETURN QUERY
    SELECT DISTINCT
        CASE WHEN t_schema IS NULL THEN
          'ALTER TABLE '||source_schema||'.'||source_rel||' DROP CONSTRAINT IF EXISTS '||s_objname||';'
             WHEN s_schema IS NULL THEN
          'ALTER TABLE '||source_schema||'.'||source_rel
            ||' ADD CONSTRAINT '||t_objname||' '||pg_get_constraintdef(t_oid)||';'
             ELSE
          '-- CONSTRAINT: LEFT and RIGHT of '''||s_id||''' are equal'
        END AS ddl
      FROM pgdeploy.object_difference(
        source_schema, target_schema,
        'pgdeploy.cte_constraint',
        source_oid, target_oid)
      ORDER BY ddl DESC;
END;
$BODY$
    LANGUAGE plpgsql STABLE;

--select * from pgdeploy.reconcile_constraints(
--    'testp'::name, 'con'::name, (SELECT c.oid FROM pg_class c INNER JOIN pg_namespace n ON n.oid = c.relnamespace and c.relname = 'con' and n.nspname = 'testp'),
--    'testr'::name, 'con'::name, (SELECT c.oid FROM pg_class c INNER JOIN pg_namespace n ON n.oid = c.relnamespace and c.relname = 'con' and n.nspname = 'testr'));
CREATE OR REPLACE FUNCTION pgdeploy.reconcile_trigger(
    source_schema name, source_oid oid,
    target_schema name, target_oid oid)
RETURNS SETOF TEXT AS
$BODY$
BEGIN
    RETURN QUERY
    SELECT DISTINCT CASE
        WHEN t_schema IS NULL THEN
          'DROP TRIGGER IF EXISTS '||s_objname||' ON '||s_schema||'.'||c.relname||';'
        WHEN s_schema IS NULL THEN
          replace(pg_get_triggerdef(t_oid),
            target_schema||'.', source_schema||'.')
        ELSE
          '-- TRIGGER: LEFT and RIGHT of '''||s_objname||''' on '''||c.relname||''' are equal'
        END AS ddl
    FROM pgdeploy.object_difference(
      source_schema, target_schema,
      'pgdeploy.cte_trigger', source_oid, target_oid) AS od
    INNER JOIN pg_trigger as tg ON tg.oid = od.s_oid OR tg.oid = od.t_oid
    INNER JOIN pg_class AS c ON c.oid = tg.tgrelid
    ORDER BY ddl DESC; -- comments and drops first
END;
$BODY$
    LANGUAGE plpgsql STABLE;

--select * from pgdeploy.reconcile_trigger(
--'testp'::name, (select c.oid from pg_class c inner join pg_namespace n on c.relnamespace = n.oid and n.nspname = 'testp' where relname = 'nlr'),
--'testr'::name, (select c.oid from pg_class c inner join pg_namespace n on c.relnamespace = n.oid and n.nspname = 'testr' where relname = 'nlr'))

-- -- ENUM:

-- -- positional semantics? does the index of a given enumlabel matter?
-- -- recursive enums?
-- -- alter statement based on the difference in the set of enumlabel for TYPE
-- --   add, respecting positions with BEFORE / AFTER
-- --   comment line for element removal, "unsupported", but give the create definition

-- -- CREATE OR WARN
-- -- TODO: check if the contents of [RANGE | ENUM] are equal, dispatch accordingly
-- DROP FUNCTION IF EXISTS pgdeploy.reconcile_type(
--     source_schema name, target_schema name);

-- CREATE OR REPLACE FUNCTION pgdeploy.reconcile_type(
--     source_schema name, target_schema name)
-- RETURNS SETOF TEXT AS
-- $BODY$
-- BEGIN
--     RETURN QUERY
--     WITH info AS (
--       SELECT
--         t.typname, t.typlen, t.typrelid,
--         s_schema, s_objname, s_oid, t_schema, t_objname, t_oid
--       FROM pgdeploy.object_difference(source_schema, target_schema, 'pgdeploy.cte_type')
--       INNER JOIN pg_type t ON t.oid = s_oid OR t.oid = t_oid
--     ), range AS (
--       SELECT i.oid, array_to_string(ARRAY[
--         'subtype = '||(SELECT typname FROM pg_type t2 WHERE t2.oid = r.rngsubtype),
--          CASE WHEN opcdefault <> 't' THEN 'subtype_opclass = '||source_schema||'.'||opcname ELSE NULL END,
--          CASE WHEN rngsubdiff::text <> '-' THEN 'subtype_diff = ' || rngsubdiff ELSE NULL END,
--          CASE WHEN rngcanonical::text <> '-' THEN 'canonical = ' || rngcanonical ELSE NULL END,
--          CASE WHEN rngcollation <> 0 THEN 'collation = ' || rngcollation ELSE NULL END], E',\n  ') AS range_body
--       FROM pg_catalog.pg_range r
--       INNER JOIN info i on i.oid = r.rngtypid
--       LEFT JOIN pg_catalog.pg_type st ON st.oid = r.rngsubtype
--       LEFT JOIN pg_catalog.pg_opclass opc ON r.rngsubopc = opc.oid
--     ), enumitems AS (
--       SELECT distinct i.typname, i.oid, e.enumtypid, ''''||e.enumlabel||'''' AS label, e.enumsortorder as sort
--       FROM pg_catalog.pg_enum e
--       INNER JOIN info i ON e.
--       ORDER BY e.enumsortorder
--     ), enumdiff as (
--       SELECT DISTINCT ei.oid, ei.label, ei.sort, ei.typname
--       FROM enumitems AS ei WHERE ei.nspname = source_schema
--         AND NOT EXISTS(
--         SELECT 1 FROM enumitems AS et
--         WHERE et.nspname = target_schema
--           AND et.typname = ei.typname
--           AND et.label = ei.label
--           AND et.sort = ei.sort
--       )
--       UNION
--       SELECT DISTINCT ei.oid, ei.label, ei.sort, ei.typname
--       FROM enumitems AS ei WHERE ei.nspname = target_schema
--         AND NOT EXISTS(
--         SELECT 1 FROM enumitems AS et
--         WHERE et.nspname = source_schema
--           AND et.typname = ei.typname
--           AND et.label = ei.label
--           AND et.sort = ei.sort
--      )
--     )
--     SELECT DISTINCT CASE
--       WHEN t_schema IS NULL THEN       -- @STATE: DROP
--         'DROP TYPE IF EXISTS '||s_schema||'.'||s_objname||';'
--       WHEN s_schema IS NULL THEN (CASE -- @STATE: CREATE OR WARN
--         WHEN i.typrelid != 0 THEN -- @CATEGORY: COMPOSITE
--           'CREATE TYPE '||source_schema||'.'||i.typname||' AS '||CAST('tuple' AS pg_catalog.text)
--         WHEN i.typlen < 0 THEN    -- @CATEGORY: RANGE
--           'CREATE TYPE '||source_schema||'.'||i.typname||E' AS (\n  '||r.range_body
--         ELSE                -- @CATEGORY: ENUM
--             'CREATE TYPE '||source_schema||'.'||i.typname||E' AS ENUM(\n  '
--             ||array_to_string(array(select e.label
--                                     from enumitems e
--                                     where e.oid = i.oid
--                                     order by e.sort), E'\n  ')
--         END)||E'\n);'             -- @CATEGORY: END
--       ELSE CASE                        -- @STATE: EQUAL (for `id` as defined in `cte_type`)
--         WHEN i.typrelid != 0 AND 1=0 THEN -- @CATEGORY: COMPOSITE
--           '-- @TYPE: difference in comp '||i.typname
--         WHEN i.typlen < 0  and 1=0 THEN    -- @CATEGORY: RANGE
--           '-- @TYPE: difference in range '||i.typname
--         WHEN EXISTS(SELECT 1 FROM enumdiff AS ed WHERE ed.oid = i.oid) THEN -- @CATEGORY: ENUM
--           E'-- @TYPE: ***WARNING***\n-- The ENUM '||i.typname||' has difference in members, please check the suitability of DROP/CREATE:'
--           ||E'\nDROP TYPE '||source_schema||'.'||i.typname||E';\n'
--           ||'CREATE TYPE '||source_schema||'.'||i.typname||E' AS ENUM(\n  '
--           ||array_to_string(array(select e.enumlabel
--                                   from pg_enum e
--                                   where e.enumtypid = i.t_oid
--                                   order by e.enumsortorder), E'\n  ')
--           ||E'\n);'

--         ELSE '-- @TYPE: LEFT and RIGHT of '''||s_schema||'.'||s_objname||''' are equal.'
--         END
--       END AS ddl                       -- @STATE: END
--     FROM info i
--     LEFT JOIN range r ON r.oid = i.oid
--     ORDER BY ddl DESC; -- comments and drops first
-- END;
-- $BODY$
--     LANGUAGE plpgsql STABLE;


--select * from pgdeploy.reconcile_type('testp', 'testr');




-- WITH info AS (
--       SELECT
--         t.oid, t.typname, t.typlen, t.typrelid,
--         s_schema, s_objname, t_schema, t_objname
--       FROM pgdeploy.object_difference('testp'::name, 'testr'::name, 'pgdeploy.cte_type')
--       INNER JOIN pg_type t ON t.oid = s_oid OR t.oid = t_oid
--     ), range AS (
--       SELECT i.oid, array_to_string(ARRAY[
--         'subtype = '||(SELECT typname FROM pg_type t2 WHERE t2.oid = r.rngsubtype),
--          CASE WHEN opcdefault <> 't' THEN 'subtype_opclass = '||'testp'||'.'||opcname ELSE NULL END,
--          CASE WHEN rngsubdiff::text <> '-' THEN 'subtype_diff = ' || rngsubdiff ELSE NULL END,
--          CASE WHEN rngcanonical::text <> '-' THEN 'canonical = ' || rngcanonical ELSE NULL END,
--          CASE WHEN rngcollation <> 0 THEN 'collation = ' || rngcollation ELSE NULL END], E',\n  ') AS range_body
--       FROM pg_catalog.pg_range r
--       INNER JOIN info i on i.oid = r.rngtypid
--       LEFT JOIN pg_catalog.pg_type st ON st.oid = r.rngsubtype
--       LEFT JOIN pg_catalog.pg_opclass opc ON r.rngsubopc = opc.oid
--     ), enumitems AS ( -- enumlabel items?
--       SELECT i.oid, ''''||e.enumlabel||'''' AS label, e.enumsortorder as sort
--       FROM pg_catalog.pg_enum e
--       INNER JOIN info i ON e.enumtypid = i.oid
--       ORDER BY e.enumsortorder
--     )
--     -- enum diff
--       SELECT typname||(CASE WHEN COALESCE(s_schema, t_schema) = 'testp' THEN 0 ELSE 1 END) as typname,
--       label, sort
--       FROM info i
--       INNER JOIN enumitems ei on ei.oid = i.oid
--       WHERE typname = 'enumdroplast' and array['some', 1::text] = array['some', 1::text]
--       ORDER BY sort, typname;




-- WITH info AS (
--       SELECT
--         t.oid, t.typname, t.typlen, t.typrelid,
--         s_schema, s_objname, t_schema, t_objname,
--         COALESCE(s_schema, t_schema) AS schemata
--       FROM pgdeploy.object_difference('testp'::name, 'testr'::name, 'pgdeploy.cte_type')
--       INNER JOIN pg_type t ON t.oid = s_oid OR t.oid = t_oid
--     ), range AS (
--       SELECT i.oid, array_to_string(ARRAY[
--         'subtype = '||(SELECT typname FROM pg_type t2 WHERE t2.oid = r.rngsubtype),
--          CASE WHEN opcdefault <> 't' THEN 'subtype_opclass = '||'testp'||'.'||opcname ELSE NULL END,
--          CASE WHEN rngsubdiff::text <> '-' THEN 'subtype_diff = ' || rngsubdiff ELSE NULL END,
--          CASE WHEN rngcanonical::text <> '-' THEN 'canonical = ' || rngcanonical ELSE NULL END,
--          CASE WHEN rngcollation <> 0 THEN 'collation = ' || rngcollation ELSE NULL END], E',\n  ') AS range_body
--       FROM pg_catalog.pg_range r
--       INNER JOIN info i on i.oid = r.rngtypid
--       LEFT JOIN pg_catalog.pg_type st ON st.oid = r.rngsubtype
--       LEFT JOIN pg_catalog.pg_opclass opc ON r.rngsubopc = opc.oid
--     ), enumitems AS ( -- enumlabel items?
--       SELECT i.oid, ''''||e.enumlabel||'''' AS label, e.enumsortorder as sort
--       FROM pg_catalog.pg_enum e
--       INNER JOIN info i ON e.enumtypid = i.oid
--       ORDER BY e.enumsortorder
--     )
--     -- enum diff
--     SELECT distinct
--     s_sort, s_name, s_label, t_label
--     FROM (
--       WITH ss AS (
--         SELECT typname||(case when i.schemata = 'testp' THEN 0 ELSE 1 END) as typnameN, typname,
--                array[typname, sort::text] as id, sort, label
--         FROM info i
--         INNER JOIN enumitems ei on ei.oid = i.oid
--         WHERE i.schemata = 'testp'
--       ), tt AS (
--         SELECT typname||(case when i.schemata = 'testp' THEN 0 ELSE 1 END) as typnameN, typname,
--                array[typname, sort::text] as id, sort, label
--         FROM info i
--         INNER JOIN enumitems ei on ei.oid = i.oid
--         WHERE i.schemata = 'testr'
--       )
--       SELECT
--         ss.id      as s_id,
--         ss.sort    as s_sort,
--         ss.typname as s_name,
--         ss.label   as s_label,
--         tt.id      as t_id,
--         tt.sort    as t_sort,
--         tt.typname as t_name,
--         ss.label   as t_label
--       FROM ss LEFT JOIN tt on tt.id = ss.id
--       UNION
--       SELECT
--         ss.id      as s_id,
--         ss.sort    as s_sort,
--         ss.typname as s_name,
--         ss.label   as s_label,
--         tt.id      as t_id,
--         tt.sort    as t_sort,
--         tt.typname as t_name,
--         tt.label   as t_label
--       FROM tt LEFT JOIN ss ON tt.id = ss.id
--     ) as b
--     WHERE s_label <> t_label
--     order by s_name, s_sort


-- WITH info AS (
--       SELECT
--         t.oid, n.nspname, t.typname, t.typlen, t.typrelid,
--         s_schema, s_objname, t_schema, t_objname
--       FROM pgdeploy.object_difference('testp'::name, 'testr'::name, 'pgdeploy.cte_type')
--       INNER JOIN pg_type t ON t.oid = s_oid OR t.oid = t_oid
--       INNER JOIN pg_namespace n ON n.oid = t.typnamespace
--     ), range AS (
--       SELECT i.oid, array_to_string(ARRAY[
--         'subtype = '||(SELECT typname FROM pg_type t2 WHERE t2.oid = r.rngsubtype),
--          CASE WHEN opcdefault <> 't' THEN 'subtype_opclass = '||'testp'::name||'.'||opcname ELSE NULL END,
--          CASE WHEN rngsubdiff::text <> '-' THEN 'subtype_diff = ' || rngsubdiff ELSE NULL END,
--          CASE WHEN rngcanonical::text <> '-' THEN 'canonical = ' || rngcanonical ELSE NULL END,
--          CASE WHEN rngcollation <> 0 THEN 'collation = ' || rngcollation ELSE NULL END], E',\n  ') AS range_body
--       FROM pg_catalog.pg_range r
--       INNER JOIN info i on i.oid = r.rngtypid
--       LEFT JOIN pg_catalog.pg_type st ON st.oid = r.rngsubtype
--       LEFT JOIN pg_catalog.pg_opclass opc ON r.rngsubopc = opc.oid
--     ), enumitems AS (
--       SELECT i.typname, i.oid, ''''||e.enumlabel||'''' AS label, e.enumsortorder as sort, i.nspname
--       FROM pg_catalog.pg_enum e
--       INNER JOIN info i ON e.enumtypid = i.oid
--       ORDER BY e.enumsortorder
--     ), enumdiff as (
--       SELECT DISTINCT ei.oid, ei.label, ei.sort, ei.typname
--       FROM enumitems AS ei WHERE ei.nspname = 'testp'::name
--         AND NOT EXISTS(
--         SELECT 1 FROM enumitems AS et
--         WHERE et.nspname = 'testr'::name
--           AND et.typname = ei.typname
--           AND et.label = ei.label
--           AND et.sort = ei.sort
--       )
--       UNION
--       SELECT DISTINCT ei.oid, ei.label, ei.sort, ei.typname
--       FROM enumitems AS ei WHERE ei.nspname = 'testr'::name
--         AND NOT EXISTS(
--         SELECT 1 FROM enumitems AS et
--         WHERE et.nspname = 'testp'::name
--           AND et.typname = ei.typname
--           AND et.label = ei.label
--           AND et.sort = ei.sort
--      )
--     )
--     SELECT distinct i.oid, ed.*
--     FROM info i
--     LEFT JOIN range r ON r.oid = i.oid
--     INNER JOIN enumdiff ed on ed.oid = i.oid
--     order by i.oid
