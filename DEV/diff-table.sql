-- d0 :: existing object in-place
-- d1 :: 'desired' object against which table schema is reconsiled

-- This query unions the anti-join of both sides, to 'diff' `d0' <-> `d1' for +/- columns
--  : anti-join will return the
-- NOTE: default constraints will have to be applied at the point of addition, per the policies
-- 	 on adding `NOT NULL' attributes to live objects

-- =====================
-- ADDITION
-- =====================
drop table if exists d0, d1;
create table if not exists d0(a int, b text);
create table if not exists d1(a int, b text, c int);

select '-' || d0.column_name as dz
from information_schema.columns as d0
left join (select column_name from information_schema.columns where table_name = 'd1') as d1
    on d0.column_name = d1.column_name
where
     table_name = 'd0'-- to yield d0
and  d1.column_name IS NULL  -- predicate for ANTI-JOIN
union
select '+' || d0.column_name as dz
from information_schema.columns as d0
left join (select column_name from information_schema.columns where table_name = 'd0') as d1
    on d0.column_name = d1.column_name
where
     table_name = 'd1'-- to yield d0
and  d1.column_name IS NULL;  -- predicate for ANTI-JOIN

-- =====================
-- REMOVAL
-- =====================

    drop table if exists d0, d1;
    create table if not exists d0(a int, b text, c int, d int, e int);
    create table if not exists d1(a int, b text, g int);

    select r_source.table_name AS object_name, 'DROP' as sign, r_source.column_name as col
    from information_schema.columns as r_source
    where table_name = 'd0'        -- to yield d0
      and not exists (
        select column_name
        from information_schema.columns as r_target
        where r_target.table_name = 'd1'
          and r_source.column_name = r_target.column_name) -- AJ predicate
    union
    select a_target.table_name as oject_name, 'ADD' as sign, a_target.column_name as col
    from information_schema.columns as a_target
    where table_name = 'd1'       -- to yield d1
      and not exists (
        select column_name
        from information_schema.columns as a_source
        where a_source.table_name = 'd0'
          and a_source.column_name = a_target.column_name); -- AJ predicate


    select 'DROP' as sign, r_source.column_name as col
    from information_schema.columns as r_source
    where table_name = 'test_reconsile'  -- to yield d0
      and table_schema = 'public'
      and not exists (
        select column_name
        from information_schema.columns as r_target
        where r_target.table_name = 'test_reconsile'
          and r_target.table_schema = 'desired'
          and r_source.column_name = _target.column_name) -- AJ predicate
    union
    select 'ADD' as sign, a_target.column_name as col
    from information_schema.columns as a_target
    where table_name = 'test_reconsile'       -- to yield d1
      and table_schema = 'desired'
      and not exists (
        select column_name
        from information_schema.columns as a_source
        where a_source.table_name = 'test_resonsile'
          and a_target.table_schema = 'public'
          and a_source.column_name = a_target.column_name) -- AJ predicate

/* DO $$ */
/* DECLARE */
/*     t_current TEXT := 'd0'; */
/*     t_desired TEXT := 'd1'; */
/* BEGIN */
/*     RAISE NOTICE 'current: %, desired: %', t_current, t_desired; */

/*     drop table if exists d0, d1; */
/*     create table if not exists d0(a int, b text, c int, d int, e int); */
/*     create table if not exists d1(a int, b text, g int); */

/*     select '-' || r_source.column_name as sign_col */
/*     from information_schema.columns as r_source */
/*     left join (select column_name */
/*                from information_schema.columns */
/*                where table_name = t_desired) as r_target */
/*         on r_source.column_name = r_target.column_name */
/*     where */
/*          table_name = t_current        -- to yield d0 */
/*     and  r_target.column_name IS NULL  -- predicate for ANTI-JOIN */
/*     union */
/*     select '+' || a_source.column_name as sign_col */
/*     from information_schema.columns as a_source */
/*     left join (select column_name */
/*                from information_schema.columns */
/*                where table_name = t_current) as a_target */
/*         on a_source.column_name = a_target.column_name */
/*     where */
/*          table_name = t_desired -- to yield d1 */
/*     and  a_source.column_name IS NULL;  -- predicate for ANTI-JOIN */

/* END $$; */






/* DO $$ */
/* DECLARE */
/*     t_current TEXT := 'd0'; */
/*     t_desired TEXT := 'd1'; */
/* BEGIN */
/*     RAISE NOTICE 'current: %, desired: %', t_current, t_desired; */

/*     drop table if exists d0, d1; */
/*     create table if not exists d0(a int, b text, c int, d int, e int); */
/*     create table if not exists d1(a int, b text, g int); */

/*     select '-' || r_source.column_name as sign_col */
/*     from information_schema.columns as r_source */
/*     where table_name = t_current        -- to yield d0 */
/*       and not exists ( */
/*         select column_name */
/*         from information_schema.columns as r_target */
/*         where r_target.table_name = t_desired */
/*           and r_source.column_name = r_target.column_name) -- AJ predicate */
/*     union */
/*     select '+' || a_target.column_name as sign_col */
/*     from information_schema.columns as a_target */
/*     where table_name = t_desired       -- to yield d1 */
/*       and not exists ( */
/*         select column_name */
/*         from information_schema.columns as a_source */
/*         where a_source.table_name = t_current */
/*           and a_source.column_name = a_target.column_name); -- AJ predicate */

/* END $$; */
