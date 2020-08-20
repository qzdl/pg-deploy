
EXTENSION = pg_deploy
DATA = pg_deploy--0.0.1.sql
REGRESS = pg_deploy

# postgres build stuff
PG_CONFIG = pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)
