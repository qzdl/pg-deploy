drop table if exists a.dropping, a.staying, b.creating, b.staying;
drop schema if exists a, b;

create schema a;
create schema b;
create table a.dropping(a int);
create table a.staying(a int, b int check (a > b));
create table b.creating(new_stuff text);
create table b.staying(a int, b int check (b > a));


select * from pgdeploy.cte_relation('a', 'b');

 nspname │ objname  │  oid  │    id
─────────┼──────────┼───────┼──────────
 a       │ dropping │ 65062 │ dropping
 a       │ staying  │ 65065 │ staying
 b       │ creating │ 65069 │ creating
 b       │ staying  │ 65075 │ staying
(4 rows)


select * from pgdeploy.object_difference('a', 'b', 'pgdeploy.cte_relation')

 s_schema │ s_objname │ s_oid  │   s_id   │ t_schema │ t_objname │ t_oid  │   t_id
──────────┼───────────┼────────┼──────────┼──────────┼───────────┼────────┼──────────
 a        │ dropping  │  65062 │ dropping │ (null)   │ (null)    │ (null) │ (null)
 a        │ staying   │  65065 │ staying  │ b        │ staying   │  65075 │ staying
 (null)   │ (null)    │ (null) │ (null)   │ b        │ creating  │  65069 │ creating
(3 rows)


select * from pgdeploy.reconcile_relation('a', 'b');

                    reconcile_relation
─────────────────────────────────────────────────────────
 -- LEFT and RIGHT of 'staying' are equal
 DROP TABLE IF EXISTS a.dropping
 CREATE TABLE a.creating(LIKE b.creating including all);
(3 rows)


select * from pgdeploy.reconcile_schema('b','a');

 priority │                                 ddl
──────────┼─────────────────────────────────────────────────────────────────────
        1 │ CREATE TABLE a.creating(LIKE b.creating including all);
        1 │ DROP TABLE IF EXISTS a.dropping
        1 │ -- LEFT and RIGHT of 'staying' are equal
        2 │ -- COLUMN: no change for a
        2 │ -- COLUMN: no change for b
        3 │ ALTER TABLE a.staying ADD CONSTRAINT staying_check CHECK ((b > a));
        3 │ ALTER TABLE a.staying DROP CONSTRAINT IF EXISTS staying_check;
(7 rows)
