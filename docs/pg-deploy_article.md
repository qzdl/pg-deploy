# Authors:
Culpepper, Samuel;
Laszlo, Forro
# pg-deploy: a framework to facilitate PostgreSQL deployment based on revision control system

The deployment of database changes usually requires the deployment of SQL
commands that change the state of the database schema (see [Microsoft Azure best practices](https://docs.microsoft.com/en-us/azure/postgresql/application-best-practices#database-deployment), 
or tools like [Flyway](https://www.baeldung.com/database-migrations-with-flyway) with their
own special syntax, terminology and workflow). 

The obvious disadvantage of these methods is that the state of the database is
not easy to track over time, given a disparate collection of `CREATE`, `ALTER`
and `DROP` statements - the sum total of which represent all objects and their
behaviour inside the database.

On the other hand, for extensions in the database, there are only states
declared, that can be described by sequences of CREATE statements. Tracking
commands like DROP and ALTER do not show the final state of the database - these
commands modify the state of the database, but they do not describe the state.

The workflow of pg-deploy requires a locally running PostgreSQL database, where
the user has right to create databases and schemas

The Python tool [migra](https://github.com/djrobstep/migra) is similar to
pg-deploy. It creates a transformation code taking two database schema
declarations. 

The difference between pg-deploy and migra is that migra is based on the Python
[schemainspect](https://pypi.org/project/schemahq-schemainspect/) library - it
reads the schema definitions from the running database, builds a Python object
and compares the objects in the migra code. `pg-deploy` compares the schemata in
the database, using the system tables, and the functionality can be extended
without any change of an external library.

Migra compares databases - pg-deploy compares schemata - but our workflow can be
extended to incorporate more schemata.

pg-deploy can be combined with git, where only the state of the schema is
described, meaning we end up with a robust way to track all the changes in the
database, in terms of the 'end' states of the objects.

Let's take an example of two such 'end' states of the same table:

```sql
-- source state
CREATE TABLE ( a INT );
```
and
```sql
-- target state
CREATE TABLE A( a INT, b INT);
```
to transform the 'source' to the 'target', we need to
```sql
ALTER TABLE A CREATE COLUMN b int;
```
whereas, from target to source:
```sql
ALTER TABLE A DROP COLUMN b;
```

This is exactly the role pg-deploy fills. We need to upload two schemas into the
database, and it returns code that with the appropriate `ALTER`s to transitio
from one schema to the other.

If we combine this functionality with a git repository for the schema
declarations and the proper workflow we end up using a very transparent and
robust way to maintain database schemata. So, let's put all the object
declarations of the schema in a git repository.

Say, the inital commit is our 'source' state:
```sql
CREATE TABLE A(a INT);
```

Now, in the next commmit we want to `ADD COLUMN b` - instead of writing an
`ALTER` statement, we can simply change the `CREATE` declaration of the table
adding the new column:

```sql
CREATE TABLE A( a INT, b INT);
```

So, this second commit shows the declaration of the database as we want it now.

Put in the context of a running database, the table `A` already exists; We need
code that transforms the first state to the second one. Enter `pg-deploy`.

Load the first commit into the database, rename the schema, load the second
commit, invoke `pg-deploy`; the `reconcile_schema()` procedure will proceed to
generate the transformation code:

```sql
ALTER TABLE A CREATE COLUMN b(int);
```

This now can be checked, and deployed to the application database.

Our git repository contains still only declarations and the transformation code,
that leads from the previous state to the new one.

The advantage of using git is huge. Git helps to document all the changes,
offers hooks to trigger tests, different branches can be made for different
scenarios - eg. different db versions - and the transition between branches can
also be generated once one scenario is obsolete.

Earlier states can be branched and merged, various workflows can be implemented
using bash or other orchestration / pipeline tools such as luigi, airflow, etc.
The schema declaration can be broken down to different files that are easier to
maintain. Loading the files into the database means that the database does its
syntactic checks. There is no cerebral change required in the development
process; all of this can be achieved in the familiar environment of git, some
scripting language and the PostgreSQL database. (for further details see a
[template repository with a use-case](TODO)).

The transformation is calculated between the 'source' schema and the 'target'
schema. The source schema is loaded into the database and RENAME-d, so the
target schema can also be loaded.

A serendipitous benefit of the pg-deploy architecture is that any two arbitrary
objects can be DIFFed - the aforementioned `reconcile_schema()` procedure is
an aggregation of object-type specific functions, `reconcile_relation()`,
`reconcile_index()`, and so on.

If over time the database state, and what is known about the database diverges,
pg-deploy can also be used to compare what is expected to exist and what
actually does.

The schema can be dumped from the database and compared to the expected sql
declaration. The result is the transformation sql file, which indicates the
differences between the existing state, and the expected.


## TODO: Make a GIF of calculating schema state differences in bash
## TODO: Make a GIF of calculating state differences in psql repl
