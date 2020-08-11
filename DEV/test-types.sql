-- types

CREATE TYPE testp.myenum AS ENUM ('arp', 'yarp', 'yep', 'yes', 'affirmative');

CREATE TYPE testp.myrange AS RANGE (subtype = float8, subtype_diff = float8mi);


CREATE TYPE testp.mycomp AS (f1 int, f2 text);
CREATE TYPE testp.mycompint AS (f1 int, f2 int);


create type testp.mycomptz AS (f1 timezone without time zone, f2 text);



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
  WHEN t.typrelid != 0 THEN -- comp
    CAST('tuple' AS pg_catalog.text)
  WHEN t.typlen < 0 THEN -- range
    E'(\n  '||(
    SELECT
      array_to_string(ARRAY['subtype = '||format_type(rngsubtype, NULL),
      CASE WHEN opcdefault <> 't' THEN 'subtype_opclass = '||'TODONAMESPACE'||'.'||opcname ELSE NULL END,
      CASE WHEN rngsubdiff::text <> '-' THEN 'subtype_diff = ' || rngsubdiff ELSE NULL END,
      CASE WHEN rngcanonical::text <> '-' THEN 'canonical = ' || rngcanonical ELSE NULL END,
      CASE WHEN rngcollation <> 0 THEN 'collation = ' || rngcollation ELSE NULL END], E',\n  ') AS range_body
    FROM pg_catalog.pg_range r
    LEFT JOIN pg_catalog.pg_type st ON st.oid = r.rngsubtype
    LEFT JOIN pg_catalog.pg_opclass opc ON r.rngsubopc = opc.oid
    WHERE r.rngtypid = t.oid)
  ELSE -- enum
    E'ENUM(\n  '||pg_catalog.array_to_string(ARRAY(
      SELECT ''''||e.enumlabel||''''
      FROM pg_catalog.pg_enum e
      WHERE e.enumtypid = t.oid
      ORDER BY e.enumsortorder), E',\n  ')
  END)||E'\n);' as ddl,
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

--  AND rngtypid = SOMETHING WHAT

select array_to_string(array[1,2], E',\n  ')

select array(1,2,4)
