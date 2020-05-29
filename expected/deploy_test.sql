BEGIN transaction;
CREATE extension deploy_test;
/* STRUCTURAL TESTS FOR THE EXTENSION
  - check for table structure
  - functions and their parameter signature
*/
SELECT table_name, column_name, data_type FROM information_schema.columns
WHERE table_schema = 'deploy_test' ORDER BY table_name, column_name;
   table_name   | column_name | data_type 
----------------+-------------+-----------
 test_reconsile | a           | integer
 test_reconsile | b           | text
 test_reconsile | c           | integer
 test_reconsile | d           | integer
 test_reconsile | e           | integer
(5 rows)

/* Check for routines (expect 3 *(character varying)) */
SELECT routines.routine_name, parameters.data_type, parameters.ordinal_position
FROM information_schema.routines
    LEFT JOIN information_schema.parameters ON routines.specific_name=parameters.specific_name
WHERE routines.specific_schema='deploy_test'
ORDER BY routines.routine_name, parameters.ordinal_position;
   routine_name    |     data_type     | ordinal_position 
-------------------+-------------------+------------------
 reconsile_desired | character varying |                1
 reconsile_desired | character varying |                2
 reconsile_desired | character varying |                3
(3 rows)

/* Check for triggers (expect 0) */
SELECT event_object_table AS table_name, trigger_schema, trigger_name,
       string_agg(event_manipulation, ',') AS event, action_timing,
       action_condition AS condition
FROM information_schema.triggers
WHERE event_object_schema = 'deploy_test' group by 1,2,3,5,6 order by table_name;
 table_name | trigger_schema | trigger_name | event | action_timing | condition 
------------+----------------+--------------+-------+---------------+-----------
(0 rows)

/* FUNCTIONAL TESTS FOR THE EXTENSION

PREPARATION: create the table for `other_state' to provide difference

*/
CREATE SCHEMA other_state;
create table if not exists other_state.test_reconsile(a int, b text, g int);
-- test if output from ext. will make `deploy_test' equal with `other_state'
SELECT * FROM deploy_test.reconsile_desired(
                              text 'deploy_test', -- original
                              text 'other_state', -- schema
                              text 'test_reconsile');
                    reconsile_desired                     
----------------------------------------------------------
 ALTER TABLE deploy_test.test_reconsile ADD COLUMN g int;
 ALTER TABLE deploy_test.test_reconsile DROP COLUMN c;
 ALTER TABLE deploy_test.test_reconsile DROP COLUMN d;
 ALTER TABLE deploy_test.test_reconsile DROP COLUMN e;
(4 rows)

-- CLEAN UP
DROP extension deploy_test cascade;
ROLLBACK;