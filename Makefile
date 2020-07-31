# Switched to sts token broken this command need MFA to create this, so assume
# it is setup when you get here.
# export AWS_ACCESS_KEY_ID	 ?= $(shell aws configure get aws_access_key_id)
# export AWS_SECRET_ACCESS_KEY ?= $(shell aws configure get aws_secret_access_key)
export AWS_REGION		     = us-east-1
export GIT_REPO				 = kubeflow-ml
export EKSCTL_EXPERIMENTAL=true
export AWS_COGNITO_USER_POOL_NAME = ml-access
export AWS_COGNITO_USER_APP_NAME = kubeflow


.id:
	git config user.email | awk -F@ '{print $$1}' > .id

deploy/cluster.yaml: .id deploy/cluster.yaml.in
	sed "s/{{ .Name }}/`cat .id`/g; s/{{ .Region }}/$(AWS_REGION)/g" deploy/cluster.yaml.in > $@

cluster: deploy/cluster.yaml
	eksctl create cluster -f deploy/cluster.yaml
	@echo 'Done with build cluster'

istio:
	istioctl install --set addonComponents.grafana.enabled=true
	@echo 'Done with istio installation on cluster'

repo:
	eksctl enable repo \
		--cluster $(shell cat .id)-eks-kubeflow \
		--region $(AWS_REGION) --git-user fluxcd \
		--git-email $(shell cat .id)@users.noreply.github.com \
		--git-url git@github.com:$(shell cat .id)/$(GIT_REPO)

kubeflow-build: deploy/kfctl_aws_cognito.v1.0.2.yaml.in
	./scripts/kubeflow.sh $(AWS_REGION) \
		$(AWS_COGNITO_USER_POOL_NAME) \
		$(AWS_COGNITO_USER_APP_NAME) \
		$(shell cat .id)-eks-kubeflow

	# Creates configuration files defining the various resources
	# in your deployment. You only need to run kfctl build if you want to edit the
	# resources before running kfctl apply.
	# kfctl build -f deploy/kfctl_aws_cognito.v1.0.2.yaml -V

	kfctl apply -f deploy/kfctl_aws_cognito.v1.0.2.yaml -V
	@echo "Kubeflow deployed on cluster"

status:
	fluxctl sync --k8s-fwd-ns flux
	# kubectl get --watch helmreleases --all-namespaces
	kubectl get helmreleases --all-namespaces

clean:
	# eksctl delete cluster --name $(shell cat .id)-eks-kubeflow --region $(AWS_REGION)
	@echo 'Too dangerous to run comment out the above line and run to delete cluster'

