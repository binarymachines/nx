##
## Makefile for New World Oracle data pipelines / utility routines
##


#_______________________________________________________________________
#
# 
#_______________________________________________________________________
#


#_______________________________________________________________________
#
# Utility targets
#_______________________________________________________________________
#

init-dirs:
	cat required_dirs.txt | xargs mkdir -p


clean:
	rm -rf temp_data/*
	rm -f temp_scripts/*
	rm -rf logs/*
	

db-up:
	docker compose up -d


db-down:
	docker compose down


dblogin:
	psql -U user --port=15433 --host=localhost -W


dbalogin:
	psql -U nxdba --port=15433 --host=localhost -w -d nxdb


docker-login:
	$(eval CONTAINER_ID=$(shell docker ps |grep postgres | grep alpine | awk '{ print $$1 }'))
	
	docker exec -ti $(CONTAINER_ID) /bin/bash


#_______________________________________________________________________
#
# SQL generators
#_______________________________________________________________________
#
#
gen-dba-script:
	warp --py --template-file=template_files/mkdbauser.sql.tpl \
	--params=role:nxdba,description:Administrator,pw:$$NX_PG_PASSWORD,db_name:nxdb \
	> temp_sql/create_dba_role.sql


gen-db-script: 
	warp --py --template-file=template_files/mkdb.sql.tpl --params=db_name:nxdb \
	> temp_sql/create_db.sql


gen-perm-script:
	warp --py --template-file=template_files/perms.sql.tpl --params=db_name:nxdb,role:nxdba \
	> temp_sql/set_perms.sql


db-create-database:
	psql -U user --port=15433 --host=localhost -w -f temp_sql/create_db.sql


db-create-dbauser:
	psql -U user --port=15433 --host=localhost  -w -f temp_sql/create_dba_role.sql


db-set-perms:
	psql -U user --port=15433 --host=localhost  -w -f temp_sql/set_perms.sql


db-purge-dimensions:
	psql -U nxdba --port=15433 --host=localhost -d nxdb -w -f sql/truncate_dimension_tables.sql


db-create-tables:	
	export PGPASSWORD=$$NX_PG_PASSWORD && psql -U nxdba --port=15433 --host=localhost -d nxdb -w -f sql/db_extensions.sql
	export PGPASSWORD=$$NX_PG_PASSWORD && psql -U nxdba --port=15433 --host=localhost -d nxdb -w -f sql/nx_ddl.sql


db-generate-dim-data:
	cat /dev/null > temp_sql/dimension_data.sql

	dgenr8 --plugin-module dim_day_generator --sql --schema public --dim-table dim_date_day --columns id value label \
	>> temp_sql/dimension_data.sql

	dgenr8 --plugin-module dim_month_generator --sql --schema public --dim-table dim_date_month --columns id value label \
	>> temp_sql/dimension_data.sql
	
	dgenr8 --plugin-module dim_year_generator --sql --schema public --dim-table dim_date_year --columns id value label \
	>> temp_sql/dimension_data.sql

	dgenr8 --plugin-module dim_minute_generator --sql --schema public --dim-table dim_time_minute --columns id value label \
	>> temp_sql/dimension_data.sql

	dgenr8 --plugin-module dim_hour_generator --sql --schema public --dim-table dim_time_hour --columns id value label \
	>> temp_sql/dimension_data.sql

	dgenr8 --plugin-module dim_value_bin_generator --sql --schema public --dim-table dim_xposts_bin --columns id value label \
	>> temp_sql/dimension_data.sql

	dgenr8 --plugin-module dim_value_bin_generator --sql --schema public --dim-table dim_comments_bin --columns id value label \
	>> temp_sql/dimension_data.sql

	dgenr8 --plugin-module dim_value_bin_generator --sql --schema public --dim-table dim_upvotes_bin --columns id value label \
	>> temp_sql/dimension_data.sql


db-populate-dimensions:
	psql -U nxdba --port=15433 --host=localhost -w -d nxdb -f temp_sql/dimension_data.sql
	

db-init: gen-db-script gen-dba-script gen-perm-script db-create-database db-create-dbauser db-set-perms db-create-tables


db-prepopulate: db-purge-dimensions db-generate-dim-data db-populate-dimensions


#_______________________________________________________________________
#
# Pipeline targets
#_______________________________________________________________________
#

pipeline-ingest-mongo:
	cat static_data/reddit_submissions.jsonl \
	| ngst --config config/ingest_reddit_data.yaml --target mongodb > temp_data/raw_post_records.jsonl
	 

pipeline-ingest-pg:
	cat temp_data/raw_post_records.jsonl \
	| ngst --config config/ingest_reddit_data.yaml --target sqldb --params=record_type:reddit_post


pipeline-ingest: pipeline-ingest-mongo pipeline-ingest-pg

