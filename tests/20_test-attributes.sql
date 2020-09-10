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
BEGIN;
CREATE SCHEMA if NOT EXISTS testr;
CREATE SCHEMA if NOT EXISTS testp;
DROP TABLE if EXISTS testr.a;
DROP TABLE if EXISTS testp.a;

CREATE TABLE testr.a(i int, ii text, iii bit);
CREATE TABLE testp.a(ii text, iv numeric CONSTRAINT positive_price CHECK (iv > 0));
/*
insert into res
select 1, 'expecting drop i,iii; add iv text' union
SELECT 1.1 deploy.reconcile_table_attributes('testr', 'testp', 'a', 'a');
*/

select * from res order by idx asc, ddl desc;
END;
