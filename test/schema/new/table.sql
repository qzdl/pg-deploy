CREATE TABLE staying_alive.first_i_was_afraid (
  a int constraint hmm check (a > 5),
  b text,
  c bool default true constraint yep check (c = true)
);
