-- types

CREATE TYPE testp.myenum AS ENUM ('arp', 'yarp', 'yep', 'yes', 'affirmative');

CREATE TYPE testp.myrange AS RANGE (subtype = float8, subtype_diff = float8mi);


CREATE TYPE testp.mycomp AS (f1 int, f2 text);
CREATE TYPE testp.mycompint AS (f1 int, f2 int);


CREATE TYPE testp.empty;

-- base type (FIXME: on hold)
-- DROP function if exists testp.fin;
-- DROP function if exists testp.fout;
-- create or replace function testp.fin(a int) returns int as $body$ begin return 0; end; $body$ language plpgsql;
-- create or replace function testp.fout(a int) returns int as $body$ begin return 0; end; $body$ language plpgsql;
-- CREATE TYPE testp.io AS (input = testp.fin, output = testp.fout);


-- extended type info query
SELECT
  'CREATE TYPE '||n.nspname||'.'||t.typname||' AS '
  ||(CASE
  WHEN t.typrelid != 0 THEN --comp
    CAST('tuple' AS pg_catalog.text)
  WHEN t.typlen < 0       -- range
      THEN CAST('var' AS pg_catalog.text)
  ELSE -- enum
    'ENUM ('||pg_catalog.array_to_string(ARRAY(
      SELECT ''''||e.enumlabel||''''
      FROM pg_catalog.pg_enum e
      WHERE e.enumtypid = t.oid
      ORDER BY e.enumsortorder), ', ')||')'
  END)||';' as ddl,
  pg_catalog.format_type(t.oid, NULL) AS "Name",
  t.typname AS "Internal name"
FROM pg_catalog.pg_type t
     LEFT JOIN pg_catalog.pg_namespace n ON n.oid = t.typnamespace
WHERE (t.typrelid = 0 OR (SELECT c.relkind = 'c' FROM pg_catalog.pg_class c WHERE c.oid = t.typrelid))
  AND NOT EXISTS(SELECT 1 FROM pg_catalog.pg_type el WHERE el.oid = t.typelem AND el.typarray = t.oid)
      AND n.nspname <> 'pg_catalog'
      AND n.nspname <> 'information_schema'
  AND pg_catalog.pg_type_is_visible(t.oid)
ORDER BY 1, 2;

CREATE or replace FUNCTION IIF(
    condition boolean,       -- IF condition
    true_result anyelement,  -- THEN
    false_result anyelement  -- ELSE
) RETURNS anyelement AS $f$
  SELECT CASE WHEN condition THEN true_result ELSE false_result END
$f$  LANGUAGE SQL IMMUTABLE;


-- range type info
-- subtype_opclass
SELECT
  pg_catalog.format_type(rngsubtype, NULL) AS rngsubtype,
  opc.opcname AS opcname,
  (SELECT nspname FROM pg_catalog.pg_namespace nsp
   WHERE nsp.oid = opc.opcnamespace) AS opcnsp,
  opc.opcdefault,

  CASE WHEN rngcollation = st.typcollation THEN 0
       ELSE rngcollation END AS collation,
  -- array_to_string(ARRAY['subtype = '||rngsubtype,
  --   IIF(opcdefault <> 't', 'subtype_opclass = '||'TODONAMESPACE'||'.'||opcname, NULL),
  --   IIF(rngsubdiff::text <> '-', 'subtype_diff = ' || rngsubdiff, NULL),
  --   IIF(rngcanonical::text <> '-', 'canonical = ' || rngcanonical, NULL),
  --   IIF(rngcollation <> 0, 'collation = ' || rngcollation, NULL)], ',\n  ') AS ddl,
rngsubdiff, rngtypid, rngcollation
  FROM pg_catalog.pg_range r,
       pg_catalog.pg_type st,
       pg_catalog.pg_opclass opc
  WHERE st.oid = rngsubtype AND opc.oid = rngsubopc
--  AND rngtypid = SOMETHING WHAT

select array_to_string(array[1,2], E',\n  ')

select array(1,2,4)
