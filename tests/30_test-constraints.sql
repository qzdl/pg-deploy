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

-- expecting:
--   drop yeah; create hmm
--   drop {anon-name}check
SELECT deploy.reconcile_constraints('testp', 'con', 33910::INT,
                                    'testr', 'con', 33920::INT);

SELECT conname, pg_get_constraintdef(c.oid) AS constrainddef
FROM pg_constraint c
WHERE conrelid=(
    SELECT attrelid FROM pg_attribute
    WHERE attrelid = (
        SELECT oid
        FROM pg_class
        WHERE relname = table_rec.relname
            AND relnamespace = (SELECT ns.oid FROM pg_namespace ns WHERE ns.nspname = p_schema_name)
    ) AND attname='tableoid');


SELECT * FROM deploy.reconcile_constraints(
    'testp'::INT, 'con'::NAME,
        (SELECT c.oid FROM pg_class c
          INNER JOIN pg_namespace n ON n.oid = c.relnamespace AND c.relname = 'con' AND n.nspname = 'testp'),
    'testr'::NAME, 'con'::NAME,
        (SELECT c.oid FROM pg_class c
          INNER JOIN pg_namespace n ON n.oid = c.relnamespace AND c.relname = 'con' AND n.nspname = 'testr'))
ORDER BY reconcile_constraints DESC;
