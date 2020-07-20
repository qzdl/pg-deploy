/* -*- mode: sql -*-

   interactive.sql

  This file is a scratch-workspace for developing this extension, based on the
  file definitions of everything here.

  This SO question got my brain going about having the definition read and
    applied: <www-url
    "https://stackoverflow.com/questions/27808534/how-to-execute-a-string-result-of-a-stored-procedure-in-postgres">

*/


DO $$
DECLARE
    rdir text :=  '/home/qzdl/git/pg-deploy/';
    func text;
BEGIN
    raise notice '
==========================================
DROP / RECREATE FUNCTION AT  %
==========================================
', (SELECT current_timestamp);

    -- NOTE: can this be done programmatically?
    DROP FUNCTION if EXISTS PUBLIC.reconsile_desired(og_schema_name text, ds_schema_name text, object_name text);

    SELECT INTO func (SELECT file.READ(rdir||'function.sql'));

    -- print definition from file
    -- raise notice '%', func;

EXECUTE func;

        RAISE NOTICE '
==========================================
COMPLETED at %
==========================================', (SELECT current_timestamp);

END $$;

DO $$
DECLARE cmd text;
BEGIN
  FOR cmd in SELECT deploy.reconcile_constraints('testp', 'con', 33910::int, 'testr', 'con', 33920::int)
  LOOP
    raise NOTICE 'cmd: %', cmd;
    execute cmd;
  END LOOP;
END $$

\d testp.con



--                                      ██                    ██            ██
--                                     ░██                   ░░            ░██
--   █████   ██████  ███████   ██████ ██████ ██████  ██████   ██ ███████  ██████  ██████
--  ██░░░██ ██░░░░██░░██░░░██ ██░░░░ ░░░██░ ░░██░░█ ░░░░░░██ ░██░░██░░░██░░░██░  ██░░░░
-- ░██  ░░ ░██   ░██ ░██  ░██░░█████   ░██   ░██ ░   ███████ ░██ ░██  ░██  ░██  ░░█████
-- ░██   ██░██   ░██ ░██  ░██ ░░░░░██  ░██   ░██    ██░░░░██ ░██ ░██  ░██  ░██   ░░░░░██
-- ░░█████ ░░██████  ███  ░██ ██████   ░░██ ░███   ░░████████░██ ███  ░██  ░░██  ██████
--  ░░░░░   ░░░░░░  ░░░   ░░ ░░░░░░     ░░  ░░░     ░░░░░░░░ ░░ ░░░   ░░    ░░  ░░░░░░
-- constraints

-- expecting:
--   ADD i int
--   ADD iii bit
--   DROP iv
SELECT PUBLIC.reconsile_desired('testp', 'testr', 'a');

DROP TABLE IF EXISTS testp.con;
DROP TABLE IF EXISTS testr.con;
CREATE TABLE testp.con(
    i int constraint yeah CHECK (i>),
    ii int check (ii > i),
    iii int check (0>iii));
create table testr.con(
    i int constraint hmm CHECK(i>ii),
    ii int,
    iii int check (0>iii));

-- expecting:
--   drop yeah; create hmm
--   drop {anon-name}check
SELECT deploy.reconcile_constraints('testp', 'con', 33910::int,
                                    'testr', 'con', 33920::int)

SELECT conname, pg_get_constraintdef(c.oid) as constrainddef
FROM pg_constraint c
WHERE conrelid=(
    SELECT attrelid FROM pg_attribute
    WHERE attrelid = (
        SELECT oid
        FROM pg_class
        WHERE relname = table_rec.relname
            AND relnamespace = (SELECT ns.oid FROM pg_namespace ns WHERE ns.nspname = p_schema_name)
    ) AND attname='tableoid')


-- get oids for n constraints across two schemata
SELECT 'testp.con', oid
FROM pg_class
WHERE relname = 'con'
    AND relnamespace = (SELECT ns.oid FROM pg_namespace ns WHERE ns.nspname = 'testp')
union
   SELECT 'testr.con', oid
FROM pg_class
WHERE relname = 'con'
    AND relnamespace = (SELECT ns.oid FROM pg_namespace ns WHERE ns.nspname = 'testr')

