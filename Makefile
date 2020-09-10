
EXTENSION = pgdeploy
EXTVERSION = 0.0.1
PGUSER	= postgres
PG_CONFIG = pg_config

#DATA = $(wildcard sql/*.sql)

# REGRESS = regression_tests
all: $(EXTENSION)--$(EXTVERSION).sql
	
$(EXTENSION)--$(EXTVERSION).sql	:	sql/reconcile_schema.sql $(sort $(filter-out $(wildcard sql/reconcile_schema.sql),$(wildcard sql/*.sql)))
	cat $^ > $@
DATA = $(EXTENSION)--$(EXTVERSION).sql
EXTRA_CLEAN = $(EXTENSION)--$(EXTVERSION).sql

PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)
