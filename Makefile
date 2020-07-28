export AWS_ACCESS_KEY_ID	 ?= $(shell aws configure get aws_access_key_id)
export AWS_SECRET_ACCESS_KEY ?= $(shell aws configure get aws_secret_access_key)
export AWS_REGION		     = us-west-2
export GIT_REPO				 = appmesh
export EKSCTL_EXPERIMENTAL=true
export APPMESH_NS = appmesh-system

.id:
	git config user.email | awk -F@ '{print $$1}' > .id

deploy/cluster.yaml: .id deploy/cluster.yaml.in
	sed "s/{{ .Name }}/`cat .id`/g; s/{{ .Region }}/$(AWS_REGION)/g" deploy/cluster.yaml.in > $@

eks-deploy: deploy/cluster.yaml
	eksctl create cluster -f deploy/cluster.yaml

cluster: eks-deploy
	aws eks update-kubeconfig --name $(shell cat .id)-appmesh
	@echo 'Done with build cluster'

repo:
	eksctl enable repo \
		--cluster $(shell cat .id)-appmesh \
		--region $(AWS_REGION) --git-user fluxcd \
		--git-email $(shell cat .id)@users.noreply.github.com \
		--git-url git@github.com:$(shell cat .id)/$(GIT_REPO)

mesh:
	eksctl enable profile appmesh \
		--revision=demo \
		--cluster $(shell cat .id)-appmesh \
		--region $(AWS_REGION) --git-user fluxcd \
		--git-email $(shell cat .id)@users.noreply.github.com \
		--git-url git@github.com:$(shell cat .id)/$(GIT_REPO)
	# Flux does a git-cluster reconciliation every five minutes,
	# the following command can be used to speed up the synchronization.
	fluxctl sync --k8s-fwd-ns flux

status:
	# kubectl get --watch helmreleases --all-namespaces
	kubectl get helmreleases --all-namespaces
	kubectl describe mesh

logs:
	 kubectl logs -n $(APPMESH_NS) -f --since 10s $(shell kubectl get pods -n $(APPMESH_NS) -o name | grep controller)

clean:
	eksctl delete cluster --name $(shell cat .id)-appmesh --region $(AWS_REGION)