-- the difference between TEXT and NAME!!!!!! in psql processing, text is
-- coalesced, but in function execution, they aren't!! This was noticed in an
-- iteration of `deploy.reconcile_schema`, where the args were ::text, and the
-- query below (from the arguments) was just buggin outon some undefined
-- behaviour. If in doubt, `pg_typeof()` and explicit typing!
WITH candidates as (
     SELECT c.relname, c.oid, n.nspname
     FROM pg_catalog.pg_class c
          LEFT JOIN pg_catalog.pg_namespace n
              ON n.oid = c.relnamespace
     WHERE relkind = 'r'
     AND (n.nspname = 'testr' OR n.nspname = 'testp')
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
     WHERE nspname = 'testp'
 ) AS active
 LEFT JOIN (
     SELECT nspname, relname, oid
     FROM candidates
     WHERE nspname = 'testr'
 ) AS target
 ON active.relname = target.relname


-- indices; LEFT RIGHT null problem if we use the set of indices for RELATION
-- from the source schema, then there is the potential for error in not having a
-- way to detect NEW indexes (not present in LEFT, but in RIGHT)
-- 'testp'::name, 34175::integer, 'testr'::name, 34182::integer

WITH indices AS -- all source,target
(
    SELECT indrelid, indexrelid, ic.relname,
           n.nspname, pg_get_indexdef(indexrelid) AS def
    FROM pg_catalog.pg_index AS i
    INNER JOIN pg_catalog.pg_class AS ic
        ON ic.oid = i.indexrelid
    INNER JOIN pg_catalog.pg_namespace AS n
        ON n.oid = ic.relnamespace
    WHERE i.indrelid IN (35036::oid, 35042::oid)
)
SELECT 'DROP' AS sign, indexrelid, relname, indrelid, def
FROM indices AS m
WHERE nspname = 'testp'::name
  AND NOT EXISTS (
    SELECT indexrelid, relname
    FROM indices AS i
    WHERE i.nspname = 'testr'::name
      AND i.relname = m.relname)
UNION ALL
SELECT 'DELTA' AS sign, indexrelid, relname, indrelid, def
FROM indices AS m
WHERE nspname = 'testr'::name
  AND (
    NOT EXISTS (
      SELECT indexrelid, relname
      FROM indices AS i
      WHERE i.nspname = 'testp'::name
        AND i.relname = m.relname)
    OR m.def <> (SELECT def
                 FROM indices AS i
                 WHERE i.nspname = 'testp'::name
                   AND i.relname = m.relname))

