



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

-----|| LEFT, RIGHT :: NO DELTA (round 2)
-- expecting NOTHING x2
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
select 5.0, 'lrnm2: pass (2 triggers)' union
select 5.1, deploy.reconcile_trigger(
    'testp'::name,
    (select c.oid from pg_class c inner join pg_namespace n on c.relnamespace = n.oid and n.nspname = 'testp' where relname = 'lrnm2'),
    'testr'::name,
    (select c.oid from pg_class c inner join pg_namespace n on c.relnamespace = n.oid and n.nspname = 'testr' where relname = 'lrnm2'));


-----|| NO LEFT, RIGHT && NO RIGHT, LEFT
-- expecting DROP ii, CREATE i
drop table if exists testp.nlrnrl;
drop table if exists testr.nlrnrl;
create table testp.nlrnrl(a text, b text);
create table testr.nlrnrl(a text, b text);
drop trigger if exists nlrnli_trig on testp.nlrnrl;
drop trigger if exists nlrnlii_trig on testp.nlrnrl;
drop trigger if exists nlrnli_trig on testr.nlrnrl;
drop trigger if exists nlrnlii_trig on testr.nlrnrl;
create trigger nlrnlii_trig before update on testp.nlrnrl for each row execute procedure testp.ttdep();
create trigger nlrnli_trig before update on testr.nlrnrl for each row execute procedure testr.ttdep();
INSERT into res
select 6.0, 'nlrnrl: drop ii, create i, (2 triggers)' union
select 6.1, deploy.reconcile_trigger(
    'testp'::name,
    (select c.oid from pg_class c inner join pg_namespace n on c.relnamespace = n.oid and n.nspname = 'testp' where relname = 'nlrnrl'),
    'testr'::name,
    (select c.oid from pg_class c inner join pg_namespace n on c.relnamespace = n.oid and n.nspname = 'testr' where relname = 'nlrnrl'));


select * from res order by idx asc, ddl desc;

-- TODO multiple triggers for one relation?

-- EVENT TRIGGERS
-- references a function

CREATE OR REPLACE FUNCTION testp.etdep() RETURNS event_trigger AS $$
BEGIN
    RAISE NOTICE 'IM (EVENT) TRIGGERED: % %', tg_event, tg_tag;
END;
$$ LANGUAGE plpgsql;
CREATE EVENT TRIGGER etdep ON ddl_command_start EXECUTE procedure testp.etdep();


drop event trigger etdep;
drop function testp.etdep;


-- GET EVENT TRIGGER FUNCTIONS
select p.* from pg_proc p inner join pg_type t on t.oid = p.prorettype where t.typname = 'event_trigger'


-- GET EVENT TRIGGER DETAILS
WITH tr AS (
  SELECT
      e.tableoid,
      e.oid,
      evtname,
      evtenabled,
      evtevent,
      array_to_string(array(select quote_literal(x) from unnest(evttags) as t(x)), ', ') as evttags,
      e.evtfoid::regproc as evtfname
  FROM pg_event_trigger e
  ORDER BY e.oid
)
SELECT
    ('CREATE EVENT TRIGGER '||evtname
    ||' ON '||evtevent
    ||(CASE WHEN evttags IS NOT NULL AND LENGTH(evttags) > 0
       THEN ' WHEN TAG IN ('||evttags||') '
       ELSE '' END)
    ||' EXECUTE FUNCTION '||evtfname||'()'
    ||(CASE WHEN evtenabled = 'O' THEN '' ELSE ' '||(
        CASE WHEN evtenabled = 'D' THEN 'DISABLE'
             WHEN evtenabled = 'A' THEN 'ENABLE ALWAYS'
             WHEN evtenabled = 'R' THEN 'ENABLE REPLICA'
                                   ELSE 'ENABLE' END) END)
    ) as ddl, *
FROM tr
order by ddl desc;

-- appendPQExpBufferStr(query, "CREATE EVENT TRIGGER ");
-- 	appendPQExpBufferStr(query, qevtname);
-- 	appendPQExpBufferStr(query, " ON ");
-- 	appendPQExpBufferStr(query, fmtId(evtinfo->evtevent));

-- 	if (strcmp("", evtinfo->evttags) != 0)
-- 	{
-- 		appendPQExpBufferStr(query, "\n         WHEN TAG IN (");
-- 		appendPQExpBufferStr(query, evtinfo->evttags);
-- 		appendPQExpBufferChar(query, ')');
-- 	}

-- 	appendPQExpBufferStr(query, "\n   EXECUTE FUNCTION ");
-- 	appendPQExpBufferStr(query, evtinfo->evtfname);
-- 	appendPQExpBufferStr(query, "();\n");


-- 	if (evtinfo->evtenabled != 'O')
-- 	{
-- 		appendPQExpBuffer(query, "\nALTER EVENT TRIGGER %s ",
-- 						  qevtname);
-- 		switch (evtinfo->evtenabled)
-- 		{
-- 			case 'D':
-- 				appendPQExpBufferStr(query, "DISABLE");
-- 				break;
-- 			case 'A':
-- 				appendPQExpBufferStr(query, "ENABLE ALWAYS");
-- 				break;
-- 			case 'R':
-- 				appendPQExpBufferStr(query, "ENABLE REPLICA");
-- 				break;
-- 			default:
-- 				appendPQExpBufferStr(query, "ENABLE");
-- 				break;
-- 		}

-- 	}
