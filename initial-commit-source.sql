--
-- PostgreSQL database dump
--

-- Dumped from database version 12.2 (Ubuntu 12.2-2.pgdg16.04+1)
-- Dumped by pg_dump version 12.2 (Ubuntu 12.2-2.pgdg16.04+1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

DROP FUNCTION IF EXISTS public.reconsile_desired(og_schema_name character varying, ds_schema_name character varying, object_name character varying);
DROP EXTENSION IF EXISTS deploy_test;
DROP SCHEMA IF EXISTS deploy_test;
--
-- Name: deploy_test; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA deploy_test;


--
-- Name: deploy_test; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS deploy_test WITH SCHEMA deploy_test;


--
-- Name: EXTENSION deploy_test; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION deploy_test IS 'A proof-of-concept to deploy a schema';


--
-- Name: reconsile_desired(character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reconsile_desired(og_schema_name character varying, ds_schema_name character varying, object_name character varying) RETURNS SETOF text
    LANGUAGE plpgsql STABLE
    AS $_$
DECLARE
    table_oid text;
    sign_attr_rec record;
    col_ddl text;
    col_rec record;
BEGIN
    -- check if og = ds; y-> do nothing
    --                   n-> calculate diff & barf alter ddl
   /* IF (1=0) */
        /* RETURN col_ddl; */
    /*
            TODO
    */
    -- get name, identifier for ds_obj so catalog info can be grabbed later
    table_oid := (
        SELECT c.oid
        FROM pg_catalog.pg_class c
            LEFT JOIN pg_catalog.pg_namespace n
                ON n.oid = c.relnamespace
        WHERE relkind = 'r'
            AND n.nspname = ds_schema_name
            AND relname~ ('^('||object_name||')$')
        ORDER BY c.relname);

    FOR sign_attr_rec IN
        -- compute diff for og->ds
        select 'DROP' as sign, r_source.column_name as col
        from information_schema.columns as r_source
        where table_name = object_name  -- to yield d0
          and table_schema = og_schema_name
          and not exists (
            select column_name
            from information_schema.columns as r_target
            where r_target.table_name = object_name
              and r_target.table_schema = ds_schema_name
              and r_source.column_name = r_target.column_name) -- AJ predicate
        union -- inverse for `ADD'
        select 'ADD' as sign, a_target.column_name as col
        from information_schema.columns as a_target
        where table_name = object_name       -- to yield d1
          and table_schema = ds_schema_name
          and not exists (
            select column_name
            from information_schema.columns as a_source
            where a_source.table_name = object_name
              and a_source.table_schema = og_schema_name
              and a_source.column_name = a_target.column_name) -- AJ predicate
    LOOP
        IF sign_attr_rec.sign = 'DROP' THEN
            col_ddl := 'ALTER TABLE '||og_schema_name||'.'||object_name||' DROP COLUMN '||sign_attr_rec.col||';';
        ELSE
            col_ddl := 'ALTER TABLE '||og_schema_name||'.'||object_name||' ADD COLUMN '||sign_attr_rec.col||' int;';
        END IF;
    RETURN NEXT col_ddl;
    END LOOP; -- table_rec

    -- if exists, generate `ALTERS' for DROP
    /*
            TODO
    */
    -- collect DROP; no further action on drops (constraints, indexes will be truncated automatically)

    -- if exists, generate `ALTERS' for ADD (to include indexes, constraints, defaults from ds_obj)
    /*
            TODO
    */
    -- collect ADD

    -- return (sign | expr)

END
$_$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: my_table; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.my_table (
    a integer,
    b integer,
    c integer,
    g integer
);


--
-- PostgreSQL database dump complete
--

