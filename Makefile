CHECK_CONNECTOR_URL=http://localhost:8083/connector-plugins

start: download-connector-plugin compose-up
	@echo "Waiting Kafka Connect connector plugin ready on $(CHECK_CONNECTOR_URL)..."
	@until curl -s -o /dev/null -w "%{http_code}" $(CHECK_CONNECTOR_URL) | grep -q "200"; do \
		echo "Not ready, waiting 5 second..."; \
		sleep 5; \
	done
	@echo "✅ Kafka Connect ready. The Kafka UI is available at http://localhost:8085"
	@$(MAKE) prepare-db
	@$(MAKE) build-ch-table
	@$(MAKE) create-dbz-connector
	@echo "Waiting debezium to be ready ..."
	@sleep 15
	@$(MAKE) create-ch-connector
	@echo "Waiting all data to be migrated into clickhouse ..."
	@sleep 10
	@$(MAKE) select-ch-data
stop: compose-stop
compose-up: 
	@echo "running compose up ..."
	@docker compose up -d 
	@echo "✅ All service running"
compose-log:
	docker compose logs -f
compose-stop:
	docker compose stop 
compose-down:
	docker compose down 
grant-user:
	@echo "Adding RELOAD privilege to debezium user ..."
	@DOCKER_CLI_HINTS=false docker exec -i mariadb_server mysql -u root < grant-access.sql
	@echo "✅ privilege updated"
prepare-db: 
	$(MAKE) grant-user
	@if [ ! -d "test_db" ]; then \
		echo "downloading dummy data ..." && \
		git clone https://github.com/datacharmer/test_db.git && \
		echo "Importing & validating dummy mysql data, this may take a while. Please wait ..." && \
		docker cp ./test_db mariadb_server:/tmp/test_db && \
		DOCKER_CLI_HINTS=false docker exec -i mariadb_server sh -c "cd /tmp/test_db && mysql -u root -t < employees.sql" && \
		DOCKER_CLI_HINTS=false docker exec -i mariadb_server sh -c "cd /tmp/test_db && mysql -u root -t < test_employees_md5.sql" && \
		echo "✅ Mysql data ready" ; \
	fi
download-connector-plugin:
	@mkdir -p kafka-connect-plugins
	@if [ ! -d "kafka-connect-plugins/debezium-connector-mariadb" ]; then \
		echo "downloading debezium mariadb connector..." && curl -L https://repo1.maven.org/maven2/io/debezium/debezium-connector-mariadb/3.1.2.Final/debezium-connector-mariadb-3.1.2.Final-plugin.tar.gz | tar -xz -C kafka-connect-plugins; \
	fi
	@echo "✅ debezium mariadb connector downloaded" 
download-connector-libs:
	@echo "downloading debezium core ..."
	@mkdir -p kafka-connect-libs
	@curl https://repo1.maven.org/maven2/io/debezium/debezium-core/3.1.2.Final/debezium-core-3.1.2.Final.jar -o kafka-connect-libs/debezium-core-3.1.2.Final.jar
create-dbz-connector:
	@echo "creating mariab connector ..."
	@curl -X POST http://localhost:8083/connectors \
  	-H "Content-Type: application/json" \
  	-d @debezium-connector.json
	@echo "\nchecking mariab connector"
	@sleep 5
	@curl http://localhost:8083/connectors/mariadb-source/status | jq
	@echo "✅ Debezium mariadb connector created. Immediately fetching data on departments table."
create-ch-connector:
	@echo "Creating clickhouse connector ..."
	@curl -X POST http://localhost:8083/connectors \
  	-H "Content-Type: application/json" \
  	-d @clickhouse-connector.json
	@echo "\nchecking clickhouse connector"
	@sleep 5
	@curl http://localhost:8083/connectors/clickhouse-sink/status | jq
delete-ch-connector:
	@curl -X DELETE http://localhost:8083/connectors/clickhouse-sink
check-dbz-connector-plugins:
	@curl http://localhost:8083/connector-plugins
delete-dbz-connector:
	@curl -X DELETE http://localhost:8083/connectors/mariadb-source
check-connector-plugins:
	@curl http://localhost:8083/connector-plugins
build-ch-table:
	@echo "Creating table departments on Clickhouse ..."
	@DOCKER_CLI_HINTS=false docker exec -i clickhouse_server clickhouse-client < ch_query.sql
	@echo "✅ table departments created on Clickhouse"
select-ch-data:
	@echo "Showing data from Clickhouse, table: departments ... "
	@DOCKER_CLI_HINTS=false docker exec -it clickhouse_server clickhouse-client --query="SELECT * FROM default.departments FINAL" --format=Pretty
	@echo "✅ All departments data migrated to Clickhouse. Now the mysql and clickhouse is sync. Try to perform any changes on mysql, then run make select-ch-data to see the data"
