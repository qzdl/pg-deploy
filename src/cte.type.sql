CREATE OR REPLACE FUNCTION pgdeploy.cte_type(
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
        (array_to_string(array[ -- all identifying type props (typrelid, typarray)
          typname, typlen::text, typbyval::text, typtype::text,
          typcategory::text, typispreferred::text, typisdefined::text,
          typdelim::text, typelem::text, typinput::text, typoutput::text,
          typreceive::text, typsend ::text, typmodin::text, typmodout::text,
          typanalyze::text, typalign::text, typstorage::text, typnotnull::text,
          typbasetype::text, typtypmod::text, typndims::text,
          typcollation::text, typdefaultbin::text, typdefault::text,
          typacl::text], ',')
        -- ||array_to_string(array(
        --     SELECT e.enumlabel FROM pg_catalog.pg_enum e WHERE e.enumtypid = t.oid), ',')
        -- ||COALESCE((SELECT rngsubtype||opcname||rngsubdiff||rngcanonical||rngcollation
        --             FROM pg_catalog.pg_range r
        --               LEFT JOIN pg_catalog.pg_type st ON st.oid = r.rngsubtype
        --               LEFT JOIN pg_catalog.pg_opclass opc ON r.rngsubopc = opc.oid
        --             WHERE r.rngtypid = t.oid),''))
        )     AS id
    FROM pg_catalog.pg_type t
      LEFT JOIN pg_catalog.pg_namespace n ON n.oid = t.typnamespace
    WHERE (t.typrelid = 0 OR (SELECT c.relkind = 'c' FROM pg_catalog.pg_class c WHERE c.oid = t.typrelid))
      AND NOT EXISTS (SELECT 1 FROM pg_catalog.pg_type el WHERE el.oid = t.typelem AND el.typarray = t.oid)
      AND n.nspname <> 'pg_catalog'
      AND n.nspname <> 'information_schema'
      AND n.nspname IN (source_schema, target_schema);
END;
$BODY$
    LANGUAGE plpgsql STABLE;

--select * from pgdeploy.cte_type('testp'::name, 'testr'::name);
--select * from pgdeploy.object_difference('testp'::name, 'testr'::name, 'pgdeploy.cte_type');
