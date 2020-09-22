
EXTENSION = pgdeploy
EXTVERSION = 0.0.1
PGUSER	= postgres

TESTS = $(wildcard test/sql/*.sql)
REGRESS = $(patsubst test/sql/%.sql,%,$(TESTS))
REGRESS_OPTS = --inputdir=test --load-language=plpgsql


all: $(EXTENSION)--$(EXTVERSION).sql

$(EXTENSION)--$(EXTVERSION).sql	:	src/reconcile_schema.sql $(sort $(filter-out $(wildcard src/reconcile_schema.sql),$(wildcard src/*.sql)))
	cat $^ > $@
DATA = $(EXTENSION)--$(EXTVERSION).sql
EXTRA_CLEAN = $(EXTENSION)--$(EXTVERSION).sql



PG_CONFIG = pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)
