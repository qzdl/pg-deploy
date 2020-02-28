
EXTENSION = deploy_test
DATA = deploy_test--0.0.1.sql
REGRESS = deploy_test

# postgres build stuff
PG_CONFIG = pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)
