-- https://www.postgresql.org/docs/current/catalog-pg-index.html
-- Is index for foo.bar(a b c) equal to foop.bar(a b c)?
-- algorithm (hash gist gin)
-- # of attrs covered
-- # of key attrs
-- collation
-- expression trees (indexprs, indpred); if not nil, s=t? dispatch t, pass
-- indices can be referenced by SCHEMA.INDEX_NAME, as they have to be unique per namespace
DROP FUNCTION IF EXISTS pgdeploy.reconcile_index(
    source_schema name, source_oid oid,
    target_schema name, target_oid oid);

CREATE OR REPLACE FUNCTION pgdeploy.reconcile_index(
    source_schema name, source_oid oid,
    target_schema name, target_oid oid)
RETURNS SETOF TEXT AS
$BODY$
BEGIN
    RETURN QUERY
    SELECT DISTINCT CASE
        WHEN t_schema IS NULL THEN
          'DROP INDEX IF EXISTS '||s_schema||'.'||s_objname
        WHEN s_schema IS NULL THEN
          replace(pg_get_indexdef(t_oid),
            target_schema||'.', source_schema||'.')
        ELSE
          '-- LEFT and RIGHT of '''||s_objname||''' are equal'
        END AS ddl
    FROM pgdeploy.object_difference(
      source_schema, target_schema, 'pgdeploy.cte_index', source_oid, target_oid);
END;
$BODY$
    LANGUAGE plpgsql STABLE;

--select * from pgdeploy.reconcile_index(
--  'testp'::name, (select c.oid from pg_class c inner join pg_namespace n on c.relnamespace = n.oid and n.nspname = 'testp' where relname = 'lnr'),
--  'testr'::name, (select c.oid from pg_class c inner join pg_namespace n on c.relnamespace = n.oid and n.nspname = 'testr' where relname = 'lnr'));
