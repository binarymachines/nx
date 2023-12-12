##
## Makefile for New World Oracle data pipelines / utility routines
##

# TODO: add wait to all generated shell scripts which run backgrounded tasks
#

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


db-purge:
	psql -U user --port=15433 --host=localhost  -w -f sql/purge.sql


db-create-tables:	
	export PGPASSWORD=$$NX_PG_PASSWORD && psql -U nxdba --port=15433 --host=localhost -d nxdb -w -f sql/db_extensions.sql
	export PGPASSWORD=$$NX_PG_PASSWORD && psql -U nxdba --port=15433 --host=localhost -d nxdb -w -f sql/nx_ddl.sql


db-init: gen-db-script gen-dba-script gen-perm-script db-create-database db-create-dbauser db-set-perms db-create-tables


docker-login:
	$(eval CONTAINER_ID=$(shell docker ps |grep postgres | grep alpine | awk '{ print $$1 }'))
	
	docker exec -ti $(CONTAINER_ID) /bin/bash


#_______________________________________________________________________
#
# Pipeline targets
#_______________________________________________________________________
#

pipeline-sample:
	xfile -p --delimiter '|' data/data_sample.csv --limit 5 | jq


pipeline-ingest-mongo:
	cat static_data/reddit_submissions.jsonl \
	| ngst --config config/ingest_reddit_data.yaml --target mongodb > temp_data/raw_post_records.jsonl
	 

pipeline-ingest-pg:
	cat temp_data/raw_post_records.jsonl \
	| ngst --config config/ingest_reddit_data.yaml --target sqldb --params=record_type:reddit_post


pipeline-ingest: pipeline-ingest-mongo pipeline-ingest-pg

