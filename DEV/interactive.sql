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
