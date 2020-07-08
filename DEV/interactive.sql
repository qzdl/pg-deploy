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
CREATE TABLE testp.a(
ii text,
iv numeric CONSTRAINT positive_price CHECK (iv > 0));


CREATE TABLE testr.b(ii text);
-- expecting:
-- DROP i
-- DROP iii
-- ADD iv text

SELECT deploy.reconcile_tables('testr', 'testp', 'a', 'a');


-- expecting:
-- ADD i int
-- ADD iii bit
-- DROP iv
SELECT PUBLIC.reconsile_desired('testp', 'testr', 'a');

DROP TABLE IF EXISTS testp.con;
DROP TABLE IF EXISTS testr.con;

CREATE TABLE testp.con(
    i int constraint yeah CHECK (i>),
    ii int check (ii > i),
    iii int check (0>iii)
);

create table testr.con(i int constraint hmm CHECK(i>ii), ii int, iii int check (0>iii));

-- drop yeah; create hmm
-- drop {anon-name}check
SELECT deploy.reconcile_constraints('testp', 'con', 33910::int,
                                    'testr', 'con', 33920::int)

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



---
---

SELECT conname, pg_get_constraintdef(c.oid) as constrainddef
FROM pg_constraint c
WHERE conrelid=(
    SELECT attrelid FROM pg_attribute
    WHERE attrelid = (
        SELECT oid
        FROM pg_class
        WHERE relname = table_rec.relname
            AND relnamespace = (SELECT ns.oid FROM pg_namespace ns WHERE ns.nspname = p_schema_name)
    ) AND attname='tableoid'

                    )



SELECT 'testp.con', oid
FROM pg_class
WHERE relname = 'con'
    AND relnamespace = (SELECT ns.oid FROM pg_namespace ns WHERE ns.nspname = 'testp')
union
   SELECT 'testr.con', oid
FROM pg_class
WHERE relname = 'con'
    AND relnamespace = (SELECT ns.oid FROM pg_namespace ns WHERE ns.nspname = 'testr')

--
-- Index; test column change

DROP TABLE IF EXISTS testp.idx;
DROP TABLE IF EXISTS testr.idx;

CREATE TABLE testp.idx (
    a text,
    b int,
    c boolean,
    d uuid
);

CREATE INDEX idx_hash on testp.idx using hash (d);

CREATE TABLE testr.idx (
    a text,
    b int,
    c boolean,
    d uuid
);

CREATE INDEX idx_hash on testr.idx using hash (b);

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


--     ██               ██                     ██                     ██
--    ░░               ░██                    ░██                    ░██
--     ██ ███████      ░██  █████  ██   ██   ██████  █████   ██████ ██████  ██████
--    ░██░░██░░░██  ██████ ██░░░██░░██ ██   ░░░██░  ██░░░██ ██░░░░ ░░░██░  ██░░░░
--    ░██ ░██  ░██ ██░░░██░███████ ░░███      ░██  ░███████░░█████   ░██  ░░█████
--    ░██ ░██  ░██░██  ░██░██░░░░   ██░██     ░██  ░██░░░░  ░░░░░██  ░██   ░░░░░██
--    ░██ ███  ░██░░██████░░██████ ██ ░░██    ░░██ ░░██████ ██████   ░░██  ██████
--    ░░ ░░░   ░░  ░░░░░░  ░░░░░░ ░░   ░░      ░░   ░░░░░░ ░░░░░░     ░░  ░░░░░░


-----|| NO LEFT, RIGHT
-- expecting CREATE from definition testr ONTO testp
--   as "create index nlr_idx on testp.nlr using hash (a);"
drop table if exists testp.nlr;
drop table if exists testr.nlr;
create table testp.nlr(a text);
create table testr.nlr(a text);
drop index if exists testp.nlr_idx;
drop index if exists testr.nlr_idx;
create index nlr_idx on testr.nlr using hash (a); -- *expected output too
select deploy.reconcile_index(
    'testp'::name,
    (select c.oid from pg_class c inner join pg_namespace n on c.relnamespace = n.oid and n.nspname = 'testp' where relname = 'nlr'),
    'testr'::name,
    (select c.oid from pg_class c inner join pg_namespace n on c.relnamespace = n.oid and n.nspname = 'testr' where relname = 'nlr'));
-----|| LEFT, NO RIGHT
-- expecting DROP from RELNAME on testp
--   as "DROP INDEX testp.lnr;"
drop table if exists testp.lnr;
drop table if exists testr.lnr;
create table testp.lnr(a text);
create table testr.lnr(a text);
drop index if exists testp.lnr_idx;
drop index if exists testr.lnr_idx;
create index lnr_idx on testp.lnr using hash (a);
select deploy.reconcile_index(
    'testp'::name,
    (select c.oid from pg_class c inner join pg_namespace n on c.relnamespace = n.oid and n.nspname = 'testp' where relname = 'lnr'),
    'testr'::name,
    (select c.oid from pg_class c inner join pg_namespace n on c.relnamespace = n.oid and n.nspname = 'testr' where relname = 'lnr'));
-----|| LEFT, RIGHT :: MOD
-- expecting DROP from RELNAME on testp
--   as "DROP INDEX testp.lrm;"
-- expecting CREATE from definition testr ONTO testp
--   as "create index lrm_idx on testp.lrm using hash (a);"
drop table if exists testp.lrm;
drop table if exists testr.lrm;
create table testp.lrm(a text, b text);
create table testr.lrm(a text, b text);
drop index if exists testp.lrm_idx;
drop index if exists testr.lrm_idx;
create index lrm_idx on testp.lrm using hash (a);
create index lrm_idx on testr.lrm using hash (b); -- *expected output too
select deploy.reconcile_index(
    'testp'::name,
    (select c.oid from pg_class c inner join pg_namespace n on c.relnamespace = n.oid and n.nspname = 'testp' where relname = 'lrm'),
    'testr'::name,
    (select c.oid from pg_class c inner join pg_namespace n on c.relnamespace = n.oid and n.nspname = 'testr' where relname = 'lrm'));
-----|| LEFT, RIGHT :: NO MOD
-- expecting NOTHING
drop table if exists testp.lrnm;
drop table if exists testr.lrnm;
create table testp.lrnm(a text, b text);
create table testr.lrnm(a text, b text);
drop index if exists testp.lrnm_idx;
drop index if exists testr.lrnm_idx;
create index lrnm_idx on testp.lrnm using hash (a);
create index lrnm_idx on testr.lrnm using hash (a);
select deploy.reconcile_index(
    'testp'::name,
    (select c.oid from pg_class c inner join pg_namespace n on c.relnamespace = n.oid and n.nspname = 'testp' where relname = 'lrnm'),
    'testr'::name,
    (select c.oid from pg_class c inner join pg_namespace n on c.relnamespace = n.oid and n.nspname = 'testr' where relname = 'lrnm'));



select deploy.reconcile_index(
    'testp'::name,
    (select c.oid from pg_class c inner join pg_namespace n on c.relnamespace = n.oid and n.nspname = 'testp' where relname = 'lnr'),
    'testr'::name,
    (select c.oid from pg_class c inner join pg_namespace n on c.relnamespace = n.oid and n.nspname = 'testr' where relname = 'lnr'));



select deploy.reconcile_index(
    'testp'::name,
    (select c.oid from pg_class c inner join pg_namespace n on c.relnamespace = n.oid and n.nspname = 'testp' where relname = 'lrm'),
    'testr'::name,
    (select c.oid from pg_class c inner join pg_namespace n on c.relnamespace = n.oid and n.nspname = 'testr' where relname = 'lrm'));
