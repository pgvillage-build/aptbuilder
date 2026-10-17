all: generated

.PHONY: generated
generated:
	mkdir -p generated
	chmod 777 generated
	docker-compose pull debgen
	docker-compose up debgen --exit-code-from debgen

.PHONY: build
build:
	mkdir -p deb
	chmod 777 deb
	docker-compose pull debbuilder
	docker-compose up debbuilder --exit-code-from debbuilder
