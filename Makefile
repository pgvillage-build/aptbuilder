# The docker compose plugin (compose v2); set DOCKER_COMPOSE=docker-compose for the standalone binary
DOCKER_COMPOSE ?= docker compose

all: generated

.PHONY: generated
generated:
	mkdir -p generated
	chmod 777 generated
	$(DOCKER_COMPOSE) pull debgen
	$(DOCKER_COMPOSE) up debgen --exit-code-from debgen

.PHONY: build
build:
	mkdir -p deb
	chmod 777 deb
	$(DOCKER_COMPOSE) pull debbuilder
	$(DOCKER_COMPOSE) up debbuilder --exit-code-from debbuilder

.PHONY: repo
repo:
	mkdir -p apt
	chmod 777 apt
	$(DOCKER_COMPOSE) pull aptrepo
	$(DOCKER_COMPOSE) up aptrepo --exit-code-from aptrepo
