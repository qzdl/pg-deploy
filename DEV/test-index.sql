
--     ██               ██                     ██                     ██
--    ░░               ░██                    ░██                    ░██
--     ██ ███████      ░██  █████  ██   ██   ██████  █████   ██████ ██████  ██████
--    ░██░░██░░░██  ██████ ██░░░██░░██ ██   ░░░██░  ██░░░██ ██░░░░ ░░░██░  ██░░░░
--    ░██ ░██  ░██ ██░░░██░███████ ░░███      ░██  ░███████░░█████   ░██  ░░█████
--    ░██ ░██  ░██░██  ░██░██░░░░   ██░██     ░██  ░██░░░░  ░░░░░██  ░██   ░░░░░██
--    ░██ ███  ░██░░██████░░██████ ██ ░░██    ░░██ ░░██████ ██████   ░░██  ██████
--    ░░ ░░░   ░░  ░░░░░░  ░░░░░░ ░░   ░░      ░░   ░░░░░░ ░░░░░░     ░░  ░░░░░░


-----|| NO LEFT, RIGHT
-- expecting CREATE from definition testr ONTO testp
--   as "create index nlr_idx on testp.nlr using hash (a);"
drop table if exists testp.nlr;
drop table if exists testr.nlr;
create table testp.nlr(a text);
create table testr.nlr(a text);
drop index if exists testp.nlr_idx;
drop index if exists testr.nlr_idx;
create index nlr_idx on testr.nlr using hash (a); -- *expected output too
select deploy.reconcile_index(
    'testp'::name,
    (select c.oid from pg_class c inner join pg_namespace n on c.relnamespace = n.oid and n.nspname = 'testp' where relname = 'nlr'),
    'testr'::name,
    (select c.oid from pg_class c inner join pg_namespace n on c.relnamespace = n.oid and n.nspname = 'testr' where relname = 'nlr'));
-----|| LEFT, NO RIGHT
-- expecting DROP from RELNAME on testp
--   as "DROP INDEX testp.lnr;"
drop table if exists testp.lnr;
drop table if exists testr.lnr;
create table testp.lnr(a text);
create table testr.lnr(a text);
drop index if exists testp.lnr_idx;
drop index if exists testr.lnr_idx;
create index lnr_idx on testp.lnr using hash (a);
select deploy.reconcile_index(
    'testp'::name,
    (select c.oid from pg_class c inner join pg_namespace n on c.relnamespace = n.oid and n.nspname = 'testp' where relname = 'lnr'),
    'testr'::name,
    (select c.oid from pg_class c inner join pg_namespace n on c.relnamespace = n.oid and n.nspname = 'testr' where relname = 'lnr'));
-----|| LEFT, RIGHT :: MOD
-- expecting DROP from RELNAME on testp
--   as "DROP INDEX testp.lrm;"
-- expecting CREATE from definition testr ONTO testp
--   as "create index lrm_idx on testp.lrm using hash (a);"
drop table if exists testp.lrm;
drop table if exists testr.lrm;
create table testp.lrm(a text, b text);
create table testr.lrm(a text, b text);
drop index if exists testp.lrm_idx;
drop index if exists testr.lrm_idx;
create index lrm_idx on testp.lrm using hash (a);
create index lrm_idx on testr.lrm using hash (b); -- *expected output too
select deploy.reconcile_index(
    'testp'::name,
    (select c.oid from pg_class c inner join pg_namespace n on c.relnamespace = n.oid and n.nspname = 'testp' where relname = 'lrm'),
    'testr'::name,
    (select c.oid from pg_class c inner join pg_namespace n on c.relnamespace = n.oid and n.nspname = 'testr' where relname = 'lrm'));
-----|| LEFT, RIGHT :: NO MOD
-- expecting NOTHING
drop table if exists testp.lrnm;
drop table if exists testr.lrnm;
create table testp.lrnm(a text, b text);
create table testr.lrnm(a text, b text);
drop index if exists testp.lrnm_idx;
drop index if exists testr.lrnm_idx;
create index lrnm_idx on testp.lrnm using hash (a);
create index lrnm_idx on testr.lrnm using hash (a);
select deploy.reconcile_index(
    'testp'::name,
    (select c.oid from pg_class c inner join pg_namespace n on c.relnamespace = n.oid and n.nspname = 'testp' where relname = 'lrnm'),
    'testr'::name,
    (select c.oid from pg_class c inner join pg_namespace n on c.relnamespace = n.oid and n.nspname = 'testr' where relname = 'lrnm'));
