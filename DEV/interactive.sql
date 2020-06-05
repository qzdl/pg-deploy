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
', (select current_timestamp);

    -- NOTE: can this be done programmatically?
    drop function if exists public.reconsile_desired(og_schema_name text, ds_schema_name text, object_name text);

    select into func (select file.read(rdir||'function.sql'));

raise notice '%', func;

execute func;

        RAISE NOTICE '
==========================================
COMPLETED at %
==========================================', (select current_timestamp);

END $$;

-- now we can make stuff and test whatever
-- check what exists
\df public.*;

create schema if not exists testr;
create schema if not exists testp;
drop table if exists testr.a;
drop table if exists testp.a;

create table testr.a(i int, ii text, iii bit);
create table testp.a(ii text, iv text);

select public.reconsile_desired('testr', 'testp', 'a');


--

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
