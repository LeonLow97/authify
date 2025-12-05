.PHONY: run
run:
	go run ./cmd/api/*.go

.PHONY: k8s-apply
k8s-apply:
	kubectl apply -f ./k8s

.PHONY: k8s-delete
k8s-delete:
	kubectl delete -f ./k8s