all: generated

.PHONY: generated
generated:
	mkdir -p generated
	chmod 777 generated
	docker-compose pull debgen
	docker-compose up debgen --exit-code-from debgen

.PHONY: debs
debs:
	./scripts/build_debs.sh
