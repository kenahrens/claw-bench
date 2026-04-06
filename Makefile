SHELL := /bin/bash

.PHONY: setup run collect

setup:
	kubectl apply -f k8s/base/namespace.yaml
	kubectl apply -f k8s/base/pvc.yaml
	@echo "Create and apply k8s/base/secrets.yaml from template before running jobs."

run:
	./scripts/run-task.sh

collect:
	./scripts/collect-logs.sh
