--  ████████                            ██████████                   ██
-- ░██░░░░░                            ░░░░░██░░░                   ░██
-- ░██       ██   ██ ███████   █████       ░██      █████   ██████ ██████
-- ░███████ ░██  ░██░░██░░░██ ██░░░██      ░██     ██░░░██ ██░░░░ ░░░██░
-- ░██░░░░  ░██  ░██ ░██  ░██░██  ░░       ░██    ░███████░░█████   ░██
-- ░██      ░██  ░██ ░██  ░██░██   ██      ░██    ░██░░░░  ░░░░░██  ░██
-- ░██      ░░██████ ███  ░██░░█████       ░██    ░░██████ ██████   ░░██
-- ░░        ░░░░░░ ░░░   ░░  ░░░░░        ░░      ░░░░░░ ░░░░░░     ░░
--
--- LRD
--- expecting CREATE OR REPLACE func
create or replace function testp.func_lrd(a int, b text) returns int as $body$ begin return 0; end; $body$ language plpgsql;
create or replace function testr.func_lrd(a int, b int) returns int as $body$ begin return 0; end; $body$ language plpgsql;


--- LRD2
--- expecting CREATE OR REPLACE func
create or replace function testp.func_lrd2(a int, g boolean) returns int as $body$ begin return 0; end; $body$ language plpgsql;
create or replace function testr.func_lrd2(a int, f boolean) returns int as $body$ begin return 0; end; $body$ language plpgsql;

--- LRD3
--- expecting CREATE OR REPLACE func
create or replace function testp.func_lrd3(a int, g boolean) returns int as $body$ begin return 0; end; $body$ language plpgsql;
create or replace function testr.func_lrd3(a int, f boolean) returns int as $body$ begin return 1; end; $body$ language plpgsql;

-- LRND
-- expecting nil
create or replace function testp.func_lrnd(a int, b int) returns int as $body$ begin return 0; end; $body$ language plpgsql;
create or replace function testr.func_lrnd(a int, b int) returns int as $body$ begin return 0; end; $body$ language plpgsql;

-- NLR
-- expecting CREATE func
create or replace function testr.func_nlr(a int, b int) returns int as $body$ begin return 0; end; $body$ language plpgsql;


-- LNR
-- expecting DROP func
drop function if exists testr.func_lnr(a int, b int);
create or replace function testp.func_lnr(a int, b int) returns int as $body$ begin return 0; end; $body$ language plpgsql;


-- USER DEFINED AGGREGATES
CREATE AGGREGATE testp.cavg (float8)
(
    sfunc = float8_accum,
    stype = float8[],
    finalfunc = float8_avg,
    initcond = '{0,0,0}'
);


drop function if exists testp.cavg;


/* these are a bit weird;
- bodies are not stored
- marked as internal
- error on `pg_get_functiondef`
  - `ERROR: "cavg" is an aggregate function`
*/


select pg_get_function_arguments((select oid from pg_proc where proname = 'cavg'));
select pg_get_function_identity_arguments((select oid from pg_proc where proname = 'cavg'));


select pg_get_functiondef((select oid from pg_proc where proname = 'cavg'));


select * from deploy.reconcile_function('testp'::name, 'testr'::name)
