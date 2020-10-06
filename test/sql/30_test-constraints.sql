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
--SELECT PUBLIC.reconsile_desired('testp', 'testr', 'a');

CREATE SCHEMA testp;
CREATE SCHEMA testr;
DROP TABLE IF EXISTS testp.con;
DROP TABLE IF EXISTS testr.con;
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


-- expecting:
--   drop yeah; create hmm
--   drop {anon-name}check
SELECT * FROM pgdeploy.reconcile_constraints(
  'testp'::NAME, 'con'::NAME,
  (SELECT c.oid FROM pg_class c
          INNER JOIN pg_namespace n ON n.oid = c.relnamespace AND c.relname = 'con' AND n.nspname = 'testp'),
    'testr'::NAME, 'con'::NAME,
        (SELECT c.oid FROM pg_class c
          INNER JOIN pg_namespace n ON n.oid = c.relnamespace AND c.relname = 'con' AND n.nspname = 'testr'))
ORDER BY reconcile_constraints DESC;
