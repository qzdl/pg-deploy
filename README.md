
# Table of Contents

1.  [`DEPLOY_TEST`](#org3349ebe)
    1.  [Workflow](#org4edd640)
        1.  [Extension Install](#org1c2ba86)
    2.  [Usage](#org7a947c4)
    3.  [Deploy/Rollback](#org1c4e810)
    4.  [Project Structure](#org4976d81)
        1.  [sql/](#org792469d)
        2.  [expected/](#org47dbd8c)
    5.  [Troubleshooting](#orgb632576)
        1.  [`installcheck`: `psql: FATAL:  role "root" does not exist`](#org990955a)
        2.  [`installcheck`: `psql: FATAL:  Peer authentication failed for user "<USER>"`](#org96835ff)



<a id="org3349ebe"></a>

# `DEPLOY_TEST`

A proof-of-concept Postgres extension for maintaining database schemata, as an
extension.

The general process of taking the objects in a database to a new version

Advantages:

-   Proper version control
    -   Deployment by commit, or by tag; e.g. hotfix
    -   Flexible to the semantic versioning scheme relevant to the project.
-   Code generation based on the differences between objects
    -   This applies for rollback, between versions, or arbitary &rsquo;dirty&rsquo; states
        (e.g at development time)
    -   catalog tables contian the necessary information to &rsquo;diff&rsquo;
-   Single source of truth for all declarations and changes to schemata.
-   Automatic test generation for functional, structural, etc tests; using standard
    Postgres test framework.
-   Can be deployed and used on local instances and production instances alike.
-   Tests can be triggered by git hook.


<a id="org4edd640"></a>

## Workflow


<a id="org1c2ba86"></a>

### Extension Install

Installation of the extension follows the standard Postgres Extension install process.

The server will not require a restart after install.

The procedure relies on `gmake`, with tests through `installcheck` managed by
environment variables, as seen below.

For a full list of environment variables relevant to PG, refer the official [docs](https://www.postgresql.org/docs/current/libpq-envars.html)

Make the extension available for the instance, generate [results/deploy<sub>test.out</sub>](results/deploy_test.out)
with the following commands &#x2013; and be sure to prepend `sudo` if the installation is
not governed by the executing user.

    make install
    make installcheck -e PGPORT=YOUR_PG_PORT -e PGUSER=YOUR_PG_USER -e OTHERVAR=READ_THE_DOCS


<a id="org7a947c4"></a>

## Usage

Prepare reference database (all changesets & scripts applied, etc).

Dump the current state of the database; this is the base for the initial commit.

-   The `--clean` option to `pg_dump` will generate a `DROP` statement for each
    object:

    pg_dump --host localhost --port 8432 --dbname "something" --user postgres \
      --schema-only --no-owner --no-privileges  --clean --if-exists \
      | sed -e 's/CREATE TABLE/CREATE TABLE IF NOT EXISTS/g' \
      | grep -v DROP.TABLE > initial-commit-source.sql

-   Adjust the newly created [initial-commit-source.sql](initial-commit-source.sql) according to your needs.

-   Create the test suite in [sql/](sql/) as demonstrated.

-   Run the tests, with copy step to expected
    
        make install
        make installcheck -e PGPORT=YOUR_PG_PORT -e PGUSER=YOUR_PG_USER -e OTHERVAR=READ_THE_DOCS
        cp results/deploy_test.out expected/deploy_test.out
        make installcheck -e PGPORT=YOUR_PG_PORT -e PGUSER=YOUR_PG_USER -e OTHERVAR=READ_THE_DOCS

-   Save the state (e.g. git commit / tag) if tests pass.

NOTE: If structural changes against the **current** version exist in the database,
      it should be possible to write the version held by the extension to a new
      schema that is not owned by the extension. From here, the process above
      can be followed to get a new baseline.


<a id="org1c4e810"></a>

## TODO Deploy/Rollback

The procedure


<a id="org4976d81"></a>

## TODO Project Structure


<a id="org792469d"></a>

### [sql/](sql/)

This directory holds the sql scripts that generate the output for


<a id="org47dbd8c"></a>

### TODO [expected/](expected/)


<a id="orgb632576"></a>

## Troubleshooting


<a id="org990955a"></a>

### `installcheck`: `psql: FATAL:  role "root" does not exist`

By default, the user/role mapping will be used when attempting to establish a
connection to the target database.

If `installcheck` has been run as `sudo make installcheck`, then the associated
`PGUSER` that will be attempted with login will be `root`, which is not
typically set up on the database server.

To fix, supply the `PGUSER` environment variable to `make` with the `-e` option:

    sudo make installcheck -e PGUSER='<user>'

If you get an error regarding peer authentication, refer [1.5.2](#org96835ff)


<a id="org96835ff"></a>

### `installcheck`: `psql: FATAL:  Peer authentication failed for user "<USER>"`

This error will likely arise when running `make installcheck` with supplying
environment variable `PGUSER`.

The fix for this depends on the authentication configuration of the target instance;

-   ascertain how authentication is configured by finding `pg_hba.conf` &#x2013; this
    can generally be found at `/etc/postgresql/<VERSION>/main/pg_hba.conf`;
    replace `<VERSION>` with the applicable version
-   either:
    -   change `peer` to `md5` or any other relevant auth method; `md5` allows for
        pass-through auth from the user&rsquo;s UNIX login
    -   check your environment variables to `make installlcheck`, and adjust the
        parameters given to suit your auth config; e.g. `PGPASSWORD` as the
        substitute for the connection parameter for `password`
-   in any case, [RTFM](https://www.postgresql.org/docs/current/libpq-envars.html)

Some useful links for troubleshooting this process:

-   [PostgreSQL: Documentation: 12: 20.3. Authentication Methods](https://www.postgresql.org/docs/12/auth-methods.html)
-   [postgresql - Getting error: Peer authentication failed for user &ldquo;postgres&rdquo;, w&#x2026;](https://stackoverflow.com/questions/18664074/getting-error-peer-authentication-failed-for-user-postgres-when-trying-to-ge)

