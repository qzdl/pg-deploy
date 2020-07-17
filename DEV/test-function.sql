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
select deploy.reconcile_function(
    'testp'::name,
    (select p.oid from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'testp' and p.proname = 'func_lrd')
    'testr'::name
    (select p.oid from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'testr' and p.proname = 'func_lrd'))

--- LRD2
--- expecting CREATE OR REPLACE func
create or replace function testp.func_lrd2(a int, g boolean) returns int as $body$ begin return 0; end; $body$ language plpgsql;
create or replace function testr.func_lrd2(a int, f boolean) returns int as $body$ begin return 0; end; $body$ language plpgsql;
select deploy.reconcile_function(
    'testp'::name,
    (select p.oid from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'testp' and p.proname = 'func_lrd2')
    'testr'::name
    (select p.oid from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'testr' and p.proname = 'func_lrd2'))

-- LRND
-- expecting nil
create or replace function testp.func_lrnd(a int, b int) returns int as $body$ begin return 0; end; $body$ language plpgsql;
create or replace function testr.func_lrnd(a int, b int) returns int as $body$ begin return 0; end; $body$ language plpgsql;
select deploy.reconcile_function(
    'testp'::name,
    (select p.oid from from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'testp' and p.proname = 'func_lrnd')
    'testr'::name
    (select p.oid from from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'testr' and p.proname = 'func_lrnd'))

-- NLR
-- expecting CREATE func
create or replace function testr.func_nlr(a int, b int) returns int as $body$ begin return 0; end; $body$ language plpgsql;
select deploy.reconcile_function(
    'testp'::name,
    (select p.oid from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'testp' and p.proname = 'func_nlr')
    'testr'::name
    (select p.oid from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'testr' and p.proname = 'func_nlr'))

-- LNR
-- expecting DROP func
drop function if exists testr.func_lnr(a int, b int);
create or replace function testp.func_lnr(a int, b int) returns int as $body$ begin return 0; end; $body$ language plpgsql;
select deploy.reconcile_function(
    'testp'::name,
    (select p.oid from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'testp' and p.proname = 'func_lnr')
    'testr'::name
    (select p.oid from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'testr' and p.proname = 'func_lnr'));
