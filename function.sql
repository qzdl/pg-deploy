CREATE FUNCTION public.reconsile_desired(
    og_schema_name character varying,
    ds_schema_name character varying,
    object_name character varying)
    -- change `varying' to `name'? (ref existing object in db)
RETURNS SETOF text AS
$BODY$
DECLARE
    table_oid text;
    sign_attr_rec record;
    col_ddl text;
    col_rec record;
BEGIN
    -- check if og = ds; y-> do nothing
    --                   n-> calculate diff & barf alter ddl
   /* IF (1=0) */
        /* RETURN col_ddl; */
    /*
            TODO
    */
    -- get name, identifier for ds_obj so catalog info can be grabbed later
    table_oid := (
        SELECT c.oid
        FROM pg_catalog.pg_class c
            LEFT JOIN pg_catalog.pg_namespace n
                ON n.oid = c.relnamespace
        WHERE relkind = 'r'
            AND n.nspname = ds_schema_name
            AND relname~ ('^('||object_name||')$')
        ORDER BY c.relname);

    FOR sign_attr_rec IN
        -- compute diff for og->ds
        select 'DROP' as sign, r_source.column_name as col
        from information_schema.columns as r_source
        where table_name = object_name  -- to yield d0
          and table_schema = og_schema_name
          and not exists (
            select column_name
            from information_schema.columns as r_target
            where r_target.table_name = object_name
              and r_target.table_schema = ds_schema_name
              and r_source.column_name = r_target.column_name) -- AJ predicate
        union -- inverse for `ADD'
        select 'ADD' as sign, a_target.column_name as col
        from information_schema.columns as a_target
        where table_name = object_name       -- to yield d1
          and table_schema = ds_schema_name
          and not exists (
            select column_name
            from information_schema.columns as a_source
            where a_source.table_name = object_name
              and a_source.table_schema = og_schema_name
              and a_source.column_name = a_target.column_name) -- AJ predicate
    LOOP
        IF sign_attr_rec.sign = 'DROP' THEN
            col_ddl := 'ALTER TABLE '||og_schema_name||'.'||object_name||' DROP COLUMN '||sign_attr_rec.col||';';
        ELSE
            col_ddl := 'ALTER TABLE '||og_schema_name||'.'||object_name||' ADD COLUMN '||sign_attr_rec.col||' int;';
        END IF;
    RETURN NEXT col_ddl;
    END LOOP; -- table_rec

    -- if exists, generate `ALTERS' for DROP
    /*
            TODO
    */
    -- collect DROP; no further action on drops (constraints, indexes will be truncated automatically)

    -- if exists, generate `ALTERS' for ADD (to include indexes, constraints, defaults from ds_obj)
    /*
            TODO
    */
    -- collect ADD

    -- return (sign | expr)

END
$BODY$
    LANGUAGE plpgsql STABLE;
