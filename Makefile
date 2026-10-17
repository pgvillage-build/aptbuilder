all: scripts

.PHONY: scripts
scripts:
	mkdir -p scripts
	chmod 777 scripts
	docker-compose pull debgen
	docker-compose up debgen --exit-code-from debgen
