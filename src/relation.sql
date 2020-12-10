CREATE OR REPLACE FUNCTION pgdeploy.reconcile_relation(
    source_schema name, target_schema name)
RETURNS SETOF TEXT AS
$BODY$
BEGIN
    RETURN QUERY
    SELECT DISTINCT
        CASE WHEN t_schema IS NULL THEN
          'DROP TABLE IF EXISTS '||s_schema||'.'||s_id||';'
             WHEN s_schema IS NULL THEN
          'CREATE TABLE '||source_schema||'.'||t_objname||'(LIKE '||t_schema||'.'||t_objname||' including all);'
             ELSE
          '-- LEFT and RIGHT of '''||s_id||''' are equal' END AS ddl
      FROM pgdeploy.object_difference(source_schema, target_schema, 'pgdeploy.cte_relation')
      ORDER BY ddl DESC; -- comments and drops first
END;
$BODY$
    LANGUAGE plpgsql STABLE;

drop schema if exists a, b;
drop table if exists a.dropping, a.staying, b.creating, b.staying;
create schema a;
create schema b;
create table a.dropping(a int);
create table a.staying(a int, b int check (a > b));
create table b.creating(new_stuff text);
create table b.staying(a int, b int check (b > a));
select * from pgdeploy.reconcile_relation('a', 'b');
select * from pgdeploy.object_difference('a', 'b', 'pgdeploy.cte_relation')

--                     reconcile_relation
-- ─────────────────────────────────────────────────────────
--  -- LEFT and RIGHT of 'staying' are equal
--  DROP TABLE IF EXISTS a.dropping
--  CREATE TABLE a.creating(LIKE b.creating including all);
-- (3 rows)
--
--  s_schema │ s_objname │ s_oid  │   s_id   │ t_schema │ t_objname │ t_oid  │   t_id
-- ──────────┼───────────┼────────┼──────────┼──────────┼───────────┼────────┼──────────
--  a        │ dropping  │  65062 │ dropping │ (null)   │ (null)    │ (null) │ (null)
--  a        │ staying   │  65065 │ staying  │ b        │ staying   │  65075 │ staying
--  (null)   │ (null)    │ (null) │ (null)   │ b        │ creating  │  65069 │ creating
-- (3 rows)
