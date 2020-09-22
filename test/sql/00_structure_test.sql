BEGIN transaction;
CREATE extension pgdeploy;
/* STRUCTURAL TESTS FOR THE EXTENSION
  - check for table structure
  - functions and their parameter signature
*/
SELECT table_name, column_name, data_type FROM information_schema.columns
WHERE table_schema = 'pgdeploy' ORDER BY table_name, column_name;

/* Check for routines (expect 3 *(character varying)) */
SELECT routines.routine_name, parameters.data_type, parameters.ordinal_position
FROM information_schema.routines
    LEFT JOIN information_schema.parameters ON routines.specific_name=parameters.specific_name
WHERE routines.specific_schema='pgdeploy'
ORDER BY routines.routine_name, parameters.ordinal_position;

/* Check for triggers (expect 0) */
SELECT event_object_table AS table_name, trigger_schema, trigger_name,
       string_agg(event_manipulation, ',') AS event, action_timing,
       action_condition AS condition
FROM information_schema.triggers
WHERE event_object_schema = 'pgdeploy' group by 1,2,3,5,6 order by table_name;

-- CLEAN UP
DROP extension pgdeploy cascade;
ROLLBACK;
