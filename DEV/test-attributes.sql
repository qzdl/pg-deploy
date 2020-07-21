--              ██     ██          ██ ██                ██
--             ░██    ░██         ░░ ░██               ░██
--   ██████   ██████ ██████ ██████ ██░██      ██   ██ ██████  █████   ██████
--  ░░░░░░██ ░░░██░ ░░░██░ ░░██░░█░██░██████ ░██  ░██░░░██░  ██░░░██ ██░░░░
--   ███████   ░██    ░██   ░██ ░ ░██░██░░░██░██  ░██  ░██  ░███████░░█████
--  ██░░░░██   ░██    ░██   ░██   ░██░██  ░██░██  ░██  ░██  ░██░░░░  ░░░░░██
-- ░░████████  ░░██   ░░██ ░███   ░██░██████ ░░██████  ░░██ ░░██████ ██████
--  ░░░░░░░░    ░░     ░░  ░░░    ░░ ░░░░░    ░░░░░░    ░░   ░░░░░░ ░░░░░░
-- attributes:
--
CREATE SCHEMA if NOT EXISTS testr;
CREATE SCHEMA if NOT EXISTS testp;
DROP TABLE if EXISTS testr.a;
DROP TABLE if EXISTS testp.a;

-- create objs for diff
-- expecting:
--   DROP i
--   DROP iii
--   ADD iv text
CREATE TABLE testr.a(i int, ii text, iii bit);
CREATE TABLE testp.a(ii text, iv numeric CONSTRAINT positive_price CHECK (iv > 0));

insert into res
select 1, 'expecting drop i,iii; add iv text' union
SELECT 1.1 deploy.reconcile_tables('testr', 'testp', 'a', 'a');


select * from res order by idx asc, ddl desc;
