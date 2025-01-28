#!/bin/sh
.DEFAULT_GOAL := help

.PHONY: deploy-dev deploy-qa deploy-prod \
		undeploy-dev undeploy-qa undeploy-prod \
		install-docker-dev install-docker-qa install-docker-prod

# Definir comandos de despliegue para cada ambiente
deploy-dev: ## Desplegar en el ambiente de desarrollo: make deploy-dev
	@./scripts/deploy/aws/deploy.sh dev

deploy-qa: ## Desplegar en el ambiente de prueba: make deploy-qa
	@./scripts/deploy/aws/deploy.sh qa

deploy-prod: ## Desplegar en el ambiente de producción: make deploy-prod
	@./scripts/deploy/aws/deploy.sh prod


# Definir comandos de limpieza para cada ambiente
undeploy-dev: ## Desinstalar solución en el ambiente de desarrollo: make undeploy-dev
	@./scripts/deploy/aws/undeploy.sh dev

undeploy-qa: ## Desinstalar solución en  el ambiente de prueba: make undeploy-qa
	@./scripts/deploy/aws/undeploy.sh qa

undeploy-prod: ## Desinstalar solución en  el ambiente de producción: make undeploy-prod
	@./scripts/deploy/aws/undeploy.sh prod


# Definir comandos de instalación de docker para cada ambiente
install-docker-dev: ## Instalar docker en el ambiente de desarrollo: make install-docker-dev
	@./scripts/deploy/aws/install-docker-manager.sh dev

install-docker-qa: ## Instalar docker en el ambiente de prueba: make install-docker-qa
	@./scripts/deploy/aws/install-docker-manager.sh qa

install-docker-prod: ## Instalar docker en el ambiente de producción: make install-docker-prod
	@./scripts/deploy/aws/install-docker-manager.sh prod


# ## Target Help ##
help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
