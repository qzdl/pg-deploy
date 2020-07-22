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
    i int constraint yeah CHECK (i>0),
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
                                    'testr', 'con', 33920::int);

SELECT conname, pg_get_constraintdef(c.oid) as constrainddef
FROM pg_constraint c
WHERE conrelid=(
    SELECT attrelid FROM pg_attribute
    WHERE attrelid = (
        SELECT oid
        FROM pg_class
        WHERE relname = table_rec.relname
            AND relnamespace = (SELECT ns.oid FROM pg_namespace ns WHERE ns.nspname = p_schema_name)
    ) AND attname='tableoid');


select * from deploy.reconcile_constraints(
    'testp'::name, 'con'::name, (SELECT c.oid FROM pg_class c INNER JOIN pg_namespace n ON n.oid = c.relnamespace and c.relname = 'con' and n.nspname = 'testp'),
    'testr'::name, 'con'::name, (SELECT c.oid FROM pg_class c INNER JOIN pg_namespace n ON n.oid = c.relnamespace and c.relname = 'con' and n.nspname = 'testr'))
order by reconcile_constraints desc
