export PATH := $(PATH):$(shell go env GOPATH)/bin
PROJECT_ROOT := $(abspath $(CURDIR)/..)

# ====================================
# Common Commands
# ====================================
.PHONY: proto
# To generate protobuf code for both api-gateway and user-service
proto:
	go install google.golang.org/protobuf/cmd/protoc-gen-go@v1.28
	go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@v1.2

	cd $(PROJECT_ROOT)/api-gateway && protoc --go_out=. --go-grpc_out=. proto/users.proto
	cd $(PROJECT_ROOT)/user-service && protoc --go_out=. --go-grpc_out=. proto/users.proto

# ====================================
# Local Run
# ====================================
SERVICE ?= api-gateway
.PHONY: run
# Run `make run SERVICE=api-gateway` to run api-gateway
# Run `make run SERVICE=user-service` to run user-service
run:
ifeq ($(SERVICE),api-gateway)
	$(MAKE) -C $(PROJECT_ROOT)/api-gateway run
endif
ifeq ($(SERVICE),user-service)
	$(MAKE) -C $(PROJECT_ROOT)/user-service run
endif

.PHONY: prom
# To view prometheus dashboard, go to http://localhost:9090/metrics
prom:
	chmod +x ./prometheus/prometheus.yml
	cd prometheus && prometheus --config.file=prometheus.yml

.PHONY: grafana
# To view grafana dashboard, go to http://localhost:3000 (username: admin, password: admin)
grafana:
	brew install grafana
	brew services start grafana

.PHONY: redis-server
# Run `redis-cli` to interact with redis server
redis-server:
	brew install redis
	brew services start redis

# ====================================
# Docker
# ====================================
.PHONY: docker-build
docker-build:
	docker-compose -f ./docker/docker-compose.dev.yaml down
	docker-compose -f ./docker/docker-compose.dev.yaml up --build -d

.PHONY: docker-down
docker-down:
	docker-compose -f ./docker/docker-compose.dev.yaml down

.PHONY: docker-seed
docker-seed:
	docker exec -i user-postgres psql -U authify -d authify_users_db < $(PROJECT_ROOT)/user-service/schema/dummy.sql

# ====================================
# Local Kubernetes with Docker Desktop
# ====================================
.PHONY: k8s-apply
k8s-apply:
	./scripts/localhost/push-local-docker-registry.sh

	kubectl create namespace authify || true
	kubectl config set-context --current --namespace=authify
	kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml

	kubectl apply -f ./k8s

	$(MAKE) -C $(PROJECT_ROOT)/api-gateway k8s-apply
	$(MAKE) -C $(PROJECT_ROOT)/user-service k8s-apply

.PHONY: k8s-delete
k8s-delete:
	kubectl delete -f ./k8s || true
	$(MAKE) -C $(PROJECT_ROOT)/api-gateway k8s-delete || true
	$(MAKE) -C $(PROJECT_ROOT)/user-service k8s-delete || true

# ====================================
# AWS EC2
# ====================================


# ec2_full_deploy:
# 	sh ./aws-cli/common/remove-variables.sh
# 	sh ./aws-cli/common/ecr.sh
# 	make ec2_deploy
# ec2_deploy:
# 	sh ./aws-cli/ec2/ec2.sh
# 	@echo "Successfully Deployed IMS to AWS EC2!"
# ec2_clean:
# 	sh ./aws-cli/ec2/ec2-cleanup.sh
# 	sh ./aws-cli/common/ecr-cleanup.sh
# 	@echo "Cleanup Completed!"

# ecr_push:
# 	sh ./aws-cli/common/ecr.sh
# ecr_clean:
# 	sh ./aws-cli/common/ecr-cleanup.sh

# terraform_ec2_key_pairs:
# 	rm -f ./terraform/modules/ec2/.ssh/IMS_BASTION_AZ1
# 	rm -f ./terraform/modules/ec2/.ssh/IMS_BASTION_AZ2
# 	rm -f ./terraform/modules/ec2/.ssh/IMS_API_GATEWAY_KEY_PAIR_AZ1
# 	rm -f ./terraform/modules/ec2/.ssh/IMS_API_GATEWAY_KEY_PAIR_AZ2
# 	rm -f ./terraform/modules/ec2/.ssh/IMS_AUTH_SERVICE_KEY_PAIR_AZ1
# 	rm -f ./terraform/modules/ec2/.ssh/IMS_AUTH_SERVICE_KEY_PAIR_AZ2
# 	ssh-keygen -t rsa -b 4096 -f ./terraform/modules/ec2/.ssh/IMS_BASTION_AZ1 -N ""
# 	ssh-keygen -t rsa -b 4096 -f ./terraform/modules/ec2/.ssh/IMS_BASTION_AZ2 -N ""
# 	ssh-keygen -t rsa -b 4096 -f ./terraform/modules/ec2/.ssh/IMS_API_GATEWAY_KEY_PAIR_AZ1 -N ""
# 	ssh-keygen -t rsa -b 4096 -f ./terraform/modules/ec2/.ssh/IMS_API_GATEWAY_KEY_PAIR_AZ2 -N ""
# 	ssh-keygen -t rsa -b 4096 -f ./terraform/modules/ec2/.ssh/IMS_AUTH_SERVICE_KEY_PAIR_AZ1 -N ""
# 	ssh-keygen -t rsa -b 4096 -f ./terraform/modules/ec2/.ssh/IMS_AUTH_SERVICE_KEY_PAIR_AZ2 -N ""