--                  ██              ██               ██
--                 ░██             ░██              ░██
--  ██████  █████  ░██     ██████ ██████  ██████   ██████  █████   ██████
-- ░░██░░█ ██░░░██ ░██    ██░░░░ ░░░██░  ░░░░░░██ ░░░██░  ██░░░██ ██░░░░
--  ░██ ░ ░███████ ░██   ░░█████   ░██    ███████   ░██  ░███████░░█████
--  ░██   ░██░░░░  ░██    ░░░░░██  ░██   ██░░░░██   ░██  ░██░░░░  ░░░░░██
-- ░███   ░░██████ ███    ██████   ░░██ ░░████████  ░░██ ░░██████ ██████
-- ░░░     ░░░░░░ ░░░    ░░░░░░     ░░   ░░░░░░░░    ░░   ░░░░░░ ░░░░░░
-- rel states:
--   state table showing LEFT and RIGHT states across the above
--   this is to be used as the default core logic to reconcile
--   'stateless' objects; functions, triggers, indices

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
      AND n.nspname IN ('testp', 'testr')
    ORDER BY n.nspname
)
SELECT DISTINCT
      CASE WHEN t_schema IS NULL THEN
        'DROP FUNCTION IF EXISTS '||s_schema||'.'||s_id
           WHEN s_schema IS NULL THEN
        replace(pg_get_functiondef(t_oid),
          'testr'||'.', 'testp'||'.')
      ELSE '-- LEFT and RIGHT of '''||s_id||''' are equal' END AS ddl -- ,COALESCE(s_schema, 'CREATE') as s_schema,      -- s_objname,      -- s_oid, --  pg_get_functiondef(s_oid) as s_def, pg_get_functions_identity_arguments(s_oid) as s_iargs      -- s_id,      -- COALESCE(t_schema, 'DROP') as t_schema,      -- t_objname,      -- t_oid, --  ,pg_get_functiondef(t_oid) as t_def, pg_get_function_identity_arguments(t_oid) as t_def,      -- t_id
FROM (
    WITH ss AS (
        SELECT nspname, objname, oid, id
        FROM fun
        WHERE nspname = 'testp'
    ),
    tt AS (
        SELECT nspname, objname, oid, id
        FROM fun
        WHERE nspname = 'testr'
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
) as AAA;

--  ██      ██         ██                                            ██
-- ░██     ░░   █████ ░██                                           ░██
-- ░██      ██ ██░░░██░██       █████  ██████    ██████  ██████     ░██  █████   ██████
-- ░██████ ░██░██  ░██░██████  ██░░░██░░██░░█   ██░░░░██░░██░░█  ██████ ██░░░██ ░░██░░█
-- ░██░░░██░██░░██████░██░░░██░███████ ░██ ░   ░██   ░██ ░██ ░  ██░░░██░███████  ░██ ░
-- ░██  ░██░██ ░░░░░██░██  ░██░██░░░░  ░██     ░██   ░██ ░██   ░██  ░██░██░░░░   ░██
-- ░██  ░██░██  █████ ░██  ░██░░██████░███     ░░██████ ░███   ░░██████░░██████ ░███
-- ░░   ░░ ░░  ░░░░░  ░░   ░░  ░░░░░░ ░░░       ░░░░░░  ░░░     ░░░░░░  ░░░░░░  ░░░
-- higher order:
--   A generalisation of the diff logic, based on `id` column of CTE as identifier
-- for the object, irrespective of the schema to which it belongs. An example of
-- this would the function `pg_get_function_identity` from `pg_catalog`.
--   So, would it be possible to have a CTE as a function? if so, a reference to
-- an arbitrary function can be given, which gives some 'higher order'
-- functionality. I will try to achieve this without dynamic plsql if possible.

-- Use ~select * from my_func()~ as opposed to ~select my_func()~; the latter
-- will not intern the column identifiers, so given components ~RETURNS
-- TABLE(right text, left text)~, and ~RETURN QUERY SELECT 'a' as left, 'b' as
-- right~, only the ~select *~ will allow the consequent query to use qualified
-- names ~<cte>.left, <cte>.right~.
drop function if exists deploy.function_cte(source_schema name, target_schema name);
create function deploy.function_cte(source_schema name, target_schema name)
RETURNS table(nspname name, objname name, oid oid, id text) AS
$BODY$
BEGIN
    RETURN QUERY
    SELECT n.nspname as nspname,
           p.proname as objname,
           p.oid     as oid,
           p.proname||'('||pg_get_function_identity_arguments(p.oid)||')'
                     as id
    FROM pg_catalog.pg_proc p
        JOIN pg_catalog.pg_namespace n
        ON n.oid = p.pronamespace
    WHERE n.nspname not like 'pg%'
      AND n.nspname <> 'information_schema'
      AND n.nspname IN (source_schema, target_scheman)
    ORDER BY n.nspname;
END;
$BODY$
    LANGUAGE plpgsql STABLE;

drop function if exists deploy.tfunction_cte(source_schema name, target_schema name);
create function deploy.tfunction_cte(source_schema name, target_schema name)
RETURNS TEXT AS
$BODY$
BEGIN
    RETURN FORMAT('
    SELECT n.nspname as nspname,
           p.proname as objname,
           p.oid     as oid,
           p.proname||''(''||pg_get_function_identity_arguments(p.oid)||'')''
                     as id
    FROM pg_catalog.pg_proc p
        JOIN pg_catalog.pg_namespace n
        ON n.oid = p.pronamespace
    WHERE n.nspname not like ''pg%%''
      AND n.nspname <> ''information_schema''
      AND n.nspname IN (%1$L, %2$L)
    ORDER BY n.nspname', source_schema, target_schema);
END;
$BODY$
    LANGUAGE plpgsql STABLE;

DROP FUNCTION IF EXISTS deploy.object_state(source_schema name, target_schema name, cte_fun text);
CREATE OR REPLACE FUNCTION deploy.object_state(source_schema name, target_schema name, cte_fun text)
RETURNS TABLE(
    s_schema name, s_objname name, s_oid oid, s_id text,
    t_schema name, t_objname name, t_oid oid, t_id text
) AS $BODY$
BEGIN
    RETURN QUERY EXECUTE FORMAT('
    with fun as (
        select * from %1$s($1, $2)
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


-- triggers:
-- get triggers for REL in SCHEMA
