.PHONY: run
run:
	go run ./cmd/*.go

.PHONY: k8s-apply
k8s-apply:
	kubectl apply -f ./k8s

.PHONY: k8s-delete
k8s-delete:
	kubectl delete deployment,service,configmap,secret,ingress,statefulset --all -n authify --ignore-not-found
