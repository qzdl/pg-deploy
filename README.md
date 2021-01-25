# `pgdeploy`
> A PostgreSQL extension for maintaining database schemata with sql generation.

![](https://www.gnu.org/graphics/gplv3-with-text-136x68.png)

<!-- markdown-toc start - Don't edit this section. Run M-x markdown-toc-refresh-toc -->
**Table of Contents**

- [`pgdeploy`](#pgdeploy)
    - [Advantages](#advantages)
    - [How it works](#how-it-works)
    - [Caveats / Limitations](#caveats--limitations)
    - [Installation](#installation)
    - [Usage & Examples](#usage--examples)
        - [pgdeploy CLI](#pgdeploy-cli)
        - [Clean Database Workflow](#clean-database-workflow)
            - [Preparation](#preparation)
        - [Working Database Workflow](#working-database-workflow)
        - [First commit](#first-commit)
        - [Further changes and rollbacks](#further-changes-and-rollbacks)
    - [For Developers](#for-developers)
        - [Testing](#testing)
        - [Integration tests](#integration-tests)
    - [Troubleshooting](#troubleshooting)
        - [`installcheck`: `psql: FATAL:  role "root" does not exist`](#installcheck-psql-fatal--role-root-does-not-exist)
        - [`installcheck`: `psql: FATAL:  Peer authentication failed for user "<USER>"`](#installcheck-psql-fatal--peer-authentication-failed-for-user-user)
        - [`installcheck`: tests failing](#installcheck-tests-failing)
    - [[TODO](./TODO)](#todotodo)
    - [LICENSE](#license)
        - [file header licence info](#file-header-licence-info)
        - [CLI license info](#cli-license-info)

<!-- markdown-toc end -->

## Advantages

- Benefits of git
  - Proper version control with rollback,
  - Deployment by commit, by tag or as your semantic versioning scheme requires,
  - Tests, deployment can be triggered by git hook etc,
  - Branches for different scenarios (archive, production system etc., where
    minor changes may be present),
  - git hooks,
  - history,
  - etc.
- Single source of truth for all declarations and changes to schemata in a
  repository
- Using the database for generating the code for depoyment means syntax and
  reference check for the schema
- Easy integration to your own automated testing pipeline for the generated restore
  code, hooks, and so on.

## How it works

The definitions of database objects describe the **state** of the database, with
regard its structure. This state can be expressed as a set of CREATE statements.

A change in this definition results in a new state, which is also a set of
create statements. We can establish the differences between the two states with
the help of the PostgreSQL catalog tables, and we can generate SQL code that can
transform one state into an other.

In other words, if we create a schema using the current state - new_schema - and
using the previous state - old_schema - in a running database, then we can
calculate the way of transforming one state into the other. The main function of
the extension - [`reconcile_schema.sql`](./src/reconcile_schema.sql) does exactly this; it
calculates the differences between the set of objects in each schema, and
generates the relevant transforming `SQL` code.

The code generation is based on the differences between objects, regardless if
that is a new commit or a rollback, only the direction of transformation must be
given.

For instance, if the *target* schema has a new table, then the `CREATE TABLE`
declaration must be calculated for the *source* schema. If we were to reverse
the direction, there would a DROP statement that removes the stale table.

To test the generated code, simply apply the generated code to the original
database schemam, then call the comparison function of the pgdeploy extension.
The result should be 'empty' - a text without any SQL commands - after applying
the changes to the source state, the object should be transformed into the
target state; there should be no difference.

After proving the generated code further, commands can be added to it before
deployment - eg. rebuilding indices, vacuuming etc.


## Caveats / Limitations
- Base types are not supported
- chain renaming is rollback boundary:
    if object A is renamed as B, B is renamed as C and a new A is made in
    subsequent changes, it is impossible to restore the initial state. If that
    is a table, it is not possible to decide if it is a new table or a renamed
    old one. With other words: RENAMEing objects is not encouraged.
- runtime errors are not checked:
    Procedures/functions must have unit tests.
- dyamically created tables shall not be part of the schema definition:
    dynamically created tables are accidental for the particular database and
    not consistent across databases. Such tables are table partitions or tables
    with time stamps generated dynamically. Be aware if such tables are included
    statically in your schema definition.


## Installation

Installation of the extension follows the standard Postgres extension install
process.

The server will not require a restart after install.

The procedure relies on `gmake`, with tests through `installcheck` managed by
environment variables, as seen below.

For a full list of environment variables relevant to PG, refer the official
[docs](https://www.postgresql.org/docs/current/libpq-envars.html)

Make the extension available for the instance, generate
[results/deploy<sub>test.out</sub>](results/deploy_test.out) with the following
commands &#x2013; and be sure to prepend `sudo` if the installation is not
governed by the executing user.

    make install
    make installcheck -e PGPORT=YOUR_PG_PORT -e PGUSER=YOUR_PG_USER -e OTHERVAR=READ_THE_DOCS

## Usage & Examples

*clean database* refers to the targeting of clean / static / discrete 'states',
from git / filesystem / etc; the sort of deterministic, knowable execution
context to run in a CI/CD pipeline.

Some examples are given for the described workflow, from test data,
demonstrating the sort of functionality that can be achieved.

__TLDR; Examples__:
- [`example/clean-workflow--files`](./example/clean-workflow--files)
- [`example/clean-workflow--git`](./example/clean-workflow--git)
- [`example/running-workflow--files`](./example/running-workflow--files)
- [`example/running-workflow--git`](./example/running-workflow--git)
- [`example/running-workflow--ALL-YOUR-SCHEMA-ARE-MINE`](./example/running-workflow--ALL-YOUR-SCHEMA-ARE-MINE)

### pgdeploy CLI
### Clean Database Workflow

> [...] target clean / static / discrete 'states', from git / filesystem / etc;
> the sort of deterministic, knowable execution context to run in a CI/CD
> pipeline.

Some examples are given for the described workflow, from test data,
demonstrating the sort of functionality that can be achieved
- [`example/clean-workflow--files`](./example/clean-workflow--files)
  - showing a bash pipeline for DB creation, schema loading, pgdeploy execution
    & output file generation
- [`example/clean-workflow--git`](./example/clean-workflow--git)



#### Preparation
- Prepare reference database. This database will be used to calculate the
  differences between the states (commits) but shall not have any user schema
  defined. (Must be blank)
- Install the extension
- Set the proper permissions, so that the user who connects to the database in
  the context of this extension can create schema.
- Create the extension for the database `CREATE EXTENSION pgdeploy;`


### Working Database Workflow
### First commit
- Create a git repository for your object declarations (tables, procedures,
  etc.), that you want to keep in the version control system.
- Write the schema declaration, or in case of a live/development system,
  `pg_dump` the schema sql in to the repository so that you can restore it.
- Modify the sql declaration according to your needs and make the inital repo
  commit.

### Further changes and rollbacks

- Make your source code changes.
  - Any change in the object definitions are simply modifications of the
    definition. Any object deletion is a deletion in the schema file.
- Load in the schemata
  - To prepare the reference database so, that your target state goes into one
    schema and the current goes into an other.
- Call the extension's main function.
  - If the reconciliation is successful, the return value is an SQL file that
    can be used to create the state transition.
- Test the code
  - As the source and target schema must exist on the reference database that is
    used by the extension, modify the code so, that you can apply it to the
    source schema in the reference database. Call the reconcile function to
    calculate the differences again. The result should be text without any SQL
    executable code in it.
- Add your custom changes
  - eg. vacuum, index rebuild, statistics, etc. Deploy the code in your system.




## For Developers
### Testing
The extension has standard PostgreSQL unit tests.

### Integration tests
The integration tests simulate a real environment and the workflow.

- The preparatory steps are as described in the Usage section for end users.
- The two states used for development are the
  [`integration_tests/source.sql`](./integration_tests/source.sql) and
  [`integration_tests/target.sql`](./integration_tests/target.sql) files. These
  files serve for testing and to be modified only when new test case or edge
  case is implemented.
- The developer executes the helper script integration_tests/transform.sh in
  order to get his test results. For details see the transform.sh file.


NOTE: If structural changes against the **current** version exist in the
      database, it should be possible to write the version held by the extension
      to a new schema that is not owned by the extension. From here, the process
      above can be followed to get a new baseline.


## Troubleshooting
### `installcheck`: `psql: FATAL:  role "root" does not exist`
By default, the user/role mapping will be used when attempting to establish a
connection to the target database.

If `installcheck` has been run as `sudo make installcheck`, then the associated
`PGUSER` that will be attempted with login will be `root`, which is not
typically set up on the database server.

To fix, supply the `PGUSER` environment variable to `make` with the `-e` option:

    sudo make installcheck -e PGUSER='<user>'


### `installcheck`: `psql: FATAL:  Peer authentication failed for user "<USER>"`

This error will likely arise when running `make installcheck` with supplying
environment variable `PGUSER`. The fix for this depends on the authentication
configuration of the target instance:

- ascertain how authentication is configured by finding `pg_hba.conf`; this
  can generally be found at `/etc/postgresql/<VERSION>/main/pg_hba.conf`;
  replace `<VERSION>` with the applicable version
- so, either:
  - change local login (first entry) from `peer` to `md5` or any other relevant
    auth method:
    - `md5` allows for password auth from the user&rsquo;s UNIX login
    - `trust` will just allow any arbitrary local connections
  - check your environment variables to `make installcheck`, and adjust the
    parameters given to suit your auth config; e.g. `PGPASSWORD` as the
    substitute for the connection parameter for `password`
- if necessary, reload the server to apply the auth changes
        /etc/init.d/postgresql reload # or however you trigger a restart
- in any case, [RTFM for environment variables](https://www.postgresql.org/docs/current/libpq-envars.html)

Some useful links for troubleshooting this process:

-   [PostgreSQL: Documentation: 12: 20.3. Authentication Methods](https://www.postgresql.org/docs/12/auth-methods.html)
-   [postgresql - Getting error: Peer authentication failed for user 'postgres'](https://stackoverflow.com/questions/18664074/getting-error-peer-authentication-failed-for-user-postgres-when-trying-to-ge)




### `installcheck`: tests failing
- Check `test/expected/`; this directory contains a set of output files that
yield a pass/fail, when `diff`ed with the output of the set of `test/sql/`
  - if this directory is blank, check the root of the repo for a directory
    `results` (the output of `installcheck`), and copy to `expected`:

        cp -a ./results/* ./test/expected/


## [TODO](./TODO)
See file [TODO](./TODO)

## [LICENSE][https://opensource.org/licenses/postgresql]

Copyright (c) 2020, ThinkProject! GmbH.

Permission to use, copy, modify, and distribute this software and its documentation for any purpose, without fee, and without a written agreement is hereby granted, provided that the above copyright notice and this paragraph and the following two paragraphs appear in all copies.

IN NO EVENT SHALL ThinkProject! GmbH. BE LIABLE TO ANY PARTY FOR DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES, INCLUDING LOST PROFITS, ARISING OUT OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION, EVEN IF $ORGANISATION HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

ThinkProject! GmbH. SPECIFICALLY DISCLAIMS ANY WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE SOFTWARE PROVIDED HEREUNDER IS ON AN "AS IS" BASIS, AND ThinkProject! GmbH. HAS NO OBLIGATIONS TO PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR MODIFICATIONS.
