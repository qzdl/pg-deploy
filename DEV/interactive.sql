/* interactive.sql

  This file is a scratch-workspace for developing this extension, based on the
  file definitions of everything here. 

  This SO question got my brain going about having the definition read and applied:
    <www-url "https://stackoverflow.com/questions/27808534/how-to-execute-a-string-result-of-a-stored-procedure-in-postgres">

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

-- now we can make stuff and test whatever
-- check what exists
\df PUBLIC.*;

-- prep environment for diff
CREATE SCHEMA if NOT EXISTS testr;
CREATE SCHEMA if NOT EXISTS testp;
DROP TABLE if EXISTS testr.a;
DROP TABLE if EXISTS testp.a;

-- create objs for diff
CREATE TABLE testr.a(i int, ii text, iii bit);
CREATE TABLE testp.a(ii text, iv numeric CONSTRAINT positive_price CHECK (iv > 0));

-- expecting:
-- DROP i
-- DROP iii
-- ADD iv text
SELECT PUBLIC.reconsile_desired('testr', 'testp', 'a');

-- expecting:
-- ADD i int
-- ADD iii bit
-- DROP iv
SELECT PUBLIC.reconsile_desired('testp', 'testr', 'a');
--
-- constraints
-- SELECT conname,
--        pg_get_constraintdef(c.oid) AS constrainddef
-- FROM pg_constraint c
-- WHERE conrelid=(
--     SELECT attrelid
--     FROM pg_attribute
--     WHERE attrelid = (
--         SELECT oid
--         FROM pg_class
--         WHERE relname = 'a'
--          AND relnamespace = (SELECT ns.oid FROM pg_namespace ns WHERE ns.nspname = 'testp')
--     )
--     AND attname='tableoid'
-- );


-- select public.describe_table('testr', 'a');

  -- with signs as (
  --               select 'DROP' as sign,
  --                      r_source.column_name as col
  --               from information_schema.columns as r_source
  --               where table_name = 'a'  -- to yield d0
  --                 and table_schema = 'testr'
  --                 and not exists (
  --                   select column_name
  --                   from information_schema.columns as r_target
  --                   where r_target.table_name = 'a'
  --                     and r_target.table_schema = 'testp'
  --                     and r_source.column_name = r_target.column_name) -- AJ predicate
  --               union -- inverse for `ADD'
  --               select 'ADD' as sign,
  --                      a_target.column_name as col
  --               from information_schema.columns as a_target
  --
  --               where table_name = 'a'       -- to yield d1
  --                 and table_schema = 'testp'
  --                 and not exists (
  --                   select column_name
  --                   from information_schema.columns as a_source
  --                   where a_source.table_name = 'a'
  --                     and a_source.table_schema = 'testr'
  --                     and a_source.column_name = a_target.column_name) -- AJ predicate
  --           )
  --           SELECT
  --               signs.sign,
  --               signs.col,
  --               b.nspname as schema_name,
  --               b.relname as table_name,
  --               a.attname as column_name,
  --               pg_catalog.format_type(a.atttypid, a.atttypmod) as column_type,
  --               -- defaults; FIXME: maybe throw into CTE to reduce duplication of query logic?
  --               CASE WHEN
  --                   (SELECT substring(pg_catalog.pg_get_expr(d.adbin, d.adrelid) for 128)
  --                    FROM   pg_catalog.pg_attrdef d
  --                    WHERE  d.adrelid = a.attrelid AND d.adnum = a.attnum AND a.atthasdef)
  --               IS NOT NULL THEN
  --                   'DEFAULT '|| (SELECT substring(pg_catalog.pg_get_expr(d.adbin, d.adrelid) for 128)
  --                                 FROM pg_catalog.pg_attrdef d
  --                                 WHERE d.adrelid = a.attrelid AND d.adnum = a.attnum AND a.atthasdef)
  --               ELSE
  --                   ''
  --               END as column_default_value,
  --               CASE WHEN a.attnotnull = true THEN
  --                   'NOT NULL'
  --               ELSE
  --                   'NULL'
  --               END as column_not_null,
  --               a.attnum as attnum,
  --               e.max_attnum as max_attnum
  --           FROM
  --               pg_catalog.pg_attribute a
  --               LEFT JOIN signs ON a.attname = signs.col AND signs.sign = 'ADD'
  --               INNER JOIN
  --                (SELECT c.oid,
  --                   n.nspname,
  --                   c.relname
  --                 FROM pg_catalog.pg_class c
  --                      LEFT JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
  --                 WHERE c.oid = 33015
  --                     -- FIXME: visible necessary? these preds should really be applied in the `_tables` query
  --                     -- AND pg_catalog.pg_table_is_visible(c.oid)
  --                 ORDER BY 2, 3) b
  --               ON a.attrelid = b.oid
  --               INNER JOIN
  --                (SELECT
  --                     a.attrelid,
  --                     max(a.attnum) as max_attnum
  --                 FROM pg_catalog.pg_attribute a
  --                 WHERE a.attnum > 0
  --                   AND NOT a.attisdropped
  --                 GROUP BY a.attrelid) e
  --               ON a.attrelid=e.attrelid
  --           WHERE a.attnum > 0
  --             AND NOT a.attisdropped
  --           ORDER BY a.attnum

--  CREATE OR REPLACE FUNCTION public.describe_table(p_schema_name character varying, p_table_name character varying)
--   RETURNS SETOF text AS
-- $BODY$
-- DECLARE
--     v_table_ddl   text;
--     column_record record;
--     table_rec record;
--     constraint_rec record;
--     firstrec boolean;
-- BEGIN
--     FOR table_rec IN
--         SELECT c.relname, c.oid FROM pg_catalog.pg_class c
--             LEFT JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
--                 WHERE relkind = 'r'
--                 AND n.nspname = 'testr'
--                 AND relname~ ('^('||'a'||')$')
--           ORDER BY c.relname
--     LOOP
--         FOR column_record IN
--             SELECT
--                 b.nspname as schema_name,
--                 b.relname as table_name,
--                 a.attname as column_name,
--                 pg_catalog.format_type(a.atttypid, a.atttypmod) as column_type,
--                 CASE WHEN
--                     (SELECT substring(pg_catalog.pg_get_expr(d.adbin, d.adrelid) for 128)
--                      FROM pg_catalog.pg_attrdef d
--                      WHERE d.adrelid = a.attrelid AND d.adnum = a.attnum AND a.atthasdef) IS NOT NULL THEN
--                     'DEFAULT '|| (SELECT substring(pg_catalog.pg_get_expr(d.adbin, d.adrelid) for 128)
--                                   FROM pg_catalog.pg_attrdef d
--                                   WHERE d.adrelid = a.attrelid AND d.adnum = a.attnum AND a.atthasdef)
--                 ELSE
--                     ''
--                 END as column_default_value,
--                 CASE WHEN a.attnotnull = true THEN
--                     'NOT NULL'
--                 ELSE
--                     'NULL'
--                 END as column_not_null,
--                 a.attnum as attnum,
--                 e.max_attnum as max_attnum
--             FROM
--                 pg_catalog.pg_attribute a
--                 INNER JOIN
--                  (SELECT c.oid,
--                     n.nspname,
--                     c.relname
--                   FROM pg_catalog.pg_class c
--                        LEFT JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
--                   WHERE c.oid = table_rec.oid
--                   ORDER BY 2, 3) b
--                 ON a.attrelid = b.oid
--                 INNER JOIN
--                  (SELECT
--                       a.attrelid,
--                       max(a.attnum) AS max_attnum
--                   FROM pg_catalog.pg_attribute a
--                   WHERE a.attnum > 0
--                     AND NOT a.attisdropped
--                   GROUP BY a.attrelid) e
--                 ON a.attrelid=e.attrelid
--             WHERE a.attnum > 0
--               AND NOT a.attisdropped
--             ORDER BY a.attnum
--         LOOP -- _columns
--             IF column_record.attnum = 1 THEN
--                 v_table_ddl:='CREATE TABLE '||column_record.SCHEMA_NAME||'.'||column_record.TABLE_NAME||' (';
--             ELSE
--                 v_table_ddl:=v_table_ddl||',';
--             END IF;

--             IF column_record.attnum <= column_record.max_attnum THEN
--                 v_table_ddl:=v_table_ddl||chr(10)||
--                          '    '||column_record.column_name||' '||column_record.column_type||' '||column_record.column_default_value||' '||column_record.column_not_null;
--             END IF;
--         END LOOP;

--         firstrec := TRUE;
--         FOR constraint_rec IN
--             SELECT conname, pg_get_constraintdef(c.oid) as constrainddef
--                 FROM pg_constraint c
--                     WHERE conrelid=(
--                         SELECT attrelid FROM pg_attribute
--                         WHERE attrelid = (
--                             SELECT oid FROM pg_class WHERE relname = table_rec.relname
--                                 AND relnamespace = (SELECT ns.oid FROM pg_namespace ns WHERE ns.nspname = p_schema_name)
--                         ) AND attname='tableoid'
--                     )
--         LOOP
--             v_table_ddl:=v_table_ddl||','||chr(10);
--             v_table_ddl:=v_table_ddl||'CONSTRAINT '||constraint_rec.conname;
--             v_table_ddl:=v_table_ddl||chr(10)||'    '||constraint_rec.constrainddef;
--             firstrec := FALSE;
--         END LOOP;
--         v_table_ddl:=v_table_ddl||');';
--         RETURN NEXT v_table_ddl;
--     END LOOP;
-- END;
-- $BODY$
--   LANGUAGE plpgsql VOLATILE
--   COST 100;
