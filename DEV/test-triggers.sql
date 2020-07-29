-- event trigger
CREATE OR REPLACE FUNCTION testp.etdep() RETURNS event_trigger AS $$
BEGIN
    RAISE NOTICE 'IM (EVENT) TRIGGERED: % %', tg_event, tg_tag;
END;
$$ LANGUAGE plpgsql;

CREATE EVENT TRIGGER etdep ON ddl_command_start EXECUTE procedure testp.etdep();
drop event trigger etdep;
drop function testp.etdep;



-- TABLEWISE
drop function if exists testp.ttdep;
--  functional dependency
create or replace function testp.ttdep() returns trigger as $$ begin raise notice 'im (table) triggered: % %', tg_event, tg_tag; end; $$ language plpgsql;
create or replace function testr.ttdep() returns trigger as $$ begin raise notice 'im (table) triggered: % %', tg_event, tg_tag; end; $$ language plpgsql;
--  results collation table
drop table if exists res;
create table res (idx float, ddl text);

-----|| NO LEFT, RIGHT
-- expecting CREATE from definition testr ONTO testp
--   as "create index nlr_idx on testp.nlr using hash (a);"
drop table if exists testp.nlr;
drop table if exists testr.nlr;
create table testp.nlr(a text);
create table testr.nlr(a text);
drop trigger if exists nlr_trig on testp.nlr;
drop trigger if exists nlr_trig on testr.nlr;
create trigger nlr_trig before update on testr.nlr for each row execute procedure testr.ttdep();  -- *expected output too
insert into res
select 1.0, 'nlr: create only' union
select 1.1, deploy.reconcile_trigger(
    'testp'::name,
    (select c.oid from pg_class c inner join pg_namespace n on c.relnamespace = n.oid and n.nspname = 'testp' where relname = 'nlr'),
    'testr'::name,
    (select c.oid from pg_class c inner join pg_namespace n on c.relnamespace = n.oid and n.nspname = 'testr' where relname = 'nlr'));

-----|| LEFT, NO RIGHT
-- expecting DROP from RELNAME on testp
--   as "DROP TRIGGER testp.lnr;"
drop table if exists testp.lnr;
drop table if exists testr.lnr;
create table testp.lnr(a text);
create table testr.lnr(a text);
drop trigger if exists lnr_trig on testp.lnr;
drop trigger if exists lnr_trig on testr.lnr;
create trigger lnr_trig before update on testp.lnr for each row execute procedure testp.ttdep();
INSERT into res
select 2.0, 'lnr: drop only' union
select 2.1, deploy.reconcile_trigger(
    'testp'::name,
    (select c.oid from pg_class c inner join pg_namespace n on c.relnamespace = n.oid and n.nspname = 'testp' where relname = 'lnr'),
    'testr'::name,
    (select c.oid from pg_class c inner join pg_namespace n on c.relnamespace = n.oid and n.nspname = 'testr' where relname = 'lnr'));

-----|| LEFT, RIGHT :: DELTA
-- expecting DROP from RELNAME on testp
--   as "DROP TRIGGER testp.lrm;"
-- expecting CREATE from definition testr ONTO testp
--   as "create trigger lrm_trig on testp.lrm using hash (a);"
drop table if exists testp.lrm;
drop table if exists testr.lrm;
create table testp.lrm(a text, b text);
create table testr.lrm(a text, b text);
drop trigger if exists lrm_trig on testp.lrm;
drop trigger if exists lrm_trig on testr.lrm;
create trigger lrm_trig before update on testp.lrm for each row execute procedure testp.ttdep();
create trigger lrm_trig after update on testr.lrm for each row execute procedure testr.ttdep(); -- *expected output too
INSERT into res
select 3.0, 'lrd: drop create' union
select 3.1, deploy.reconcile_trigger(
    'testp'::name,
    (select c.oid from pg_class c inner join pg_namespace n on c.relnamespace = n.oid and n.nspname = 'testp' where relname = 'lrm'),
    'testr'::name,
    (select c.oid from pg_class c inner join pg_namespace n on c.relnamespace = n.oid and n.nspname = 'testr' where relname = 'lrm'));

-----|| LEFT, RIGHT :: NO DELTA
-- expecting NOTHING
drop table if exists testp.lrnm;
drop table if exists testr.lrnm;
create table testp.lrnm(a text, b text);
create table testr.lrnm(a text, b text);
drop trigger if exists lrnm_trig on testp.lrnm;
drop trigger if exists lrnm_trig on testr.lrnm;
create trigger lrnm_trig before update on testp.lrnm for each row execute procedure testp.ttdep();
create trigger lrnm_trig before update on testr.lrnm for each row execute procedure testr.ttdep();
INSERT into res
select 4.0, 'lrnd: pass' union
select 4.1, deploy.reconcile_trigger(
    'testp'::name,
    (select c.oid from pg_class c inner join pg_namespace n on c.relnamespace = n.oid and n.nspname = 'testp' where relname = 'lrnm'),
    'testr'::name,
    (select c.oid from pg_class c inner join pg_namespace n on c.relnamespace = n.oid and n.nspname = 'testr' where relname = 'lrnm'));

drop table if exists testp.lrnm2;
drop table if exists testr.lrnm2;
create table testp.lrnm2(a text, b text);
create table testr.lrnm2(a text, b text);
drop trigger if exists lrnmi_trig on testp.lrnm2;
drop trigger if exists lrnmii_trig on testp.lrnm2;
drop trigger if exists lrnmi_trig on testr.lrnm2;
drop trigger if exists lrnmii_trig on testr.lrnm2;
create trigger lrnmi_trig before update on testp.lrnm2 for each row execute procedure testp.ttdep();
create trigger lrnmii_trig before update on testp.lrnm2 for each row execute procedure testp.ttdep();
create trigger lrnmi_trig before update on testr.lrnm2 for each row execute procedure testr.ttdep();
create trigger lrnmii_trig before update on testr.lrnm2 for each row execute procedure testr.ttdep();
INSERT into res
select 4.0, 'lrnm2: pass (2 triggers)' union
select 4.1, deploy.reconcile_trigger(
    'testp'::name,
    (select c.oid from pg_class c inner join pg_namespace n on c.relnamespace = n.oid and n.nspname = 'testp' where relname = 'lrnm2'),
    'testr'::name,
    (select c.oid from pg_class c inner join pg_namespace n on c.relnamespace = n.oid and n.nspname = 'testr' where relname = 'lrnm2'));




select * from res order by idx asc, ddl desc;

-- TODO multiple triggers for one relation?
