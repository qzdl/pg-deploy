BEGIN transaction;


CREATE extension deploy_test;

/* STRUCTURAL TESTS FOR THE EXTENSION
  - check for table structure
  - functions and their parameter signature
*/
SELECT table_name, column_name, data_type FROM information_schema.columns
WHERE table_schema = 'deploy_test' ORDER BY table_name, column_name;

SELECT routines.routine_name, parameters.data_type, parameters.ordinal_position
FROM information_schema.routines
    LEFT JOIN information_schema.parameters ON routines.specific_name=parameters.specific_name
WHERE routines.specific_schema='deploy_test'
ORDER BY routines.routine_name, parameters.ordinal_position;


SELECT event_object_table AS table_name, trigger_schema, trigger_name,
       string_agg(event_manipulation, ',') AS event, action_timing,
       action_condition AS condition
FROM information_schema.triggers
WHERE event_object_schema = 'deploy_test' group by 1,2,3,5,6 order by table_name;


/* FUNCTIONAL TESTS FOR THE EXTENSION

PREPARATION: create the table for `other_state' to provide difference

*/

CREATE SCHEMA other_state;
create table if not exists other_state.test_reconsile(a int, b text, g int);


-- test if output from ext. will make `deploy_test' equal with `other_state'
SELECT * FROM public.reconsile_desired(
                              text 'deploy_test', -- original
                              text 'other_state', -- schema
                              text 'test_reconsile');

-- CLEAN UP
DROP extension deploy_test cascade;

ROLLBACK;
