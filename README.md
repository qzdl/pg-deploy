
# Table of Contents

1.  [`DEPLOY_TEST`](#org757db1b)
    1.  [Workflow](#org30bf2dc)
        1.  [Extension Install](#org82aaf99)
    2.  [Usage](#orga57ddd9)
    3.  [Deploy/Rollback](#org9d415b0)
    4.  [Project Structure](#org9c1e0fe)
        1.  [sql/](#org6513172)
        2.  [expected/](#orga8d4880)
    5.  [Troubleshooting](#org55c182b)
        1.  [`installcheck`: `psql: FATAL:  role "root" does not exist`](#orge6f3ef8)
        2.  [`installcheck`: `psql: FATAL:  Peer authentication failed for user "<USER>"`](#org1e98693)



<a id="org757db1b"></a>

# `DEPLOY_TEST`

Postgres extension for maintaining database schemata using git.


Advantages:

-  Benefits of git
    - Proper version control with rollback
    - Deployment by commit, by tag or as your semantic versioning scheme requires
    - Tests, deployment can be triggered by git hook etc
-   Single source of truth for all declarations and changes to schemata
-   Automatic test generation for functional, structural, etc tests; using standard
    Postgres test framework.

How it works - some theory:

The definition of the database object describe the state of the database in regard its structure. This state is defined by
a set of CREATE statements. A change in this definition results in a new state, that is also a set
of create statements. We can establish the differences between the two states with the help of the
PostgreSQL catalog tables and we can generate SQL code that can transform one state into an other.
With other workd: if we create a schema using the current state - new_schema - and using the previous
state - old_schema - in a running database. Then the main function of the extension calculates the
differences between the two schemas and generates an SQL code. This code can transform old_schema
into the new_schema. The code generation based on the differences between objects, regardless if that is a new commit
or a rollback, only the direction of transformation must be defined:
If the new_schema has a new table then the table declaration must be calculated and applied to the old_schema.
The other direction would be a DROP statement that removes the excess table.

<a id="org30bf2dc"></a>

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

*usr/lib/postgresql/10/lib/pgxs/src/makefiles*../../src/test/regress/pg<sub>regress</sub> &#x2013;inputdir=./ &#x2013;bindir=&rsquo;/usr/lib/postgresql/10/bin&rsquo;    &#x2013;dbname=contrib<sub>regression</sub> deploy<sub>test</sub>
(using postmaster on Unix socket, default port)
`============` dropping database &ldquo;contrib<sub>regression</sub>&rdquo; `============`
NOTICE:  database &ldquo;contrib<sub>regression</sub>&rdquo; does not exist, skipping
DROP DATABASE
`============` creating database &ldquo;contrib<sub>regression</sub>&rdquo; `============`
CREATE DATABASE
ALTER DATABASE
`============` running regression test queries        `============`
test deploy<sub>test</sub>              &#x2026; ok

`===================`
 All 1 tests passed.
`===================`


<a id="orga57ddd9"></a>

## Workflow


<a id="org82aaf99"></a>

## Usage

### Preparation

-   Install the extension
-   Prepare reference database. This database will be used to calculate the differences between the states (commits)
-   Set the proper permissions, so that the user who connects to the database can create schema.

### First commit

-   Create a git repository for your object declarations (tables, procedures, ect.)
    , that you want to keep in the version controll system.
-   pg_dump the schema so that you can restore it.
-   Use this dump as the base of your initial commit, adjust it according to your needs.
-   Make the initial commit.
-   Any change in the object definitions are simply modifications of the definition as if the object would be newly created.
    Any object deletion is a deletion in the file.




## For Developers

-   
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


<a id="org9d415b0"></a>

## TODO Deploy/Rollback

Same as with a new commit. Do your rollback in your repository and generate the delta file to deploy.


<a id="org9c1e0fe"></a>

### SHORTER
## TODO Project Structure


<a id="org6513172"></a>

### [sql/](sql/)

This directory holds the sql scripts that generate the output for


<a id="orga8d4880"></a>

### TODO [expected/](expected/)


<a id="org55c182b"></a>

###

## Troubleshooting during installation


<a id="orge6f3ef8"></a>

### `installcheck`: `psql: FATAL:  role "root" does not exist`

By default, the user/role mapping will be used when attempting to establish a
connection to the target database.

If `installcheck` has been run as `sudo make installcheck`, then the associated
`PGUSER` that will be attempted with login will be `root`, which is not
typically set up on the database server.

To fix, supply the `PGUSER` environment variable to `make` with the `-e` option:

    sudo make installcheck -e PGUSER='<user>'

If you get an error regarding peer authentication, refer [1.5.2](#org1e98693)


<a id="org1e98693"></a>

### `installcheck`: `psql: FATAL:  Peer authentication failed for user "<USER>"`

This error will likely arise when running `make installcheck` with supplying
environment variable `PGUSER`.
The fix for this depends on the authentication configuration of the target instance;

-   ascertain how authentication is configured by finding `pg_hba.conf` &#x2013; this
    can generally be found at `/etc/postgresql/<VERSION>/main/pg_hba.conf`;
    replace `<VERSION>` with the applicable version
-   so, either:
    -   change local login (first entry) from `peer` to `md5` or any other relevant
        auth method;
        -   `md5` allows for password auth from the user&rsquo;s UNIX login
        -   `trust` will just allow any arbitrary local connections

    -   check your environment variables to `make installlcheck`, and adjust the
        parameters given to suit your auth config; e.g. `PGPASSWORD` as the
        substitute for the connection parameter for `password`
-   if necessary, reload the server to apply the auth changes with the following
    command

        /etc/init.d/postgresql reload
-   in any case, [RTFM](https://www.postgresql.org/docs/current/libpq-envars.html)

Some useful links for troubleshooting this process:

-   [PostgreSQL: Documentation: 12: 20.3. Authentication Methods](https://www.postgresql.org/docs/12/auth-methods.html)
-   [postgresql - Getting error: Peer authentication failed for user &ldquo;postgres&rdquo;, w&#x2026;](https://stackoverflow.com/questions/18664074/getting-error-peer-authentication-failed-for-user-postgres-when-trying-to-ge)
