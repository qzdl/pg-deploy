# Authors:
Culpepper, Samuel
Laszlo, Forro
# pg-deploy: a framework to facilitate Postgres deployment based on revision control system

The deployment of database changes means usually deployment of SQL commands that change the state of the database schema ( see  [Microsoft Azure best practices](https://docs.microsoft.com/en-us/azure/postgresql/application-best-practices#database-deployment),or tools like [Flyway](https://www.baeldung.com/database-migrations-with-flyway) with their own special syntax, terminology and workflow). The obvious disadvantage of these method is that the state of the database is not easy to track if the changes are different ALTER and DROP commands, besides CREATE statements.
On the other hand extension in the database there are only states declared, that can be described by sequences of CREATE statements. Tracking commands like DROP and ALTER do not show the final state of the database - these commands modify the state of the database, but they do not describe the state.
pg-deploy does one thing: It creates a transformation code taking two database schema declarations. If it is combined with git where only the state if the schema is described, we end up with a robust way to track all the changes in the database.  Let's take an example of two states of the same table:

```sql
CREATE TABLE A( a INT );
```
and 

```sql
CREATE TABLE A( a INT, b INT);
```
Obviously to transform the first to the second we need to
```sql 
ALTER TABLE A CREATE COLUMN b int;
```
while from the second to the first we need to 
```sql 
ALTER TABLE A DROP COLUMN b;
```
That is exaclty that pg-deploy does for us. We need to upload two schemas into the database and it returns a code that alters one schema to the other. If we combine this functionality with a git repository for the schema declarations and the proper workflow we end up using a very transparent and robust way to maintain database schemata. 
So, let's put all the object declarations of the schema in a git repository. Say, the first commit is our 
```sql 
CREATE TABLE A(a INT);
```
statement.
Now, in the next commmit we want to add column b. How to do it? Instead of writing an ALTER statement, we can simply change the CREATE declaration of the table adding the new column.
```sql
CREATE TABLE A( a INT, b INT);
```
So, this commit shows the declaration of the database as we now want to have, but we can not deploy it. The table already exists in the database. We need a code that transforms the first state to the second one. Here where pg-deploy comes to play. We can load the first commit into the database and rename the schema. then we can load the second commit to the database and call pg-deploy's reconcile() procedure that generates the transformation code:
```sql 
ALTER TABLE A CREATE COLUMN b(int);
```
This can be deployed to the databases. Our git repository contains still only declarations and the transformation code, that leads from the previous state to the new one. 
The advantage of using git is huge. Git helps to document all the changes, offers hooks to trigger tests, different branches can be made for different scenarios - eg. different db versions -, and the transition between branches can also be generated once one scenario is obsolete. Earlier states can be branched and merged, various workflows can be implemented using bash or other languages of choice. The schema declaration can be broken down to different files that are easier to maintain. Loading the files into the database means that the database does its syntactic checks. An this all can be achieved in the familiar environment of git, some scripting language and the PostgreSQL database. ( for further details see a [template repository with a use-case]() ).
One further use case of pg-deploy that it can compare any arbitrary schema declarations. If over the time the database state and what is known about the database diverges, pg-deploy can also be used to compare what is expected to exist and what actually does. The schema can be dumped from the database and compared to the expected sql declaration. The result is the transformation sql file, that also indicates the differences between the expected and the is.

