# KubeFlow

This project is modeled after the 
[Kubeflow end-to-end demo](https://www.kubeflow.org/docs/aws/aws-e2e)

## Prerequisites
Access to an AWS account via command line is required, make sure you’re able 
to execute aws cli commands. Install the following programs in the system from which
you provision the infra (laptop or conf.management tool):
   
   * AWS CLI
   * git
   * jq
   * [kubectl](https://github.com/kubeflow/kfctl/releases/)
   * eksctl
   * fluxctl
   * kustomize
   * [kn](https://github.com/knative/homebrew-client)


## Build

TODO - Setup IAM as part of the cluster setup to give access to a group

```bash
make cluster
```

You will get a lot of debug output you should note the following 'eksctl utils' commands
in case of problems and debugging:
```bash
[ℹ]  eksctl version 0.18.0
...
[ℹ]  if you encounter any issues, check CloudFormation console or try 'eksctl utils describe-stacks --region=us-west-2 --cluster=seizadi-appmesh'
[ℹ]  CloudWatch logging will not be enabled for cluster "seizadi-appmesh" in "us-west-2"
[ℹ]  you can enable it with 'eksctl utils update-cluster-logging --region=us-west-2 --cluster=seizadi-appmesh'
...
[✔]  EKS cluster "seizadi-appmesh" in "us-west-2" region is ready
```

The default number of nodes that are called for is 6 nodes you can change it higher or lower:
```bash
eksctl scale nodegroup --cluster=seizadi-eks-kubeflow --nodes=4 seizadi-eks-kubeflow-ng
```

## Deploy
This assumes you have a appmesh github repo that you attach as part of the GitOps pipeline:
```bash
make repo
```
```bash
[ℹ]  Generating manifests
[ℹ]  Cloning git@github.com:seizadi/appmesh
Cloning into '/var/folders/49/3pxhjsps4fx4q21nkbj1j6n00000gp/T/eksctl-install-flux-clone-257687401'...
remote: Enumerating objects: 3, done.
....
[ℹ]  Flux will only operate properly once it has write-access to the Git repository
[ℹ]  please configure git@github.com:seizadi/appmesh so that the following Flux SSH public key has write access to it
ssh-rsa ..................
   
```
Copy the public key 'ssh-rsa ....' and create a deploy key with write access on your GitHub repository. 
Go to Settings > Deploy keys click on Add deploy key, check Allow write access, 
paste the Flux public key and click Add key.

Once that is done, Flux will pick up the changes in the repository and deploy them to the cluster.


### Setup CERT and DNS Subdomain for Cognito
See [Cognito Setup](https://www.kubeflow.org/docs/aws/aws-e2e/#cognito).
I had wanted to use a registered domain, but it had an imported certificate and cognito needs
an AWS managed certificate (i.e. one issued by AWS Certificate Manager).
I am using 
[godaddy to map subdomain](https://www.godaddy.com/help/add-an-ns-record-19212)

At the end you need to make sure that the login URL works,
you will find all this information from Cognito User Pool page:
```bash
https://auth.example.com/login?response_type=code&client_id=<your_app_client_id>&redirect_uri=<your_callback_url>
```
At this point you should get Cognito UI to login using your credentials, but when you login you don't see anything
since we have not setup the Kubeflow service yet.

We have all the information to setup Kubeflow server you call into the kubeflow project
to get IAM Roles:
```bash
❯ make iamroles
aws iam list-roles | jq -r ".Roles[] | \
                select(.RoleName | startswith(\"eksctl-seizadi-eks-kubeflow\") \
                and contains(\"NodeInstanceRole\")) .RoleName"
eksctl-seizadi-eks-kubeflow-nodeg-NodeInstanceRole-xxxxxx
```

To setup the 


```bash
make status
```

## Install Istio
Install istioctl on MacOS
```bash
brew install istioctl
```

## Debug
### Could not use kfctl apply to install
I have following error:
```bash
WARN[0111] Encountered error applying application istio-install:  (kubeflow.error): Code 500 with message: Apply.Run  Error [error when applying patch:
....
ssgateway", "chart":"gateways", "heritage":"Tiller", "istio":"ingressgateway", "release":"istio"}, MatchExpressions:[]v1.LabelSelectorRequirement(nil)}: field is immutable, error when creating "/tmp/kout925260150": admission webhook "validation.istio.io" denied the request: unrecognized type kubernetes, error when creating "/tmp/kout925260150": admission webhook "validation.istio.io" denied the request: unrecognized type logentry, error when creating "/tmp/kout925260150": admission webhook "validation.istio.io" denied the request: unrecognized type metric]  filename="kustomize/kustomize.go:202"
WARN[0111] Will retry in 12 seconds.                     filename="kustomize/kustomize.go:203"
```
Start by upgrading from v1.0.2 from v1.0-branch
```bash
wget https://raw.githubusercontent.com/kubeflow/manifests/v1.0-branch/kfdef/kfctl_aws_cognito.v1.0.2.yaml
```
to v1.0.2 from v1.1.0 branch:
```bash
wget https://raw.githubusercontent.com/kubeflow/manifests/v1.1.0/kfdef/kfctl_aws_cognito.v1.0.2.yaml
```

### Could not use kubectl
```bash
$ k get nodes
error: You must be logged in to the server (Unauthorized)
```
This seems to be a
[known issue some people have experienced](https://github.com/kubernetes-sigs/aws-iam-authenticator/issues/174), 
this is the solution that worked for me:
```bash
$ aws eks update-kubeconfig --name seizadi-appmesh
Added new context arn:aws:eks:us-west-2:405093580753:cluster/seizadi-appmesh to /Users/seizadi/.kube/config
sc-l-seizadi:eksctl seizadi$ k get nodes
NAME                                          STATUS   ROLES    AGE   VERSION
ip-192-168-38-54.us-west-2.compute.internal   Ready    <none>   65m   v1.15.11-eks-af3caf
ip-192-168-94-72.us-west-2.compute.internal   Ready    <none>   65m   v1.15.11-eks-af3caf
```

### 'make repo' stage failed
```bash
[ℹ]  Waiting for Helm Operator to start
[!]  Helm Operator is not ready yet (Could not create a dialer: Could not get pod name: Could not find pod for selector: labels "name in (flux-helm-operator)"), retrying ...
....
[!]  Helm Operator is not ready yet (Could not create a dialer: Could not get pod name: Could not find pod for selector: labels "name in (flux-helm-operator)"), retrying ...
[✖]  You may find the local clone of git@github.com:seizadi/appmesh used by eksctl at /var/folders/49/3pxhjsps4fx4q21nkbj1j6n00000gp/T/eksctl-install-flux-clone-257687401
[ℹ]  
Error: timed out waiting for Helm Operator's pod to be created
make: *** [repo] Error 1
```

Looks like this is a [known regression](https://github.com/weaveworks/eksctl/issues/2118),
you can see the [root cause here](https://github.com/weaveworks/eksctl/pull/2117).
The fix is a new version was 0.19.0-rc.1, upgrade eksctl
```bash
brew upgrade eksctl
==> Upgrading weaveworks/tap/eksctl 0.18.0 -> 0.19.0 
``` 
It gets updated frequently right now I have 0.24.0 loaded:
```bash
❯ brew upgrade eksctl
...
Warning: weaveworks/tap/eksctl 0.24.0 already installed
```
