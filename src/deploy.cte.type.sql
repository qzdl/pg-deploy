DROP FUNCTION IF EXISTS deploy.cte_type(
    source_schema name, target_schema name);

CREATE OR REPLACE FUNCTION deploy.cte_type(
    source_schema name, target_schema name)
RETURNS TABLE(
    nspname name, objname name, oid oid, id text) AS
$BODY$
BEGIN
    RETURN QUERY
    SELECT DISTINCT
        n.nspname AS nspname,
        t.typname AS objname,
        t.oid     AS oid,
        (array_to_string(array[ -- all identifying type props
          typname, typlen::text, typbyval::text, typtype::text, typcategory::text, typispreferred::text,
          typisdefined::text, typdelim::text, typrelid::text, typelem::text, typarray::text, typinput::text,
          typoutput::text, typreceive::text, typsend ::text, typmodin::text, typmodout::text, typanalyze::text,
          typalign::text, typstorage::text, typnotnull::text, typbasetype::text, typtypmod::text, typndims::text,
          typcollation::text, typdefaultbin::text, typdefault::text, typacl::text], ',')
        ||array_to_string(array(
            SELECT e.enumlabel FROM pg_catalog.pg_enum e WHERE e.enumtypid = t.oid), ',')
        ||COALESCE((SELECT rngsubtype||opcname||rngsubdiff||rngcanonical||rngcollation
                    FROM pg_catalog.pg_range r
                      LEFT JOIN pg_catalog.pg_type st ON st.oid = r.rngsubtype
                      LEFT JOIN pg_catalog.pg_opclass opc ON r.rngsubopc = opc.oid
                    WHERE r.rngtypid = t.oid),'')) AS id
    FROM pg_catalog.pg_type t
      LEFT JOIN pg_catalog.pg_namespace n ON n.oid = t.typnamespace
    WHERE (t.typrelid = 0 OR (SELECT c.relkind = 'c' FROM pg_catalog.pg_class c WHERE c.oid = t.typrelid))
      AND NOT EXISTS (SELECT 1 FROM pg_catalog.pg_type el WHERE el.oid = t.typelem AND el.typarray = t.oid)
      AND n.nspname <> 'pg_catalog'
      AND n.nspname <> 'information_schema'
      --AND pg_catalog.pg_type_is_visible(t.oid)
      AND n.nspname IN (source_schema, target_schema);
END;
$BODY$
    LANGUAGE plpgsql STABLE;

select * from deploy.cte_type('testp'::name, 'testr'::name);


SELECT DISTINCT
        n.nspname AS nspname,
        t.typname AS objname,
        t.oid     AS oid,
        array_to_string(array[ -- all identifying type props
          typname, typlen::text, typbyval::text, typtype::text, typcategory::text, typispreferred::text,
          typisdefined::text, typdelim::text, typrelid::text, typelem::text, typarray::text, typinput::text,
          typoutput::text, typreceive::text, typsend ::text, typmodin::text, typmodout::text, typanalyze::text,
          typalign::text, typstorage::text, typnotnull::text, typbasetype::text, typtypmod::text, typndims::text,
          typcollation::text, typdefaultbin::text, typdefault::text, typacl::text], ',')||
        array_to_string(array(SELECT e.enumlabel FROM pg_catalog.pg_enum e WHERE e.enumtypid = t.oid), ',')||
        COALESCE((SELECT rngsubtype||opcname||rngsubdiff||rngcanonical||rngcollation
                    FROM pg_catalog.pg_range r
                      LEFT JOIN pg_catalog.pg_type st ON st.oid = r.rngsubtype
                      LEFT JOIN pg_catalog.pg_opclass opc ON r.rngsubopc = opc.oid
                    WHERE r.rngtypid = t.oid),'') AS rpos
    FROM pg_catalog.pg_type t
      LEFT JOIN pg_catalog.pg_namespace n ON n.oid = t.typnamespace
    WHERE (t.typrelid = 0 OR (SELECT c.relkind = 'c' FROM pg_catalog.pg_class c WHERE c.oid = t.typrelid))
      AND NOT EXISTS (SELECT 1 FROM pg_catalog.pg_type el WHERE el.oid = t.typelem AND el.typarray = t.oid)
      AND n.nspname <> 'pg_catalog'
      AND n.nspname <> 'information_schema'
      --AND pg_catalog.pg_type_is_visible(t.oid)
      AND n.nspname IN ('testp'::name, 'testr'::name);





