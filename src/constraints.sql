/*
    reconcile_constraints:
    - diff of constraints for tables through anti-join
    - mark for ALTER



*/

CREATE FUNCTION deploy.reconcile_constraints(
    source_schema text, source_rel text, source_oid int
    target_schema text, target_rel text, target_oid int)
RETURNS SETOF text AS
$BODY$
DECLARE
    _constraints record;
BEGIN
-- _constraints, added at the end, also requires a diff
    FOR _constraints IN
        WITH signs AS (
            SELECT
                'DROP' AS sign,
                conname, pg_get_constraintdef(c.oid) as constrainddef,
                CASE
                    WHEN pg_get_constraintdef(c.oid) = pg_get_constraintdef(target_oid)
                    THEN 0
                    ELSE 1
                END AS parity
            FROM pg_constraint c
            WHERE conrelid = source_oid
            UNION
            SELECT
                'ADD' as sign,
                conname, pg_get_constraintdef(c.oid) as constraintdef,
                CASE
                    WHEN pg_get_constraintdef(c.oid) = pg_get_constraintdef(source_oid)
                    THEN 0
                    ELSE 1
                END AS parity
            FROM pg_constraint c
            WHERE conrelid = target_oid
        )
        SELECT sign, conname, constraintde
    LOOP
        RAISE NOTICE 'CONSTRAINT FOR %', _constraints.conname;

        IF _constraints.sign = 'DROP' or _constraints.parity = 0 THEN
            ddl := 'ALTER TABLE '||source_schema||'.'||source_rel
                   ||' DROP CONSTRAINT '||_constraints.connname||'; ';
        END IF;

        IF _constraints.sign = 'ADD' or _constraints.parity = 0 THEN
            ddl := ddl||'ALTER TABLE '||source_schema||'.'||source_rel
                   ||'ADD CONSTRAINT'||_constraints.conname||' '||_constraints.constraintdef;
        END IF;
        ddl := ddl||';';
        RETURN NEXT col_ddl;
    END LOOP; -- _constraints
END
$BODY$
    LANGUAGE plpgsql STABLE;
