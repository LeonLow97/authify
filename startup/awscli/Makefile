SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

AWSCLI_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
VARIABLES_FILE ?= variables.env
ENV_TEMPLATE := $(AWSCLI_DIR)/.env.template
ENV_FILE := $(AWSCLI_DIR)/.env
VARS_FILE := $(AWSCLI_DIR)/$(VARIABLES_FILE)

-include $(ENV_TEMPLATE)
-include $(ENV_FILE)
-include $(VARS_FILE)

dequote = $(subst ",,$(strip $(1)))

REMOTE_USER := $(call dequote,$(AMI_EC2_DEFAULT_USER))
SSH_OPTS ?= -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new

BASTION_IP_az1 := $(call dequote,$(BASTION_PUBLIC_IP_AZ1))
BASTION_IP_az2 := $(call dequote,$(BASTION_PUBLIC_IP_AZ2))

BASTION_KEY_az1 := $(call dequote,$(EC2_BASTION_HOST_KEY_NAME_AZ1))
BASTION_KEY_az2 := $(call dequote,$(EC2_BASTION_HOST_KEY_NAME_AZ2))

API_GATEWAY_KEY_az1 := $(call dequote,$(EC2_API_GATEWAY_KEY_NAME_AZ1))
API_GATEWAY_KEY_az2 := $(call dequote,$(EC2_API_GATEWAY_KEY_NAME_AZ2))
USER_SERVICE_KEY_az1 := $(call dequote,$(EC2_USER_SERVICE_KEY_NAME_AZ1))
USER_SERVICE_KEY_az2 := $(call dequote,$(EC2_USER_SERVICE_KEY_NAME_AZ2))

API_GATEWAY_IP_az1 := $(call dequote,$(API_GATEWAY_PRIVATE_IP_AZ1))
API_GATEWAY_IP_az2 := $(call dequote,$(API_GATEWAY_PRIVATE_IP_AZ2))
USER_SERVICE_IP_az1 := $(call dequote,$(USER_SERVICE_PRIVATE_IP_AZ1))
USER_SERVICE_IP_az2 := $(call dequote,$(USER_SERVICE_PRIVATE_IP_AZ2))
ALB_DNS := $(call dequote,$(ALB_DNS_NAME))

API_BASE_URL ?= $(if $(ALB_DNS),http://$(ALB_DNS),http://localhost:8080)
TEST_EMAIL ?= authify.test@example.com
TEST_PASSWORD ?= Password111!
TEST_FIRST_NAME ?= Authify
TEST_LAST_NAME ?= Tester

define require_var
	@if [[ -z "$(strip $($(1)))" ]]; then \
		echo "Missing $(1). Make sure $(VARS_FILE) has been populated by the deploy scripts."; \
		exit 1; \
	fi
endef

define require_file
	@if [[ ! -f "$(1)" ]]; then \
		echo "Missing file: $(1)"; \
		exit 1; \
	fi
endef

.PHONY: help curl-health curl-signup curl-login curl-auth-flow \
	copy-pems-az1 copy-pems-az2 ssh-bastion-az1 ssh-bastion-az2 \
	ssh-api-gateway-az1 ssh-api-gateway-az2 ssh-user-service-az1 ssh-user-service-az2

help:
	@echo "Available targets:"
	@echo "  make curl-health"
	@echo "  make curl-signup"
	@echo "  make curl-login"
	@echo "  make curl-auth-flow"
	@echo "  make copy-pems-az1"
	@echo "  make copy-pems-az2"
	@echo "  make ssh-bastion-az1"
	@echo "  make ssh-bastion-az2"
	@echo "  make ssh-api-gateway-az1"
	@echo "  make ssh-api-gateway-az2"
	@echo "  make ssh-user-service-az1"
	@echo "  make ssh-user-service-az2"

curl-health:
	curl -i -sS "$(API_BASE_URL)/health/liveness"

curl-signup:
	curl -i -sS -X POST "$(API_BASE_URL)/api/v1/signup" \
		-H "Content-Type: application/json" \
		-d '{"first_name":"$(TEST_FIRST_NAME)","last_name":"$(TEST_LAST_NAME)","email":"$(TEST_EMAIL)","password":"$(TEST_PASSWORD)"}'

curl-login:
	curl -i -sS -X POST "$(API_BASE_URL)/api/v1/login" \
		-H "Content-Type: application/json" \
		-d '{"email":"$(TEST_EMAIL)","password":"$(TEST_PASSWORD)"}'

curl-auth-flow: curl-health curl-signup curl-login

copy-pems-az1:
	$(call require_var,BASTION_IP_az1)
	$(call require_var,BASTION_KEY_az1)
	$(call require_var,API_GATEWAY_KEY_az1)
	$(call require_var,USER_SERVICE_KEY_az1)
	$(call require_file,$(AWSCLI_DIR)/$(BASTION_KEY_az1).pem)
	$(call require_file,$(AWSCLI_DIR)/$(API_GATEWAY_KEY_az1).pem)
	$(call require_file,$(AWSCLI_DIR)/$(USER_SERVICE_KEY_az1).pem)
	bastion_key="$(AWSCLI_DIR)/$(BASTION_KEY_az1).pem"; \
	bastion_host="$(REMOTE_USER)@$(BASTION_IP_az1)"; \
	for key_name in "$(API_GATEWAY_KEY_az1)" "$(USER_SERVICE_KEY_az1)"; do \
		local_key="$(AWSCLI_DIR)/$$key_name.pem"; \
		remote_tmp="/tmp/$$key_name.pem"; \
		scp $(SSH_OPTS) -i "$$bastion_key" "$$local_key" "$$bastion_host:$$remote_tmp"; \
		ssh $(SSH_OPTS) -i "$$bastion_key" "$$bastion_host" \
			"install -m 400 '$$remote_tmp' '/home/$(REMOTE_USER)/$$key_name.pem' && rm -f '$$remote_tmp'"; \
	done

copy-pems-az2:
	$(call require_var,BASTION_IP_az2)
	$(call require_var,BASTION_KEY_az2)
	$(call require_var,API_GATEWAY_KEY_az2)
	$(call require_var,USER_SERVICE_KEY_az2)
	$(call require_file,$(AWSCLI_DIR)/$(BASTION_KEY_az2).pem)
	$(call require_file,$(AWSCLI_DIR)/$(API_GATEWAY_KEY_az2).pem)
	$(call require_file,$(AWSCLI_DIR)/$(USER_SERVICE_KEY_az2).pem)
	bastion_key="$(AWSCLI_DIR)/$(BASTION_KEY_az2).pem"; \
	bastion_host="$(REMOTE_USER)@$(BASTION_IP_az2)"; \
	for key_name in "$(API_GATEWAY_KEY_az2)" "$(USER_SERVICE_KEY_az2)"; do \
		local_key="$(AWSCLI_DIR)/$$key_name.pem"; \
		remote_tmp="/tmp/$$key_name.pem"; \
		scp $(SSH_OPTS) -i "$$bastion_key" "$$local_key" "$$bastion_host:$$remote_tmp"; \
		ssh $(SSH_OPTS) -i "$$bastion_key" "$$bastion_host" \
			"install -m 400 '$$remote_tmp' '/home/$(REMOTE_USER)/$$key_name.pem' && rm -f '$$remote_tmp'"; \
	done

ssh-bastion-az1:
	$(call require_var,BASTION_IP_az1)
	$(call require_var,BASTION_KEY_az1)
	$(call require_file,$(AWSCLI_DIR)/$(BASTION_KEY_az1).pem)
	ssh $(SSH_OPTS) -i "$(AWSCLI_DIR)/$(BASTION_KEY_az1).pem" "$(REMOTE_USER)@$(BASTION_IP_az1)"

ssh-bastion-az2:
	$(call require_var,BASTION_IP_az2)
	$(call require_var,BASTION_KEY_az2)
	$(call require_file,$(AWSCLI_DIR)/$(BASTION_KEY_az2).pem)
	ssh $(SSH_OPTS) -i "$(AWSCLI_DIR)/$(BASTION_KEY_az2).pem" "$(REMOTE_USER)@$(BASTION_IP_az2)"

ssh-api-gateway-az1: copy-pems-az1
	$(call require_var,API_GATEWAY_IP_az1)
	ssh $(SSH_OPTS) -tt -i "$(AWSCLI_DIR)/$(BASTION_KEY_az1).pem" "$(REMOTE_USER)@$(BASTION_IP_az1)" \
		"ssh $(SSH_OPTS) -i '/home/$(REMOTE_USER)/$(API_GATEWAY_KEY_az1).pem' $(REMOTE_USER)@$(API_GATEWAY_IP_az1)"

ssh-api-gateway-az2: copy-pems-az2
	$(call require_var,API_GATEWAY_IP_az2)
	ssh $(SSH_OPTS) -tt -i "$(AWSCLI_DIR)/$(BASTION_KEY_az2).pem" "$(REMOTE_USER)@$(BASTION_IP_az2)" \
		"ssh $(SSH_OPTS) -i '/home/$(REMOTE_USER)/$(API_GATEWAY_KEY_az2).pem' $(REMOTE_USER)@$(API_GATEWAY_IP_az2)"

ssh-user-service-az1: copy-pems-az1
	$(call require_var,USER_SERVICE_IP_az1)
	ssh $(SSH_OPTS) -tt -i "$(AWSCLI_DIR)/$(BASTION_KEY_az1).pem" "$(REMOTE_USER)@$(BASTION_IP_az1)" \
		"ssh $(SSH_OPTS) -i '/home/$(REMOTE_USER)/$(USER_SERVICE_KEY_az1).pem' $(REMOTE_USER)@$(USER_SERVICE_IP_az1)"

ssh-user-service-az2: copy-pems-az2
	$(call require_var,USER_SERVICE_IP_az2)
	ssh $(SSH_OPTS) -tt -i "$(AWSCLI_DIR)/$(BASTION_KEY_az2).pem" "$(REMOTE_USER)@$(BASTION_IP_az2)" \
		"ssh $(SSH_OPTS) -i '/home/$(REMOTE_USER)/$(USER_SERVICE_KEY_az2).pem' $(REMOTE_USER)@$(USER_SERVICE_IP_az2)"
