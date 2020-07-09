drop FUNCTION if exists deploy.reconcile_tables (
    source_schema name, source_rel name, source_oid oid,
    target_schema name, target_rel name, target_oid oid);

CREATE OR REPLACE FUNCTION deploy.reconcile_tables(
    source_schema name, source_rel name, source_oid oid,
    target_schema name, target_rel name, target_oid oid)
RETURNS SETOF text AS
$BODY$
DECLARE
    col_ddl text;
    _tables record;
    _columns record;
BEGIN
    -- safety checks; restrict to operational tables
    FOR _tables IN
        SELECT c.relname, c.oid, n.nspname FROM pg_catalog.pg_class c
            LEFT JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
        WHERE relkind = 'r'
            AND (n.nspname = target_schema OR n.nspname = source_schema)
            --AND relname~ ('^('||source_rel||')$')
        ORDER BY c.relname
    LOOP -- _tables
        RAISE NOTICE 'LOOP TABLES: %', _tables;
        
        -- get column info (name, type, NULL, constraints, defaults)
        FOR _columns IN
        -- compute diff for source->target
        -- FIXME: potential optimisation (information_schema -> raw catalog)
        -- FIXME: antijoin diff  can be tidied up by passing oids in
            with signs as (
                select 'DROP' as sign,
                       r_source.column_name as col
                from information_schema.columns as r_source
                where table_name = source_rel  -- to yield d0
                  and table_schema = source_schema
                  and not exists (
                    select column_name
                    from information_schema.columns as r_target
                    where r_target.table_name = target_rel
                      and r_target.table_schema = target_schema
                      and r_source.column_name = r_target.column_name) -- AJ predicate
                union -- inverse for `ADD'
                select 'ADD' as sign,
                       a_target.column_name as col
                from information_schema.columns as a_target
                where table_name = target_rel       -- to yield d1
                  and table_schema = target_schema
                  and not exists (
                    select column_name
                    from information_schema.columns as a_source
                    where a_source.table_name = source_rel
                      and a_source.table_schema = source_schema
                      and a_source.column_name = a_target.column_name) -- AJ predicate
            )
            SELECT
                signs.sign,
                signs.col,
                b.nspname as schema_name,
                b.relname as table_name,
                a.attname as column_name,
                pg_catalog.format_type(a.atttypid, a.atttypmod) as column_type,
                -- defaults; FIXME: maybe throw into CTE to reduce duplication of query logic?
                CASE WHEN
                    (SELECT substring(pg_catalog.pg_get_expr(d.adbin, d.adrelid) for 128)
                     FROM   pg_catalog.pg_attrdef d
                     WHERE  d.adrelid = a.attrelid AND d.adnum = a.attnum AND a.atthasdef)
                IS NOT NULL THEN
                    'DEFAULT '|| (SELECT substring(pg_catalog.pg_get_expr(d.adbin, d.adrelid) for 128)
                                  FROM pg_catalog.pg_attrdef d
                                  WHERE d.adrelid = a.attrelid AND d.adnum = a.attnum AND a.atthasdef)
                ELSE
                    ''
                END as column_default_value,
                CASE WHEN a.attnotnull = true THEN
                    'NOT NULL'
                ELSE
                    'NULL'
                END as column_not_null,
                a.attnum as attnum,
                e.max_attnum as max_attnum
            FROM
                pg_catalog.pg_attribute a
                LEFT JOIN signs ON a.attname = signs.col
                INNER JOIN
                 (SELECT c.oid,
                    n.nspname,
                    c.relname
                  FROM pg_catalog.pg_class c
                       LEFT JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
                  WHERE c.oid = _tables.oid
                      -- FIXME: visible necessary? these preds should really be applied in the `_tables` query
                      -- AND pg_catalog.pg_table_is_visible(c.oid)
                  ORDER BY 2, 3) b
                ON a.attrelid = b.oid
                INNER JOIN
                 (SELECT
                      a.attrelid,
                      max(a.attnum) as max_attnum
                  FROM pg_catalog.pg_attribute a
                  WHERE a.attnum > 0
                    AND NOT a.attisdropped
                  GROUP BY a.attrelid) e
                ON a.attrelid=e.attrelid
            WHERE a.attnum > 0
              AND NOT a.attisdropped
            AND signs.sign IS NOT NULL
            ORDER BY a.attnum
        LOOP -- _columns
            RAISE NOTICE 'LOOP COLUMN: %', _columns.sign;

            IF _columns.sign = 'DROP' THEN
                col_ddl := 'ALTER TABLE '||source_schema||'.'||source_rel||' DROP COLUMN '||_columns.col;
            ELSE
                SELECT INTO col_ddl
                'ALTER TABLE '||source_schema||'.'||source_rel||' '
                ||'ADD COLUMN '||_columns.col||' '||_columns.column_type||' '
                ||_columns.column_default_value||' '||_columns.column_not_null;
            END IF;
            col_ddl := col_ddl||';';
            RETURN NEXT col_ddl;
        END LOOP; -- _columns
    END LOOP; -- _tables
END
$BODY$
    LANGUAGE plpgsql STABLE;