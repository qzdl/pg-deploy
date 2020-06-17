CREATE FUNCTION deploy.reconcile_constraints(
    source_schema text,
    target_schema text,
    source_rel text,
    target_rel
)
RETURNS SETOF text AS
$BODY$
DECLARE
    _constraints record;
BEGIN
-- _constraints, added at the end, also requires a diff
    FOR _constraints IN
        SELECT conname, pg_get_constraintdef(c.oid) as constrainddef
        FROM pg_constraint c
        WHERE conrelid=( -- 0
            SELECT attrelid
            FROM pg_attribute
            WHERE attrelid = ( -- 1
                SELECT oid
                FROM pg_class
                WHERE relname = target_rel
                  AND relnamespace = ( -- 2
                   SELECT ns.oid
                   FROM pg_namespace ns
                   WHERE ns.nspname = target_schema) -- 2
            ) AND attname='tableoid' ) -- 1, 0
    LOOP
        RAISE NOTICE 'CONSTRAINT FOR %', _constraints.conname;
        ddl := 'ALTER TABLE '||source_schema||'.'||source_rel||' ';
        IF _constraints.sign = 'DROP' THEN
            ddl := ddl||'DROP CONSTRAINT '||_constraints.connname;
        ELSE
            ddl : ddl||'ADD CONSTRAINT'||_constraints.conname||' '||_constraints.constrainddef;
        END IF;
        ddl := ddl||';';
        RETURN NEXT col_ddl;
    END LOOP; -- _constraints
END
$BODY$
    LANGUAGE plpgsql STABLE;
