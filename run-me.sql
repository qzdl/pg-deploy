 -- LEFT and RIGHT of 'first_i_was_afraid' are equal
 ALTER TABLE staying_alive.first_i_was_afraid ADD COLUMN hey_git text DEFAULT 'git git gitty git git'::text NOT NULL;
 -- COLUMN: no change for a
 -- COLUMN: no change for b
 -- COLUMN: no change for c
 ALTER TABLE staying_alive.first_i_was_afraid DROP CONSTRAINT IF EXISTS yep;
 -- CONSTRAINT: LEFT and RIGHT of 'hmm CHECK ((a > 5))' are equal

