
-- ENUM:

-- positional semantics? does the index of a given enumlabel matter?
-- recursive enums?
-- alter statement based on the difference in the set of enumlabel for TYPE
--   add, respecting positions with BEFORE / AFTER
--   comment line for element removal, "unsupported", but give the create definition

-- CREATE OR WARN
-- TODO: check if the contents of [RANGE | ENUM] are equal, dispatch accordingly
DROP FUNCTION IF EXISTS pgdeploy.reconcile_type(
    source_schema name, target_schema name);

CREATE OR REPLACE FUNCTION pgdeploy.reconcile_type(
    source_schema name, target_schema name)
RETURNS SETOF TEXT AS
$BODY$
BEGIN
    RETURN QUERY
    WITH info AS (
      SELECT
        t.typname, t.typlen, t.typrelid,
        s_schema, s_objname, s_oid, t_schema, t_objname, t_oid
      FROM pgdeploy.object_difference(source_schema, target_schema, 'pgdeploy.cte_type')
      INNER JOIN pg_type t ON t.oid = s_oid OR t.oid = t_oid
    ), range AS (
      SELECT i.oid, array_to_string(ARRAY[
        'subtype = '||(SELECT typname FROM pg_type t2 WHERE t2.oid = r.rngsubtype),
         CASE WHEN opcdefault <> 't' THEN 'subtype_opclass = '||source_schema||'.'||opcname ELSE NULL END,
         CASE WHEN rngsubdiff::text <> '-' THEN 'subtype_diff = ' || rngsubdiff ELSE NULL END,
         CASE WHEN rngcanonical::text <> '-' THEN 'canonical = ' || rngcanonical ELSE NULL END,
         CASE WHEN rngcollation <> 0 THEN 'collation = ' || rngcollation ELSE NULL END], E',\n  ') AS range_body
      FROM pg_catalog.pg_range r
      INNER JOIN info i on i.oid = r.rngtypid
      LEFT JOIN pg_catalog.pg_type st ON st.oid = r.rngsubtype
      LEFT JOIN pg_catalog.pg_opclass opc ON r.rngsubopc = opc.oid
    ), enumitems AS (
      SELECT distinct i.typname, i.oid, e.enumtypid, ''''||e.enumlabel||'''' AS label, e.enumsortorder as sort
      FROM pg_catalog.pg_enum e
      INNER JOIN info i ON e.
      ORDER BY e.enumsortorder
    ), enumdiff as (
      SELECT DISTINCT ei.oid, ei.label, ei.sort, ei.typname
      FROM enumitems AS ei WHERE ei.nspname = source_schema
        AND NOT EXISTS(
        SELECT 1 FROM enumitems AS et
        WHERE et.nspname = target_schema
          AND et.typname = ei.typname
          AND et.label = ei.label
          AND et.sort = ei.sort
      )
      UNION
      SELECT DISTINCT ei.oid, ei.label, ei.sort, ei.typname
      FROM enumitems AS ei WHERE ei.nspname = target_schema
        AND NOT EXISTS(
        SELECT 1 FROM enumitems AS et
        WHERE et.nspname = source_schema
          AND et.typname = ei.typname
          AND et.label = ei.label
          AND et.sort = ei.sort
     )
    )
    SELECT DISTINCT CASE
      WHEN t_schema IS NULL THEN       -- @STATE: DROP
        'DROP TYPE IF EXISTS '||s_schema||'.'||s_objname||';'
      WHEN s_schema IS NULL THEN (CASE -- @STATE: CREATE OR WARN
        WHEN i.typrelid != 0 THEN -- @CATEGORY: COMPOSITE
          'CREATE TYPE '||source_schema||'.'||i.typname||' AS '||CAST('tuple' AS pg_catalog.text)
        WHEN i.typlen < 0 THEN    -- @CATEGORY: RANGE
          'CREATE TYPE '||source_schema||'.'||i.typname||E' AS (\n  '||r.range_body
        ELSE                -- @CATEGORY: ENUM
            'CREATE TYPE '||source_schema||'.'||i.typname||E' AS ENUM(\n  '
            ||array_to_string(array(select e.label
                                    from enumitems e
                                    where e.oid = i.oid
                                    order by e.sort), E'\n  ')
        END)||E'\n);'             -- @CATEGORY: END
      ELSE CASE                        -- @STATE: EQUAL (for `id` as defined in `cte_type`)
        WHEN i.typrelid != 0 AND 1=0 THEN -- @CATEGORY: COMPOSITE
          '-- @TYPE: difference in comp '||i.typname
        WHEN i.typlen < 0  and 1=0 THEN    -- @CATEGORY: RANGE
          '-- @TYPE: difference in range '||i.typname
        WHEN EXISTS(SELECT 1 FROM enumdiff AS ed WHERE ed.oid = i.oid) THEN -- @CATEGORY: ENUM
          E'-- @TYPE: ***WARNING***\n-- The ENUM '||i.typname||' has difference in members, please check the suitability of DROP/CREATE:'
          ||E'\nDROP TYPE '||source_schema||'.'||i.typname||E';\n'
          ||'CREATE TYPE '||source_schema||'.'||i.typname||E' AS ENUM(\n  '
          ||array_to_string(array(select e.enumlabel
                                  from pg_enum e
                                  where e.enumtypid = i.t_oid
                                  order by e.enumsortorder), E'\n  ')
          ||E'\n);'

        ELSE '-- @TYPE: LEFT and RIGHT of '''||s_schema||'.'||s_objname||''' are equal.'
        END
      END AS ddl                       -- @STATE: END
    FROM info i
    LEFT JOIN range r ON r.oid = i.oid
    ORDER BY ddl DESC; -- comments and drops first
END;
$BODY$
    LANGUAGE plpgsql STABLE;


--select * from pgdeploy.reconcile_type('testp', 'testr');




-- WITH info AS (
--       SELECT
--         t.oid, t.typname, t.typlen, t.typrelid,
--         s_schema, s_objname, t_schema, t_objname
--       FROM pgdeploy.object_difference('testp'::name, 'testr'::name, 'pgdeploy.cte_type')
--       INNER JOIN pg_type t ON t.oid = s_oid OR t.oid = t_oid
--     ), range AS (
--       SELECT i.oid, array_to_string(ARRAY[
--         'subtype = '||(SELECT typname FROM pg_type t2 WHERE t2.oid = r.rngsubtype),
--          CASE WHEN opcdefault <> 't' THEN 'subtype_opclass = '||'testp'||'.'||opcname ELSE NULL END,
--          CASE WHEN rngsubdiff::text <> '-' THEN 'subtype_diff = ' || rngsubdiff ELSE NULL END,
--          CASE WHEN rngcanonical::text <> '-' THEN 'canonical = ' || rngcanonical ELSE NULL END,
--          CASE WHEN rngcollation <> 0 THEN 'collation = ' || rngcollation ELSE NULL END], E',\n  ') AS range_body
--       FROM pg_catalog.pg_range r
--       INNER JOIN info i on i.oid = r.rngtypid
--       LEFT JOIN pg_catalog.pg_type st ON st.oid = r.rngsubtype
--       LEFT JOIN pg_catalog.pg_opclass opc ON r.rngsubopc = opc.oid
--     ), enumitems AS ( -- enumlabel items?
--       SELECT i.oid, ''''||e.enumlabel||'''' AS label, e.enumsortorder as sort
--       FROM pg_catalog.pg_enum e
--       INNER JOIN info i ON e.enumtypid = i.oid
--       ORDER BY e.enumsortorder
--     )
--     -- enum diff
--       SELECT typname||(CASE WHEN COALESCE(s_schema, t_schema) = 'testp' THEN 0 ELSE 1 END) as typname,
--       label, sort
--       FROM info i
--       INNER JOIN enumitems ei on ei.oid = i.oid
--       WHERE typname = 'enumdroplast' and array['some', 1::text] = array['some', 1::text]
--       ORDER BY sort, typname;




-- WITH info AS (
--       SELECT
--         t.oid, t.typname, t.typlen, t.typrelid,
--         s_schema, s_objname, t_schema, t_objname,
--         COALESCE(s_schema, t_schema) AS schemata
--       FROM pgdeploy.object_difference('testp'::name, 'testr'::name, 'pgdeploy.cte_type')
--       INNER JOIN pg_type t ON t.oid = s_oid OR t.oid = t_oid
--     ), range AS (
--       SELECT i.oid, array_to_string(ARRAY[
--         'subtype = '||(SELECT typname FROM pg_type t2 WHERE t2.oid = r.rngsubtype),
--          CASE WHEN opcdefault <> 't' THEN 'subtype_opclass = '||'testp'||'.'||opcname ELSE NULL END,
--          CASE WHEN rngsubdiff::text <> '-' THEN 'subtype_diff = ' || rngsubdiff ELSE NULL END,
--          CASE WHEN rngcanonical::text <> '-' THEN 'canonical = ' || rngcanonical ELSE NULL END,
--          CASE WHEN rngcollation <> 0 THEN 'collation = ' || rngcollation ELSE NULL END], E',\n  ') AS range_body
--       FROM pg_catalog.pg_range r
--       INNER JOIN info i on i.oid = r.rngtypid
--       LEFT JOIN pg_catalog.pg_type st ON st.oid = r.rngsubtype
--       LEFT JOIN pg_catalog.pg_opclass opc ON r.rngsubopc = opc.oid
--     ), enumitems AS ( -- enumlabel items?
--       SELECT i.oid, ''''||e.enumlabel||'''' AS label, e.enumsortorder as sort
--       FROM pg_catalog.pg_enum e
--       INNER JOIN info i ON e.enumtypid = i.oid
--       ORDER BY e.enumsortorder
--     )
--     -- enum diff
--     SELECT distinct
--     s_sort, s_name, s_label, t_label
--     FROM (
--       WITH ss AS (
--         SELECT typname||(case when i.schemata = 'testp' THEN 0 ELSE 1 END) as typnameN, typname,
--                array[typname, sort::text] as id, sort, label
--         FROM info i
--         INNER JOIN enumitems ei on ei.oid = i.oid
--         WHERE i.schemata = 'testp'
--       ), tt AS (
--         SELECT typname||(case when i.schemata = 'testp' THEN 0 ELSE 1 END) as typnameN, typname,
--                array[typname, sort::text] as id, sort, label
--         FROM info i
--         INNER JOIN enumitems ei on ei.oid = i.oid
--         WHERE i.schemata = 'testr'
--       )
--       SELECT
--         ss.id      as s_id,
--         ss.sort    as s_sort,
--         ss.typname as s_name,
--         ss.label   as s_label,
--         tt.id      as t_id,
--         tt.sort    as t_sort,
--         tt.typname as t_name,
--         ss.label   as t_label
--       FROM ss LEFT JOIN tt on tt.id = ss.id
--       UNION
--       SELECT
--         ss.id      as s_id,
--         ss.sort    as s_sort,
--         ss.typname as s_name,
--         ss.label   as s_label,
--         tt.id      as t_id,
--         tt.sort    as t_sort,
--         tt.typname as t_name,
--         tt.label   as t_label
--       FROM tt LEFT JOIN ss ON tt.id = ss.id
--     ) as b
--     WHERE s_label <> t_label
--     order by s_name, s_sort


-- WITH info AS (
--       SELECT
--         t.oid, n.nspname, t.typname, t.typlen, t.typrelid,
--         s_schema, s_objname, t_schema, t_objname
--       FROM pgdeploy.object_difference('testp'::name, 'testr'::name, 'pgdeploy.cte_type')
--       INNER JOIN pg_type t ON t.oid = s_oid OR t.oid = t_oid
--       INNER JOIN pg_namespace n ON n.oid = t.typnamespace
--     ), range AS (
--       SELECT i.oid, array_to_string(ARRAY[
--         'subtype = '||(SELECT typname FROM pg_type t2 WHERE t2.oid = r.rngsubtype),
--          CASE WHEN opcdefault <> 't' THEN 'subtype_opclass = '||'testp'::name||'.'||opcname ELSE NULL END,
--          CASE WHEN rngsubdiff::text <> '-' THEN 'subtype_diff = ' || rngsubdiff ELSE NULL END,
--          CASE WHEN rngcanonical::text <> '-' THEN 'canonical = ' || rngcanonical ELSE NULL END,
--          CASE WHEN rngcollation <> 0 THEN 'collation = ' || rngcollation ELSE NULL END], E',\n  ') AS range_body
--       FROM pg_catalog.pg_range r
--       INNER JOIN info i on i.oid = r.rngtypid
--       LEFT JOIN pg_catalog.pg_type st ON st.oid = r.rngsubtype
--       LEFT JOIN pg_catalog.pg_opclass opc ON r.rngsubopc = opc.oid
--     ), enumitems AS (
--       SELECT i.typname, i.oid, ''''||e.enumlabel||'''' AS label, e.enumsortorder as sort, i.nspname
--       FROM pg_catalog.pg_enum e
--       INNER JOIN info i ON e.enumtypid = i.oid
--       ORDER BY e.enumsortorder
--     ), enumdiff as (
--       SELECT DISTINCT ei.oid, ei.label, ei.sort, ei.typname
--       FROM enumitems AS ei WHERE ei.nspname = 'testp'::name
--         AND NOT EXISTS(
--         SELECT 1 FROM enumitems AS et
--         WHERE et.nspname = 'testr'::name
--           AND et.typname = ei.typname
--           AND et.label = ei.label
--           AND et.sort = ei.sort
--       )
--       UNION
--       SELECT DISTINCT ei.oid, ei.label, ei.sort, ei.typname
--       FROM enumitems AS ei WHERE ei.nspname = 'testr'::name
--         AND NOT EXISTS(
--         SELECT 1 FROM enumitems AS et
--         WHERE et.nspname = 'testp'::name
--           AND et.typname = ei.typname
--           AND et.label = ei.label
--           AND et.sort = ei.sort
--      )
--     )
--     SELECT distinct i.oid, ed.*
--     FROM info i
--     LEFT JOIN range r ON r.oid = i.oid
--     INNER JOIN enumdiff ed on ed.oid = i.oid
--     order by i.oid
