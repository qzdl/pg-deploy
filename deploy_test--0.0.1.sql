
/* reconsile for tables

This function will run for each existing object


drop table if exists d0, d1;
create table if not exists d0(a int, b text, c int, d int, e int);
create table if not exists d1(a int, b text, g int);

SELECT *
FROM public.reconsile_desired('public', 'd0', 'desired', 'd1')

;; =>
ALTER TABLE public.d0 DROP COLUMN IF EXISTS c;
ALTER TABLE public.d0 DROP COLUMN IF EXISTS d;
ALTER TABLE public.d0 DROP COLUMN IF EXISTS e;
ALTER TABLE public.d0 ADD COLUMN IF NOT EXISTS g int;


========
Room for improvement:
- object_name must be the same between the two schemas; for the usecase, it doesn't
  make sense to permit comparisons between arbitrary objects, *but*, the `sign_attr_rec'
  query is capable of comparing arbitrary objects;
- decoupling DROP / ADD
    * In the case of data migration, it would pay to have an associative structure
      that models the transition from state0->state1 & state1->state0:
      s0 => t(a string)    ('1|2|3|4')
      s1 => t(ab string[]) (['1', '2', '3', '4'])
      tr (s0->s1) => split_string_to_array(a, '|')
      tr (s1->s0) => join_array_to_string(a, '|')
- currently operates for 'full' changes;
  * once the structure of the function has
    been realised, it would make sense to diff on the individual attributes between
    existing columns.

*/

CREATE SCHEMA deploy_test;

CREATE TABLE IF NOT EXISTS deploy_test.test_reconsile(a int, b text, c int, d int, e int);

/* Should be written as a pl script; decouple from instance, keep in repository */
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
