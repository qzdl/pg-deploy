-- https://www.postgresql.org/docs/current/catalog-pg-index.html
-- Is index for foo.bar(a b c) equal to foop.bar(a b c)?
-- algorithm (hash gist gin)
-- # of attrs covered
-- # of key attrs
-- collation
-- expression trees (indexprs, indpred); if not nil, s=t? dispatch t, pass
-- indices can be referenced by SCHEMA.INDEX_NAME, as they have to be unique per namespace
CREATE SCHEMA IF NOT EXISTS deploy;

DROP FUNCTION IF EXISTS deploy.reconcile_index(
    source_schema name, source_oid oid,
    target_schema name, target_oid oid);

CREATE OR REPLACE FUNCTION deploy.reconcile_index(
    source_schema name, source_oid oid,
    target_schema name, target_oid oid)
RETURNS SETOF TEXT AS
$BODY$
DECLARE
    _index RECORD;
    ddl TEXT;
BEGIN
    RAISE NOTICE 'ARGS %', source_schema||'|'||source_oid||':'||target_schema||'|'||target_oid;
    
    FOR _index IN
        WITH indices AS
        (
            SELECT
                indrelid, indexrelid, ic.relname, n.nspname,
                replace(pg_get_indexdef(indexrelid), target_schema||'.', source_schema||'.') AS def
            FROM pg_catalog.pg_index AS i
            INNER JOIN pg_catalog.pg_class AS ic
                ON ic.oid = i.indexrelid
            INNER JOIN pg_catalog.pg_namespace AS n
                ON n.oid = ic.relnamespace
            WHERE i.indrelid = source_oid or i.indrelid = target_oid
        )
        SELECT 'DROP' AS sign, indexrelid, relname, indrelid, def
        FROM indices AS m
        WHERE nspname = source_schema
          AND NOT EXISTS (
            SELECT indexrelid, relname
            FROM indices AS i
            WHERE i.nspname = target_schema
              AND i.relname = m.relname)
        UNION ALL
        SELECT 'DELTA' AS sign, indexrelid, relname, indrelid, def
        FROM indices AS m
        WHERE nspname = target_schema
          AND (
            NOT EXISTS (
              SELECT indexrelid, relname
              FROM indices AS i
              WHERE i.nspname =  source_schema
                AND i.relname = m.relname)
            OR m.def <> (SELECT def
                         FROM indices AS i
                         WHERE i.nspname = source_schema
                         AND i.relname = m.relname))
    LOOP
        RAISE NOTICE 'INDEX LOOP: %', _index;

        SELECT INTO ddl
          'DROP INDEX IF EXISTS '||source_schema||'.'||_index.relname||'; ';

        IF (_index.sign = 'DELTA') THEN
            ddl := ddl||_index.def||';';
        END IF;
        RETURN NEXT ddl;
    END LOOP;
END;
$BODY$
    LANGUAGE plpgsql STABLE;
