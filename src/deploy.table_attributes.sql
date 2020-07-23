DROP FUNCTION if exists deploy.reconcile_table_attributes (
    source_schema name, source_rel name, source_oid oid,
    target_schema name, target_rel name, target_oid oid);

CREATE OR REPLACE FUNCTION deploy.reconcile_table_attributes(
    source_schema name, source_rel name, source_oid oid,
    target_schema name, target_rel name, target_oid oid)
RETURNS SETOF text AS
$BODY$
DECLARE
    col_ddl text;
    _columns record;
BEGIN
    RETURN QUERY
    WITH info AS (
        SELECT
            od.*,
            pg_catalog.format_type(a.atttypid, a.atttypmod) as column_type,
            CASE WHEN (
                SELECT substring(pg_catalog.pg_get_expr(d.adbin, d.adrelid) for 128)
                FROM   pg_catalog.pg_attrdef d
                WHERE  d.adrelid = a.attrelid AND d.adnum = a.attnum AND a.atthasdef
            ) IS NOT NULL THEN
                'DEFAULT '|| (
                  SELECT substring(pg_catalog.pg_get_expr(d.adbin, d.adrelid) for 128)
                  FROM   pg_catalog.pg_attrdef d
                  WHERE  d.adrelid = a.attrelid AND d.adnum = a.attnum AND a.atthasdef
            ) ELSE NULL
            END AS column_default_value,
            CASE WHEN a.attnotnull = true THEN 'NOT NULL' ELSE 'NULL' END AS column_not_null
        FROM deploy.object_difference(
             source_schema, target_schema,
             'deploy.cte_attribute', source_oid, target_oid) AS od
        LEFT JOIN pg_catalog.pg_attribute a
            ON ((a.attrelid = od.t_oid and a.attname = od.t_objname)
             OR (a.attrelid = od.s_oid AND a.attname = od.s_objname))
        WHERE a.attnum > 0
          AND NOT a.attisdropped
    ) -- eo info
    SELECT DISTINCT CASE
      WHEN t_schema IS NULL THEN
        'ALTER TABLE '||source_schema||'.'||source_rel||
        ' DROP COLUMN '||s_objname||';'

      WHEN s_schema IS NULL THEN
        'ALTER TABLE '||source_schema||'.'||source_rel||
        ' ADD COLUMN '||array_to_string(ARRAY[t_objname, column_type,
        column_default_value, column_not_null],' ')||';'

      ELSE '-- COLUMN: no change for '||s_objname END AS ddl
    FROM info;
END;
$BODY$
    LANGUAGE plpgsql STABLE;

select * FROM deploy.object_difference(
  'testp'::name, 'testr'::name, 'deploy.cte_attribute',
   (SELECT c.oid FROM pg_class c INNER JOIN pg_namespace n
      ON n.oid = c.relnamespace and c.relname = 'a' and n.nspname = 'testp'),
   (SELECT c.oid FROM pg_class c INNER JOIN pg_namespace n
      ON n.oid = c.relnamespace and c.relname = 'a' and n.nspname = 'testr'))
      order by s_objname, t_objname;

select * from deploy.reconcile_table_attributes(
    'testp'::name, 'a'::name, (SELECT c.oid FROM pg_class c INNER JOIN pg_namespace n ON n.oid = c.relnamespace and c.relname = 'a' and n.nspname = 'testp'),
    'testr'::name, 'a'::name, (SELECT c.oid FROM pg_class c INNER JOIN pg_namespace n ON n.oid = c.relnamespace and c.relname = 'a' and n.nspname = 'testr'));
