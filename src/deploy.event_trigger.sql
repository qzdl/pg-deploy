-- split / replace '--deploy--' as signifier for deploy owned event triggers

DROP FUNCTION IF EXISTS deploy.reconcile_event_trigger();

CREATE OR REPLACE FUNCTION deploy.reconcile_event_trigger()
RETURNS SETOF TEXT AS
$BODY$
BEGIN
    RETURN QUERY
    WITH tr AS (
      SELECT DISTINCT
          e.tableoid,
          e.oid,
          evtname,
          evtenabled,
          evtevent,
          array_to_string(
            ARRAY(SELECT quote_literal(x)
                  FROM UNNEST(evttags) AS t(x)), ', ') AS evttags,
          e.evtfoid::regproc AS evtfname
      FROM object_difference(''::name,''::name,'cte_event_trigger'::name) od
      INNER JOIN pg_event_trigger e
        ON e.oid = od.s_oid OR e.oid = od.t_oid
    )
    SELECT CASE
      WHEN t_schema IS NULL THEN
        'DROP EVENT TRIGGER IF EXISTS '||s_objname||';'
      WHEN s_schema IS NULL THEN
        'CREATE EVENT TRIGGER '||evtname||' ON '||evtevent       -- event listener
        ||(CASE WHEN evttags IS NOT NULL AND LENGTH(evttags) > 0 -- tags
           THEN ' WHEN TAG IN ('||evttags||') '                  -- tags
           ELSE '' END)                                          -- tags
        ||' EXECUTE FUNCTION '||evtfname||'();'                  -- event function
        ||(CASE WHEN evtenabled = 'O' THEN '' ELSE '
    ALTER EVENT TRIGGER '||evtname||' '||(                       -- second ddl statement,
            CASE WHEN evtenabled = 'D' THEN 'DISABLE'            -- for enabling trigger
                 WHEN evtenabled = 'A' THEN 'ENABLE ALWAYS'
                 WHEN evtenabled = 'R' THEN 'ENABLE REPLICA'
                 ELSE 'ENABLE' END)||';' END)
      ELSE
        '-- EVENT TRIGGER: LEFT and RIGHT of '''||s_objname||''' on '''||evtevent||''' are equal'
      END AS ddl
    FROM tr
    ORDER BY ddl DESC; -- comments and drops first
END;
$BODY$
    LANGUAGE plpgsql STABLE;

select * from deploy.reconcile_event_trigger();
