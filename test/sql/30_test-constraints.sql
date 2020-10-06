--                                      ██                    ██            ██
--                                     ░██                   ░░            ░██
--   █████   ██████  ███████   ██████ ██████ ██████  ██████   ██ ███████  ██████  ██████
--  ██░░░██ ██░░░░██░░██░░░██ ██░░░░ ░░░██░ ░░██░░█ ░░░░░░██ ░██░░██░░░██░░░██░  ██░░░░
-- ░██  ░░ ░██   ░██ ░██  ░██░░█████   ░██   ░██ ░   ███████ ░██ ░██  ░██  ░██  ░░█████
-- ░██   ██░██   ░██ ░██  ░██ ░░░░░██  ░██   ░██    ██░░░░██ ░██ ░██  ░██  ░██   ░░░░░██
-- ░░█████ ░░██████  ███  ░██ ██████   ░░██ ░███   ░░████████░██ ███  ░██  ░░██  ██████
--  ░░░░░   ░░░░░░  ░░░   ░░ ░░░░░░     ░░  ░░░     ░░░░░░░░ ░░ ░░░   ░░    ░░  ░░░░░░

-- CONSTRAINTS

BEGIN;
SET client_min_messages TO WARNING;
CREATE EXTENSION pgdeploy;

CREATE SCHEMA testp;
CREATE SCHEMA testr;
CREATE TABLE testp.con(
    i INT CONSTRAINT yeah CHECK (i>0),
    ii INT CHECK (ii > i),
    iii INT CHECK (0>iii));

CREATE TABLE testr.con(
    i INT CONSTRAINT hmm CHECK(i>ii),
    ii INT,
    iii INT CHECK (0>iii));

SELECT conname, pg_get_constraintdef(c.oid) AS constrainddef
FROM pg_constraint c
WHERE conrelid IN (
    SELECT attrelid FROM pg_attribute
    WHERE attrelid IN (
        SELECT c.oid
        FROM pg_class c
        INNER JOIN pg_namespace n on n.oid = c.relnamespace
        WHERE c.relname = 'con'
            AND n.nspname IN ('testp', 'testr'))
        AND attname='tableoid');

SELECT * FROM pgdeploy.reconcile_constraints(
  'testp'::NAME, 'con'::NAME,'testp.con'::regclass::oid
    ,'testr'::NAME, 'con'::NAME,'testp.con'::regclass::oid)
ORDER BY reconcile_constraints DESC;


-- CLEAN UP
DROP EXTENSION pgdeploy CASCADE;
ROLLBACK;
