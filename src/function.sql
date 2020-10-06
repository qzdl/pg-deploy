CREATE OR REPLACE FUNCTION pgdeploy.reconcile_function(
    source_schema name, target_schema name)
RETURNS SETOF TEXT AS
$BODY$
BEGIN
    RETURN QUERY
    SELECT DISTINCT CASE
      WHEN t_schema IS NULL THEN
        'DROP '|| (CASE WHEN a.aggfnoid IS NOT NULL THEN 'AGGREGATE' ELSE 'FUNCTION' END)
         ||' IF EXISTS '||s_schema||'.'||s_objname||';'
      WHEN s_schema IS NULL THEN
        replace((CASE WHEN l.lanname = 'internal'
           THEN '-- unsupported function definition ('||t_objname||') '||p.prosrc
           ELSE pg_get_functiondef(t_oid) END),
          target_schema||'.', source_schema||'.')
      ELSE
        '-- LEFT and RIGHT of '''||s_objname||''' are equal'
      END AS ddl
    FROM pgdeploy.object_difference(source_schema, target_schema, 'pgdeploy.cte_function')
    INNER JOIN pg_proc p ON p.oid = s_oid OR p.oid = t_oid
    LEFT JOIN pg_language l ON p.prolang = l.oid
    LEFT JOIN pg_aggregate a ON a.aggfnoid = p.oid
    ORDER BY ddl DESC; -- comments and drops first
END;
$BODY$
    LANGUAGE plpgsql STABLE;

--select * from pgdeploy.reconcile_function('testp', 'testr');