select typname,array_to_string(array(
            SELECT e.enumlabel FROM pg_catalog.pg_enum e WHERE e.enumtypid = t.oid), ',')
    FROM pg_catalog.pg_type t
      LEFT JOIN pg_catalog.pg_namespace n ON n.oid = t.typnamespace
    WHERE (t.typrelid = 0 OR (SELECT c.relkind = 'c' FROM pg_catalog.pg_class c WHERE c.oid = t.typrelid))
      AND NOT EXISTS (SELECT 1 FROM pg_catalog.pg_type el WHERE el.oid = t.typelem AND el.typarray = t.oid)
      AND n.nspname <> 'pg_catalog'
      AND n.nspname <> 'information_schema'
      --AND pg_catalog.pg_type_is_visible(t.oid)
      AND n.nspname IN ('testp'::name, 'testr'::name);

-- extended type info query
-- SELECT
--   'CREATE TYPE '||n.nspname||'.'||t.typname||' AS '||(CASE
--   WHEN t.typrelid != 0 THEN -- comp
--     CAST('tuple' AS pg_catalog.text)
--   WHEN t.typlen < 0 THEN -- range
--     E'(\n  '||(
--     SELECT array_to_string(ARRAY[
--       'subtype = '||(SELECT typname FROM pg_type t2 WHERE t2.oid = r.rngsubtype),
--       CASE WHEN opcdefault <> 't' THEN 'subtype_opclass = '||n.nspname||'.'||opcname ELSE NULL END,
--       CASE WHEN rngsubdiff::text <> '-' THEN 'subtype_diff = ' || rngsubdiff ELSE NULL END,
--       CASE WHEN rngcanonical::text <> '-' THEN 'canonical = ' || rngcanonical ELSE NULL END,
--       CASE WHEN rngcollation <> 0 THEN 'collation = ' || rngcollation ELSE NULL END], E',\n  ') AS range_body
--     FROM pg_catalog.pg_range r
--     LEFT JOIN pg_catalog.pg_type st ON st.oid = r.rngsubtype
--     LEFT JOIN pg_catalog.pg_opclass opc ON r.rngsubopc = opc.oid
--     WHERE r.rngtypid = t.oid)
--   ELSE -- enum
--   -- positional semantics? does the index of a given enumlabel matter?
--   -- recursive enums?
--   -- alter statement based on the difference in the set of enumlabel for TYPE
--   --   add, respecting positions with BEFORE / AFTER
--   --   comment line for element removal, "unsupported", but give the create definition
--     E'ENUM(\n  '||pg_catalog.array_to_string(ARRAY(
--       SELECT ''''||e.enumlabel||''''
--       FROM pg_catalog.pg_enum e
--       WHERE e.enumtypid = t.oid
--       ORDER BY e.enumsortorder), E',\n  ')
--   END)||E'\n);' as ddl,
--   pg_catalog.format_type(t.oid, NULL) AS "Name",
--   t.typname AS "Internal name"
-- FROM pg_catalog.pg_type t
--   LEFT JOIN pg_catalog.pg_namespace n ON n.oid = t.typnamespace
-- WHERE (t.typrelid = 0 OR (SELECT c.relkind = 'c' FROM pg_catalog.pg_class c WHERE c.oid = t.typrelid))
--   AND NOT EXISTS (SELECT 1 FROM pg_catalog.pg_type el WHERE el.oid = t.typelem AND el.typarray = t.oid)
--   AND n.nspname <> 'pg_catalog'
--   AND n.nspname <> 'information_schema'
--   AND pg_catalog.pg_type_is_visible(t.oid)
-- ORDER BY 1, 2;
