-- https://wiki.postgresql.org/wiki/Pg_depend_display
CREATE SCHEMA IF NOT EXISTS report;
DROP VIEW IF EXISTS report.dependency;
CREATE OR REPLACE VIEW report.dependency AS
WITH RECURSIVE preference AS (
  SELECT 10 AS max_depth  -- The deeper the recursion goes, the slower it performs.
    , 16384 AS min_oid -- user objects only
    , '^(londiste|pgq|pg_toast)'::text AS schema_exclusion
    , '^pg_(conversion|language|ts_(dict|template))'::text AS class_exclusion
    , '{"SCHEMA":"00", "TABLE":"01", "CONSTRAINT":"02", "DEFAULT":"03",
        "INDEX":"05", "SEQUENCE":"06", "TRIGGER":"07", "FUNCTION":"08",
        "VIEW":"10", "MVIEW":"11", "FOREIGN":"12"}'::json AS type_ranks
)
, dependency_pair AS (
    WITH relation_object AS (
        SELECT oid
        , oid::regclass::text AS object_name
        , CASE relkind
              WHEN 'r' THEN 'TABLE'::text
              WHEN 'i' THEN 'INDEX'::text
              WHEN 'S' THEN 'SEQUENCE'::text
              WHEN 'v' THEN 'VIEW'::text
              WHEN 'm' THEN 'MVIEW'::text
              WHEN 'c' THEN 'TYPE'::text      -- COMPOSITE type
              WHEN 't' THEN 'TOAST'::text
              WHEN 'f' THEN 'FOREIGN'::text
          END AS object_type
        FROM pg_class
    )
    SELECT
        objid,
        CASE classid
            WHEN 'pg_amop'::regclass THEN 'ACCESS METHOD OPERATOR'
            WHEN 'pg_amproc'::regclass THEN 'ACCESS METHOD PROCEDURE'
            WHEN 'pg_attrdef'::regclass THEN 'DEFAULT'
            WHEN 'pg_cast'::regclass THEN 'CAST'
            WHEN 'pg_class'::regclass THEN rel.object_type
            WHEN 'pg_constraint'::regclass THEN 'CONSTRAINT'
            WHEN 'pg_extension'::regclass THEN 'EXTENSION'
            WHEN 'pg_namespace'::regclass THEN 'SCHEMA'
            WHEN 'pg_opclass'::regclass THEN 'OPERATOR CLASS'
            WHEN 'pg_operator'::regclass THEN 'OPERATOR'
            WHEN 'pg_opfamily'::regclass THEN 'OPERATOR FAMILY'
            WHEN 'pg_proc'::regclass THEN 'FUNCTION'
            WHEN 'pg_rewrite'::regclass THEN (SELECT concat(object_type,' RULE') FROM pg_rewrite e JOIN relation_object r ON r.oid = ev_class WHERE e.oid = objid)
            WHEN 'pg_trigger'::regclass THEN 'TRIGGER'
            WHEN 'pg_type'::regclass THEN 'TYPE'
            ELSE classid::regclass::text
        END AS object_type,
        CASE classid
            WHEN 'pg_attrdef'::regclass THEN (SELECT attname FROM pg_attrdef d JOIN pg_attribute c ON (c.attrelid,c.attnum)=(d.adrelid,d.adnum) WHERE d.oid = objid)
            WHEN 'pg_cast'::regclass THEN (SELECT concat(castsource::regtype::text, ' AS ', casttarget::regtype::text,' WITH ', castfunc::regprocedure::text) FROM pg_cast WHERE oid = objid)
            WHEN 'pg_class'::regclass THEN rel.object_name
            WHEN 'pg_constraint'::regclass THEN (SELECT conname FROM pg_constraint WHERE oid = objid)
            WHEN 'pg_extension'::regclass THEN (SELECT extname FROM pg_extension WHERE oid = objid)
            WHEN 'pg_namespace'::regclass THEN (SELECT nspname FROM pg_namespace WHERE oid = objid)
            WHEN 'pg_opclass'::regclass THEN (SELECT opcname FROM pg_opclass WHERE oid = objid)
            WHEN 'pg_operator'::regclass THEN (SELECT oprname FROM pg_operator WHERE oid = objid)
            WHEN 'pg_opfamily'::regclass THEN (SELECT opfname FROM pg_opfamily WHERE oid = objid)
            WHEN 'pg_proc'::regclass THEN objid::regprocedure::text
            WHEN 'pg_rewrite'::regclass THEN (SELECT ev_class::regclass::text FROM pg_rewrite WHERE oid = objid)
            WHEN 'pg_trigger'::regclass THEN (SELECT tgname FROM pg_trigger WHERE oid = objid)
            WHEN 'pg_type'::regclass THEN objid::regtype::text
            ELSE objid::text
        END AS object_name,
        array_agg(objsubid ORDER BY objsubid) AS objsubids,
        refobjid,
        CASE refclassid
            WHEN 'pg_namespace'::regclass THEN 'SCHEMA'
            WHEN 'pg_class'::regclass THEN rrel.object_type
            WHEN 'pg_opfamily'::regclass THEN 'OPERATOR FAMILY'
            WHEN 'pg_proc'::regclass THEN 'FUNCTION'
            WHEN 'pg_type'::regclass THEN 'TYPE'
            ELSE refclassid::text
        END AS refobj_type,
        CASE refclassid
            WHEN 'pg_namespace'::regclass THEN (SELECT nspname FROM pg_namespace WHERE oid = refobjid)
            WHEN 'pg_class'::regclass THEN rrel.object_name
            WHEN 'pg_opfamily'::regclass THEN (SELECT opfname FROM pg_opfamily WHERE oid = refobjid)
            WHEN 'pg_proc'::regclass THEN refobjid::regprocedure::text
            WHEN 'pg_type'::regclass THEN refobjid::regtype::text
            ELSE refobjid::text
        END AS refobj_name,
        array_agg(refobjsubid ORDER BY refobjsubid) AS refobjsubids,
        CASE deptype
            WHEN 'n' THEN 'normal'
            WHEN 'a' THEN 'automatic'
            WHEN 'i' THEN 'internal'
            WHEN 'e' THEN 'extension'
            WHEN 'p' THEN 'pinned'
        END AS dependency_type
    FROM pg_depend dep
    LEFT JOIN relation_object rel ON rel.oid = dep.objid
    LEFT JOIN relation_object rrel ON rrel.oid = dep.refobjid
    , preference
    WHERE deptype = ANY('{n,a}')
    AND objid >= preference.min_oid
    AND (refobjid >= preference.min_oid OR refobjid = 2200) -- need public schema as root node
    AND classid::regclass::text !~ preference.class_exclusion
    AND refclassid::regclass::text !~ preference.class_exclusion
    AND coalesce(substring(objid::regclass::text, E'^(\\w+)\\.'),'') !~ preference.schema_exclusion
    AND coalesce(substring(refobjid::regclass::text, E'^(\\w+)\\.'),'') !~ preference.schema_exclusion
    GROUP BY classid, objid, refclassid, refobjid, deptype, rel.object_name, rel.object_type, rrel.object_name, rrel.object_type
)
, dependency_hierarchy AS (
    SELECT DISTINCT
        0 AS level,
        refobjid AS objid,
        refobj_type AS object_type,
        refobj_name AS object_name,
        --refobjsubids AS objsubids,
        NULL::text AS dependency_type,
        ARRAY[refobjid] AS dependency_chain,
        ARRAY[concat(preference.type_ranks->>refobj_type,refobj_type,' ',refobj_name)] AS dependency_name_chain
    FROM dependency_pair root
    , preference
    WHERE NOT EXISTS
       (SELECT 'x' FROM dependency_pair branch WHERE branch.objid = root.refobjid)
    AND refobj_name !~ preference.schema_exclusion
    UNION ALL
    SELECT
        level + 1 AS level,
        child.objid,
        child.object_type,
        child.object_name,
        --child.objsubids,
        child.dependency_type,
        parent.dependency_chain || child.objid,
        parent.dependency_name_chain || concat(preference.type_ranks->>child.object_type,child.object_type,' ',child.object_name)
    FROM dependency_pair child
    JOIN dependency_hierarchy parent ON (parent.objid = child.refobjid)
    , preference
    WHERE level < preference.max_depth
    AND child.object_name !~ preference.schema_exclusion
    AND child.refobj_name !~ preference.schema_exclusion
    AND NOT (child.objid = ANY(parent.dependency_chain)) -- prevent circular referencing
)
SELECT * FROM dependency_hierarchy
ORDER BY dependency_chain ;
