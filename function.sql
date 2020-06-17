drop FUNCTION if exists public.reconsile_desired(
    source_schema text,
    target_schema text,
    object_name text
);

CREATE FUNCTION public.reconsile_desired(
    source_schema text,
    target_schema text,
    object_name text
)
RETURNS SETOF text AS
$BODY$
DECLARE
    col_ddl text;
    _tables record;
    _columns record;
    _constraints record;
BEGIN
    -- restrict to operational tables
    FOR _tables IN
        SELECT c.relname, c.oid, n.nspname FROM pg_catalog.pg_class c
            LEFT JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
        WHERE relkind = 'r'
            AND (n.nspname = target_schema OR n.nspname = source_schema)
            AND relname~ ('^('||object_name||')$')
        ORDER BY c.relname
    LOOP -- _tables
        RAISE NOTICE '

OPERATING FOR TABLE [schema.rel] :: %', _tables.nspname||'.'||_tables.relname;
        
        -- get column info (name, type, NULL, constraints, defaults)
        FOR _columns IN
        -- compute diff for source->target
        -- FIXME: potential optimisation (information_schema -> raw catalog)
            with signs as (
                select 'DROP' as sign,
                       r_source.column_name as col
                from information_schema.columns as r_source
                where table_name = object_name  -- to yield d0
                  and table_schema = source_schema
                  and not exists (
                    select column_name
                    from information_schema.columns as r_target
                    where r_target.table_name = object_name
                      and r_target.table_schema = target_schema
                      and r_source.column_name = r_target.column_name) -- AJ predicate
                union -- inverse for `ADD'
                select 'ADD' as sign,
                       a_target.column_name as col
                from information_schema.columns as a_target
                where table_name = object_name       -- to yield d1
                  and table_schema = target_schema
                  and not exists (
                    select column_name
                    from information_schema.columns as a_source
                    where a_source.table_name = object_name
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
            RAISE NOTICE '
COLUMN: %', _columns.sign;
            IF _columns.sign = 'DROP' THEN
                col_ddl := 'ALTER TABLE '||source_schema||'.'||object_name||' DROP COLUMN '||_columns.col;
            ELSE
                SELECT INTO col_ddl
                'ALTER TABLE '||source_schema||'.'||object_name||' '
                ||'ADD COLUMN '||_columns.col||' '||_columns.column_type||' '
                ||_columns.column_default_value||' '||_columns.column_not_null;
            END IF;
            col_ddl := col_ddl||';';
            RETURN NEXT col_ddl;
        END LOOP; -- _columns

        -- _constraints, added at the end, also requires a diff
        FOR _constraints IN
            RAISE NOTICE
            SELECT conname, pg_get_constraintdef(c.oid) as constrainddef
            FROM pg_constraint c
            WHERE conrelid=(
                  SELECT attrelid FROM pg_attribute
                  WHERE attrelid = (
                      SELECT oid FROM pg_class
                      WHERE relname = _tables.relname
                        AND relnamespace = (SELECT ns.oid FROM pg_namespace ns WHERE ns.nspname = target_schema)
                  ) AND attname='tableoid'
            )
        LOOP
            RAISE NOTICE 'CONSTRAINT FOR %', _constraints.conname;
             SELECT INTO col_ddl
                'CONSTRAINT '||_constraints.conname||' '||_constraints.constrainddef;
              RETURN NEXT col_ddl; -- constraint return; returns less
        END LOOP; -- _constraints
       RAISE NOTICE 'return next %', col_ddl;

    END LOOP; -- _tables
END
$BODY$
    LANGUAGE plpgsql STABLE;
