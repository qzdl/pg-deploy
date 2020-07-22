DROP FUNCTION IF EXISTS deploy.cte_constraint(
    source_schema name, target_schema name, soid oid, toid oid);

CREATE OR REPLACE FUNCTION deploy.cte_constraint(
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


select * from deploy.cte_constraint(
    'testp'::name, 'testr'::name,
    (SELECT c.oid FROM pg_class c INNER JOIN pg_namespace n ON n.oid = c.relnamespace and c.relname = 'con' and n.nspname = 'testp'),
    (SELECT c.oid FROM pg_class c INNER JOIN pg_namespace n ON n.oid = c.relnamespace and c.relname = 'con' and n.nspname = 'testr'));

--  nspname |    objname    |  oid  |        id
-- ---------+---------------+-------+-------------------
--  testp   | yeah          | 36050 | CHECK ((i > 0))
--  testp   | yeah          | 36050 | CHECK ((i > 0))
--  testp   | yeah          | 36050 | CHECK ((i > 0))
--  testp   | yeah          | 36050 | CHECK ((i > 0))
--  testp   | yeah          | 36050 | CHECK ((i > 0))
--  testp   | yeah          | 36050 | CHECK ((i > 0))
--  testp   | yeah          | 36050 | CHECK ((i > 0))
--  testp   | yeah          | 36050 | CHECK ((i > 0))
--  testp   | yeah          | 36050 | CHECK ((i > 0))
--  testp   | con_check     | 36051 | CHECK ((ii > i))
--  testp   | con_check     | 36051 | CHECK ((ii > i))
--  testp   | con_check     | 36051 | CHECK ((ii > i))
--  testp   | con_check     | 36051 | CHECK ((ii > i))
--  testp   | con_check     | 36051 | CHECK ((ii > i))
--  testp   | con_check     | 36051 | CHECK ((ii > i))
--  testp   | con_check     | 36051 | CHECK ((ii > i))
--  testp   | con_check     | 36051 | CHECK ((ii > i))
--  testp   | con_check     | 36051 | CHECK ((ii > i))
--  testp   | con_iii_check | 36052 | CHECK ((0 > iii))
--  testp   | con_iii_check | 36052 | CHECK ((0 > iii))
--  testp   | con_iii_check | 36052 | CHECK ((0 > iii))
--  testp   | con_iii_check | 36052 | CHECK ((0 > iii))
--  testp   | con_iii_check | 36052 | CHECK ((0 > iii))
--  testp   | con_iii_check | 36052 | CHECK ((0 > iii))
--  testp   | con_iii_check | 36052 | CHECK ((0 > iii))
--  testp   | con_iii_check | 36052 | CHECK ((0 > iii))
--  testp   | con_iii_check | 36052 | CHECK ((0 > iii))
--  testr   | hmm           | 36056 | CHECK ((i > ii))
--  testr   | hmm           | 36056 | CHECK ((i > ii))
--  testr   | hmm           | 36056 | CHECK ((i > ii))
--  testr   | hmm           | 36056 | CHECK ((i > ii))
--  testr   | hmm           | 36056 | CHECK ((i > ii))
--  testr   | hmm           | 36056 | CHECK ((i > ii))
--  testr   | hmm           | 36056 | CHECK ((i > ii))
--  testr   | hmm           | 36056 | CHECK ((i > ii))
--  testr   | hmm           | 36056 | CHECK ((i > ii))
--  testr   | con_iii_check | 36057 | CHECK ((0 > iii))
--  testr   | con_iii_check | 36057 | CHECK ((0 > iii))
--  testr   | con_iii_check | 36057 | CHECK ((0 > iii))
--  testr   | con_iii_check | 36057 | CHECK ((0 > iii))
--  testr   | con_iii_check | 36057 | CHECK ((0 > iii))
--  testr   | con_iii_check | 36057 | CHECK ((0 > iii))
--  testr   | con_iii_check | 36057 | CHECK ((0 > iii))
--  testr   | con_iii_check | 36057 | CHECK ((0 > iii))
--  testr   | con_iii_check | 36057 | CHECK ((0 > iii))
-- (45 rows)
