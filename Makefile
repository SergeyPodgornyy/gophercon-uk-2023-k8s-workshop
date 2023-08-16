# Check to see if we can use ash, in Alpine images, or default to BASH.
SHELL_PATH = /bin/ash
SHELL = $(if $(wildcard $(SHELL_PATH)),/bin/ash,/bin/bash)

run:
	go run app/services/sales-api/main.go | go run app/tooling/logfmt/main.go -service=$(SERVICE_NAME)

help:
	go run app/services/sales-api/main.go --help

# ==============================================================================
# Define dependencies

GOLANG          := golang:1.21
ALPINE          := alpine:3.18
KIND            := kindest/node:v1.27.3
POSTGRES        := postgres:15.4
VAULT           := hashicorp/vault:1.14
GRAFANA         := grafana/grafana:9.5.3
PROMETHEUS      := prom/prometheus:v2.45.0
TEMPO           := grafana/tempo:2.2.0
LOKI            := grafana/loki:2.8.3
PROMTAIL        := grafana/promtail:2.8.3
TELEPRESENCE    := datawire/ambassador-telepresence-manager:2.14.2

KIND_CLUSTER    := ardan-starter-cluster
NAMESPACE       := sales-system
APP             := sales
BASE_IMAGE_NAME := ardanlabs/service
SERVICE_NAME    := sales-api
VERSION         := 0.0.1
SERVICE_IMAGE   := $(BASE_IMAGE_NAME)/$(SERVICE_NAME):$(VERSION)
METRICS_IMAGE   := $(BASE_IMAGE_NAME)/$(SERVICE_NAME)-metrics:$(VERSION)

# VERSION       := "0.0.1-$(shell git rev-parse --short HEAD)"

up:
	kind create cluster \
		--image $(KIND) \
		--name $(KIND_CLUSTER) \
		--config zarf/k8s/dev/kind-config.yaml

	kubectl wait --timeout=120s --namespace=local-path-storage --for=condition=Available deployment/local-path-provisioner

	kind load docker-image $(TELEPRESENCE) --name $(KIND_CLUSTER)

	telepresence --context=kind-$(KIND_CLUSTER) helm install --request-timeout 2m 
	telepresence --context=kind-$(KIND_CLUSTER) -kubeconfig=$(HOME)/.kube/config connect

down:
	telepresence quit -s
	kind delete cluster --name $(KIND_CLUSTER)

# ==============================================================================
# Building containers

all: service

service:
	docker build \
		-f zarf/docker/dockerfile.service \
		-t $(SERVICE_IMAGE) \
		--build-arg BUILD_REF=$(VERSION) \
		--build-arg BUILD_DATE=`date -u +"%Y-%m-%dT%H:%M:%SZ"` \
		.
# ------------------------------------------------------------------------------

load:
	kind load docker-image $(SERVICE_IMAGE) --name $(KIND_CLUSTER)

apply:
	kustomize build zarf/k8s/dev/sales | kubectl apply -f -
	kubectl wait pods --namespace=$(NAMESPACE) --selector app=$(APP) --timeout=120s --for=condition=Ready

restart:
	kubectl rollout restart deployment $(APP) --namespace=$(NAMESPACE)

update: all load restart

reapply: all load apply

# ------------------------------------------------------------------------------

logs:
	kubectl logs --namespace=$(NAMESPACE) -l app=$(APP) --all-containers=true -f --tail=100 --max-log-requests=6 | go run app/tooling/logfmt/main.go -service=$(SERVICE_NAME)

status:
	kubectl get nodes -o wide
	kubectl get svc -o wide
	kubectl get pods -o wide --watch --all-namespaces

describe:
	kubectl describe pod --namespace=$(NAMESPACE) -l app=$(APP)

tidy:
	go mod tidy
	go mod vendor

# ------------------------------------------------------------------------------

hack:
	curl -il http://$(SERVICE_NAME).$(NAMESPACE).svc.cluster.local:3000/hack

metrics:
	curl -il http://$(SERVICE_NAME).$(NAMESPACE).svc.cluster.local:4000/debug/vars
