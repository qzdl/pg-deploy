 DROP TABLE IF EXISTS staying_alive.i_was_petrified;
 -- LEFT and RIGHT of 'first_i_was_afraid' are equal
 ALTER TABLE staying_alive.first_i_was_afraid ADD COLUMN b text NULL;
 ALTER TABLE staying_alive.first_i_was_afraid ADD COLUMN c boolean DEFAULT true NULL;
 -- COLUMN: no change for a
 ALTER TABLE staying_alive.first_i_was_afraid ADD CONSTRAINT hmm CHECK ((a > 5));
 ALTER TABLE staying_alive.first_i_was_afraid ADD CONSTRAINT yep CHECK ((c = true));
 ALTER TABLE staying_alive.first_i_was_afraid DROP CONSTRAINT IF EXISTS first_i_was_afraid_a_check;

