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

--- LRD2
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


select * from deploy.reconcile_function('testp'::name, 'testr'::name)
