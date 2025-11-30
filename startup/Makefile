# ============================
# Common Commands
# ============================
proto:
	@echo "Align gRPC proto files..."
	./proto.sh

# ============================
# Local Run
# ============================
SERVICE ?= api-gateway
.PHONY: run
run:
ifeq ($(SERVICE),api-gateway)
	$(MAKE) -C ../api-gateway run
endif
ifeq ($(SERVICE),user-service)
	$(MAKE) -C ../user-service run
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

# build:
# 	docker-compose -f docker-compose.dev.yml down
# 	@echo "Building and starting docker images..."
# 	docker-compose -f docker-compose.dev.yml up --build -d
# 	@echo "Docker images built and started!"

# down:
# 	docker-compose -f docker-compose.dev.yml down

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
