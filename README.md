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

You don't need to install Istio on cluster
 installation of kubeflow will install Istio:
```bash
make kubeflow
```
You will have an ALB launched and attached to the Istion Gateway.
The ALB does not have a unique name you will have to find it
using creation timestamp or tags:
```bash
| Tag                                    | Value                                 |
|--------------------------------------  | ------------------------------------- |
| kubernetes.io/service-name             | istio-system/kfserving-ingressgateway |  
| kubernetes.io/cluster/dev-eks-kubeflow | owned                                 |
```

## Using Examples to enable RBAC

This guide helps in setting up RBAC for Kubeflow.

The RBAC rules here assume 3 groups: admin, datascience and validator as sample groups for operating on Kubeflow.

### Setup

```
./apply_example.sh --issuer https://dex.example.com:32000 --jwks-uri https://dex.example.com:32000/keys --client-id ldapdexapp
```

#### Note Regarding Istio RBAC

Currently, the only service authenticated and authorized supported in this example is ml-pipeline service.
Support for authorization in Pipelines is being discussed in this [issue](https://github.com/kubeflow/pipelines/issues/1223).
This example allows for authentication and authorization only for requests within the Kubernetes cluster.


## Debug

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

### Failed to delete cluster due to Cognito binding

```bash
[✖]  unexpected status "DELETE_FAILED" while waiting for CloudFormation stack "eksctl-seizadi-eks-kubeflow-nodegroup-seizadi-eks-kubeflow-ng"
[ℹ]  fetching stack events in attempt to troubleshoot the root cause of the failure
[✖]  AWS::CloudFormation::Stack/eksctl-seizadi-eks-kubeflow-nodegroup-seizadi-eks-kubeflow-ng: DELETE_FAILED – "The following resource(s) failed to delete: [NodeInstanceRole]. "
[✖]  AWS::IAM::Role/NodeInstanceRole: DELETE_FAILED – "Cannot delete entity, must delete policies first. (Service: AmazonIdentityManagement; Status Code: 409; Error Code: DeleteConflict; Request ID: 54ad9613-fffd-44de-b780-114d679f2f1b)"
[ℹ]  1 error(s) occurred while deleting cluster with nodegroup(s)
[✖]  waiting for CloudFormation stack "eksctl-seizadi-eks-kubeflow-nodegroup-seizadi-eks-kubeflow-ng": ResourceNotReady: failed waiting for successful resource state
Error: failed to delete cluster with nodegroup(s)
```

Ideally now you need to go find the cluster node instance role in AWS IAM and cleanup the bindings:
```bash
aws iam delete-role-policy --region ${REGION} --profile ${PROFILE} \
    --role-name ${ROLE_NAME} \
    --policy-name ${CLUSTER_NAME}-<SomePolicy >
```

I cheated and went to AWS Console and deleted the cluster from there! This is a problem that the Cluster becomes
attached to other services and those are not visible to eksctl in managing the cluster.

Now the Cloud Formation Template is orphaned when I try to create a new cluster and that cleanup
option will not work since the cluster is gone:
```bash
[ℹ]  to cleanup resources, run 'eksctl delete cluster --region=us-east-1 --name=seizadi-eks-kubeflow'
[✖]  creating CloudFormation stack "eksctl-seizadi-eks-kubeflow-cluster": AlreadyExistsException: Stack [eksctl-seizadi-eks-kubeflow-cluster] already exists
        status code: 400, request id: 331ecd30-755f-4b78-9027-89fdd96cf3ca
```

Go to AWS Console Cloud Formation page and delete template from there, you will see the
node instance role which is the root cause of deletion errors: 

```bash
NodeInstanceRole
eksctl-seizadi-eks-kubeflow-nodeg-NodeInstanceRole-1LXJR0KG2D5RL
```

### AWS Resource Errors
Had this case where AWS allocation failed. I was not able to cleanup using eksctl, had to go
to AWS Console and cleanup Cloud Formation resources.

Also made the cluster three AZs to reduce the chances of this happening.

```bash
❯ make cluster
sed "s/{{ .Name }}/`cat .id`/g; s/{{ .Region }}/us-east-1/g" deploy/cluster.yaml.in > deploy/cluster.yaml
eksctl create cluster -f deploy/cluster.yaml
[ℹ]  eksctl version 0.24.0
[ℹ]  using region us-east-1
[ℹ]  setting availability zones to [us-east-1e us-east-1c]
[ℹ]  subnets for us-east-1e - public:192.168.0.0/19 private:192.168.64.0/19
[ℹ]  subnets for us-east-1c - public:192.168.32.0/19 private:192.168.96.0/19
[ℹ]  nodegroup "dev-eks-kubeflow-ng" will use "ami-055e79c5dcb596625" [AmazonLinux2/1.15]
[ℹ]  using Kubernetes version 1.15
[ℹ]  creating EKS cluster "dev-eks-kubeflow" in "us-east-1" region with un-managed nodes
[ℹ]  1 nodegroup (dev-eks-kubeflow-ng) was included (based on the include/exclude rules)
[ℹ]  will create a CloudFormation stack for cluster itself and 1 nodegroup stack(s)
[ℹ]  will create a CloudFormation stack for cluster itself and 0 managed nodegroup stack(s)
[ℹ]  if you encounter any issues, check CloudFormation console or try 'eksctl utils describe-stacks --region=us-east-1 --cluster=dev-eks-kubeflow'
[ℹ]  CloudWatch logging will not be enabled for cluster "dev-eks-kubeflow" in "us-east-1"
[ℹ]  you can enable it with 'eksctl utils update-cluster-logging --region=us-east-1 --cluster=dev-eks-kubeflow'
[ℹ]  Kubernetes API endpoint access will use default of {publicAccess=true, privateAccess=false} for cluster "dev-eks-kubeflow" in "us-east-1"
[ℹ]  2 sequential tasks: { create cluster control plane "dev-eks-kubeflow", 2 sequential sub-tasks: { no tasks, create nodegroup "dev-eks-kubeflow-ng" } }
[ℹ]  building cluster stack "eksctl-dev-eks-kubeflow-cluster"
[ℹ]  deploying stack "eksctl-dev-eks-kubeflow-cluster"
[✖]  unexpected status "ROLLBACK_IN_PROGRESS" while waiting for CloudFormation stack "eksctl-dev-eks-kubeflow-cluster"
[ℹ]  fetching stack events in attempt to troubleshoot the root cause of the failure
[✖]  AWS::EC2::SubnetRouteTableAssociation/RouteTableAssociationPrivateUSEAST1C: CREATE_FAILED – "Resource creation cancelled"
[✖]  AWS::EC2::SubnetRouteTableAssociation/RouteTableAssociationPublicUSEAST1E: CREATE_FAILED – "Resource creation cancelled"
[✖]  AWS::EC2::SubnetRouteTableAssociation/RouteTableAssociationPrivateUSEAST1E: CREATE_FAILED – "Resource creation cancelled"
[✖]  AWS::EC2::SubnetRouteTableAssociation/RouteTableAssociationPublicUSEAST1C: CREATE_FAILED – "Resource creation cancelled"
[✖]  AWS::EC2::Route/PublicSubnetRoute: CREATE_FAILED – "Resource creation cancelled"
[✖]  AWS::EC2::NatGateway/NATGateway: CREATE_FAILED – "Resource creation cancelled"
[✖]  AWS::EKS::Cluster/ControlPlane: CREATE_FAILED – "Cannot create cluster 'dev-eks-kubeflow' because us-east-1e, the targeted availability zone, does not currently have sufficient capacity to support the cluster. Retry and choose from these availability zones: us-east-1a, us-east-1b, us-east-1c, us-east-1d, us-east-1f (Service: AmazonEKS; Status Code: 400; Error Code: UnsupportedAvailabilityZoneException; Request ID: 514f7850-38c3-4ecb-8bc6-860d1852d673)"
[!]  1 error(s) occurred and cluster hasn't been created properly, you may wish to check CloudFormation console
[ℹ]  to cleanup resources, run 'eksctl delete cluster --region=us-east-1 --name=dev-eks-kubeflow'
[✖]  waiting for CloudFormation stack "eksctl-dev-eks-kubeflow-cluster": ResourceNotReady: failed waiting for successful resource state
Error: failed to create cluster "dev-eks-kubeflow"
make: *** [cluster] Error 1
❯ eksctl delete cluster --region=us-east-1 --name=dev-eks-kubeflow
[ℹ]  eksctl version 0.24.0
[ℹ]  using region us-east-1
Error: checking AWS STS access – cannot get role ARN for current session: ExpiredToken: The security token included in the request is expired
        status code: 403, request id: 75256e9d-0710-4b8d-a615-d5c3d21612f3
❯ awst default 920183
Saved default credentials to /Users/seizadi/.aws/credentials
❯ eksctl delete cluster --region=us-east-1 --name=dev-eks-kubeflow
[ℹ]  eksctl version 0.24.0
[ℹ]  using region us-east-1
[ℹ]  deleting EKS cluster "dev-eks-kubeflow"
Error: fetching cluster status to determine if it can be deleted: unable to describe cluster control plane: ResourceNotFoundException: No cluster found for name: dev-eks-kubeflow.
{
  RespMetadata: {
    StatusCode: 404,
    RequestID: "151dafb1-0536-475e-97ed-97564283ef9a"
  },
  Message_: "No cluster found for name: dev-eks-kubeflow."
}
```
### Kubeflow fails to install when Istio is already installed on Cluster
```bash
WARN[0082] Encountered error applying application istio-install:  (kubeflow.error): Code 500 with message: Apply.Run  Error [error when applying patch:
{"metadata":{"annotations":{"kubectl.kubernetes.io/last-applied-configuration":"{\"apiVersion\":\"apps/v1\",\"kind\":\"Deployment\",\"metadata\":{\"annotations\":{},\"labels\":{\"app\":\"grafana\",\"chart\":\"grafana\",\"heritage\":\"Tiller\",\"release\":\"istio\"},\"name\":\"grafana\",\"namespace\":\"istio-system\"},\"spec\":{\"replicas\":1,\"selector\":{\"matchLabels\":.
```
The fix is to remove istio-crds and istio-install from kfctl_aws_cognito.v1.0.2.yaml.in
so that kfctl will skip them, see 
[disable Istio on install](https://www.kubeflow.org/docs/started/k8s/kfctl-k8s-istio/#before-you-start):
```yaml
  applications:
# Remove since we already have Istio installed
#  - kustomizeConfig:
#      parameters:
#      - name: namespace
#        value: istio-system
#      repoRef:
#        name: manifests
#        path: istio/istio-crds
#    name: istio-crds
#  - kustomizeConfig:
#      parameters:
#      - name: namespace
#        value: istio-system
#      repoRef:
#        name: manifests
#        path: istio/istio-install
#    name: istio-install
```
### Kubeflow generates larege files for GitHub
Look at what is checked in and maybe add items to .gitignore
```bash
❯ git push
Enumerating objects: 24, done.
Counting objects: 100% (24/24), done.
Delta compression using up to 16 threads
Compressing objects: 100% (12/12), done.
Writing objects: 100% (13/13), 29.04 MiB | 2.52 MiB/s, done.
Total 13 (delta 7), reused 0 (delta 0), pack-reused 0
remote: Resolving deltas: 100% (7/7), completed with 7 local objects.
remote: warning: GH001: Large files detected. You may want to try Git Large File Storage - https://git-lfs.github.com.
remote: warning: See http://git.io/iEPt8g for more information.
remote: warning: File go_build_main_go is 93.88 MB; this is larger than GitHub's recommended maximum file size of 50.00 MB
To github.com:seizadi/kubeflow-aws-cognito.git
   be16918..3dc67ac  master -> master
```

### Debug Web Client Inteface
Had issue where Cognito Identity worked but when it redirected to
kubeflow.platform.seizadi.com the connection timed-out.

Looking at the AWS Loadbalancer, it looks like a classic is setup
for all instances here is the table:

| LB Protocol | LB Port | EC2 Protocol | EC2 Port | Cipher | CERT |
| ----------- | ------- | ------------ | -------- | ------ | ---- |
| TCP         | 15443   | TCP          | 32224    | N/A    | N/A  |
| TCP         | 15032   | TCP          | 32062    | N/A    | N/A  |
| TCP         | 15031   | TCP          | 31009    | N/A    | N/A  |
| TCP         | 15030   | TCP          | 32603    | N/A    | N/A  |
| TCP         | 15029   | TCP          | 30058    | N/A    | N/A  |
| TCP         | 31400   | TCP          | 31400    | N/A    | N/A  |
| TCP         | 443     | TCP          | 31390    | N/A    | N/A  |
| TCP         | 80      | TCP          | 31380    | N/A    | N/A  |
| TCP         | 15020   | TCP          | 31945    | N/A    | N/A  |

Now look to make sure Istion Gateway is setup:
```bash
kubectl get svc istio-ingressgateway -n istio-system
NAME                   TYPE           CLUSTER-IP      EXTERNAL-IP                                                              PORT(S)                                                                                                                                      AGE
istio-ingressgateway   LoadBalancer   10.100.25.144   af2d............................-80.......us-east-1.elb.amazonaws.com   15020:31945/TCP,80:31380/TCP,443:31390/TCP,31400:31400/TCP,15029:30058/TCP,15030:32603/TCP,15031:31009/TCP,15032:32062/TCP,15443:32224/TCP   3d1h
```

So that part looks good and we can look further into the cluster.
Now looking at the cluster to see how things are wired:
```bash
kubectl get svc --all-namespaces -o json | jq '.items[] | {name:.metadata.name, namespace: .metadata.namespace, p:.spec.ports[], s:.spec.selector } | select( .p.nodePort != null ) | "\(.name):\(.namespace) localhost:\(.p.nodePort) -> \(.p.port) -> \(.p.targetPort) selector:\(.s)"'
"istio-ingressgateway:istio-system localhost:31945 -> 15020 -> 15020 selector:{\"app\":\"istio-ingressgateway\",\"istio\":\"ingressgateway\",\"release\":\"istio\"}"
"istio-ingressgateway:istio-system localhost:31380 -> 80 -> 80 selector:{\"app\":\"istio-ingressgateway\",\"istio\":\"ingressgateway\",\"release\":\"istio\"}"
"istio-ingressgateway:istio-system localhost:31390 -> 443 -> 443 selector:{\"app\":\"istio-ingressgateway\",\"istio\":\"ingressgateway\",\"release\":\"istio\"}"
"istio-ingressgateway:istio-system localhost:31400 -> 31400 -> 31400 selector:{\"app\":\"istio-ingressgateway\",\"istio\":\"ingressgateway\",\"release\":\"istio\"}"
"istio-ingressgateway:istio-system localhost:30058 -> 15029 -> 15029 selector:{\"app\":\"istio-ingressgateway\",\"istio\":\"ingressgateway\",\"release\":\"istio\"}"
"istio-ingressgateway:istio-system localhost:32603 -> 15030 -> 15030 selector:{\"app\":\"istio-ingressgateway\",\"istio\":\"ingressgateway\",\"release\":\"istio\"}"
"istio-ingressgateway:istio-system localhost:31009 -> 15031 -> 15031 selector:{\"app\":\"istio-ingressgateway\",\"istio\":\"ingressgateway\",\"release\":\"istio\"}"
"istio-ingressgateway:istio-system localhost:32062 -> 15032 -> 15032 selector:{\"app\":\"istio-ingressgateway\",\"istio\":\"ingressgateway\",\"release\":\"istio\"}"
"istio-ingressgateway:istio-system localhost:32224 -> 15443 -> 15443 selector:{\"app\":\"istio-ingressgateway\",\"istio\":\"ingressgateway\",\"release\":\"istio\"}"
"kfserving-ingressgateway:istio-system localhost:31709 -> 15020 -> 15020 selector:{\"app\":\"kfserving-ingressgateway\",\"kfserving\":\"ingressgateway\"}"
"kfserving-ingressgateway:istio-system localhost:32380 -> 80 -> 80 selector:{\"app\":\"kfserving-ingressgateway\",\"kfserving\":\"ingressgateway\"}"
"kfserving-ingressgateway:istio-system localhost:32390 -> 443 -> 443 selector:{\"app\":\"kfserving-ingressgateway\",\"kfserving\":\"ingressgateway\"}"
"kfserving-ingressgateway:istio-system localhost:32400 -> 31400 -> 31400 selector:{\"app\":\"kfserving-ingressgateway\",\"kfserving\":\"ingressgateway\"}"
"kfserving-ingressgateway:istio-system localhost:30299 -> 15011 -> 15011 selector:{\"app\":\"kfserving-ingressgateway\",\"kfserving\":\"ingressgateway\"}"
"kfserving-ingressgateway:istio-system localhost:32560 -> 8060 -> 8060 selector:{\"app\":\"kfserving-ingressgateway\",\"kfserving\":\"ingressgateway\"}"
"kfserving-ingressgateway:istio-system localhost:32021 -> 853 -> 853 selector:{\"app\":\"kfserving-ingressgateway\",\"kfserving\":\"ingressgateway\"}"
"kfserving-ingressgateway:istio-system localhost:31285 -> 15029 -> 15029 selector:{\"app\":\"kfserving-ingressgateway\",\"kfserving\":\"ingressgateway\"}"
"kfserving-ingressgateway:istio-system localhost:32186 -> 15030 -> 15030 selector:{\"app\":\"kfserving-ingressgateway\",\"kfserving\":\"ingressgateway\"}"
"kfserving-ingressgateway:istio-system localhost:31045 -> 15031 -> 15031 selector:{\"app\":\"kfserving-ingressgateway\",\"kfserving\":\"ingressgateway\"}"
"kfserving-ingressgateway:istio-system localhost:30753 -> 15032 -> 15032 selector:{\"app\":\"kfserving-ingressgateway\",\"kfserving\":\"ingressgateway\"}"
"kfserving-ingressgateway:istio-system localhost:31160 -> 15443 -> 15443 selector:{\"app\":\"kfserving-ingressgateway\",\"kfserving\":\"ingressgateway\"}"
"argo-ui:kubeflow localhost:32243 -> 80 -> 8001 selector:{\"app\":\"argo-ui\",\"app.kubernetes.io/component\":\"argo\",\"app.kubernetes.io/instance\":\"argo-v2.3.0\",\"app.kubernetes.io/managed-by\":\"kfctl\",\"app.kubernetes.io/name\":\"argo\",\"app.kubernetes.io/part-of\":\"kubeflow\",\"app.kubernetes.io/version\":\"v2.3.0\",\"kustomize.component\":\"argo\"}"
```

Look at Istion Gateway equivalent of tradition Ingress:
```bash
kubectl get gateway --all-namespaces -o json | jq '.items[] | {name:.metadata.name, namespace: .metadata.namespace, serv:.spec.servers[], sel:.spec.selector } | "\(.name):\(.namespace) selector:\(.sel) servers:\(.serv)"'
"cluster-local-gateway:knative-serving selector:{\"istio\":\"cluster-local-gateway\"} servers:{\"hosts\":[\"*\"],\"port\":{\"name\":\"http\",\"number\":80,\"protocol\":\"HTTP\"}}"
"knative-ingress-gateway:knative-serving selector:{\"app\":\"kfserving-ingressgateway\",\"kfserving\":\"ingressgateway\"} servers:{\"hosts\":[\"*\"],\"port\":{\"name\":\"http\",\"number\":80,\"protocol\":\"HTTP\"}}"
"kubeflow-gateway:kubeflow selector:{\"istio\":\"ingressgateway\"} servers:{\"hosts\":[\"*\"],\"port\":{\"name\":\"http\",\"number\":80,\"protocol\":\"HTTP\"}}"
```

At the end could not find a rule to terminate TLS on Ingress gateway,

It seems that it should happen on AWS LB, so I manually configured that and also found that port 80 was open so I closed it,
there is a AWS Classic LB configured not ALB, but if I switch to ALB I would redirect port 80 (HTTP) to 443 (HTTPS).

```bash
Load Balancer Protocol: HTTPS
Load Balancer Port: 443
Instance Protocol: HTTP
Instance Port: 31390
Cipher: Change
SSL Certificate: 46.... (ACM) Change 
``` 

Now we can see the dashboard but Cognito user credentials are not passed to Kubeflow, see next issue.

### Can login without credentials as anonymous user

When you login you see:
```bash
User None is not authorized to list kubeflow.org.v1alpha1.poddefaults for namespace: anonymous
```
I referenced this document on [Kubeflow AuthN/AuthZ](https://www.kubeflow.org/docs/aws/authentication/).

This is how it is suppose to work:

After ALB load balancer authenticates a user successfully, it sends the user claims received from the IdP 
to the target. The load balancer signs the user claim so that applications can verify the signature and 
verify that the claims were sent by the load balancer. Applications that require the full user claims can 
use any standard JWT library to verify the JWT tokens.

Header x-amzn-oidc-data stores user claims, in JSON web tokens (JWT) format. In order to create a 
kubeflow-userid header, we create aws-istio-authz-adaptor which is an isito route directive adpater. 
It modifies traffic metadata using operation templates on the request and response headers. 
In this case, we decode JWT token x-amzn-oidc-data and retrieve user claim, 
then append a new header to user’s requests. Here is the 
[AWS Blog on it](https://aws.amazon.com/blogs/aws/built-in-authentication-in-alb/)

Right now I don't have ALB but Classic LB so not sure that happened and whether I have to manually
set this up or there is automation that is not configured.

See this [Kubeflow multi-user AuthZ](https://github.com/kubeflow/kubeflow/issues/4761)
See this [Kbeflow AWS multi-user AuthZ](https://github.com/kubeflow/manifests/pull/908)

Looks like AWS AuthZ plugin is installed:
```bash
k get deploy --all-namespaces | fgrep authzadaptor
istio-system           authzadaptor                                         1/1     1            1           3d8h
```

Logged [this issue](https://github.com/kubeflow/kubeflow/issues/5196) to track this problem. The
resolution was to set the cluster name in ALB manifest in the file
[param.env](https://github.com/kubeflow/manifests/blob/master/aws/aws-alb-ingress-controller/base/params.env).


### Debug Model 
In the [guide](https://www.kubeflow.org/docs/aws/aws-e2e/#deploy-models) 
they show how to apply models:
```bash
kubectl apply -f https://raw.githubusercontent.com/kubeflow/kfserving/master/docs/samples/tensorflow/tensorflow.yaml
kubectl apply -f https://raw.githubusercontent.com/kubeflow/kfserving/master/docs/samples/pytorch/pytorch.yaml
kubectl apply -f https://raw.githubusercontent.com/kubeflow/kfserving/master/docs/samples/sklearn/sklearn.yaml
```
There is a cryptic example of how to do a post call with reference
to Web cookie,
```bash
POST https://sklearn-iris-predictor-default.default.platform.domain.com/v1/models/sklearn-iris:predict HTTP/1.1
Host: sklearn-iris-predictor-default.default.platform.domain.com
Content-Type: application/json
Cookie: AWSELBAuthSessionCookie-0=TBLc8+Mz0hSZp...

{
  "instances": [
    [6.8,  2.8,  4.8,  1.4],
    [6.0,  3.4,  4.5,  1.6]
  ]
}
```

First make sure the model serving label is enabled for your namespace, this is typically the case
but good to check:
```bash
kubectl describe namespace seizadi

Name:         seizadi
Labels:       istio-injection=enabled
              katib-metricscollector-injection=enabled
              serving.kubeflow.org/inferenceservice=enabled
....
```
You want 'serving.kubeflow.org/inferenceservice=enabled' in the namespace. If it is not
enabled you can enable it:
```bash
kubectl label namespace kubeflow serving.kubeflow.org/inferenceservice=enabled
```

You should apply the model to your namespace:
```bash
kubectl apply -n kubeflow -f https://raw.githubusercontent.com/kubeflow/kfserving/master/docs/samples/sklearn/sklearn.yaml
```
You should have a model now being served in your namespace:
```bash
 k get InferenceService
NAME           URL                                                                       READY   DEFAULT TRAFFIC   CANARY TRAFFIC   AGE
sklearn-iris   http://sklearn-iris.seizadi.platform.sexample.com/v1/models/sklearn-iris   True    100                                23s
```

If you have problems at this level this is a 
[guide on debugging KF-Serving Model](https://github.com/kubeflow/kfserving/blob/master/docs/KFSERVING_DEBUG_GUIDE.md) 

Note that the URL for accessing this model has the namespace sandwiched in the path
so your path will vary depending on what namespace the model is served. Also when you
are using your login credentials you will need the cookies that give you access to your
namwspace.

You need to use this unique URL in your request header to specify the HOST:
```bash
kubectl get -n seizadi inferenceservice sklearn-iris -o jsonpath='{.status.url}' | cut -d "/" -f 3
sklearn-iris.seizadi.platform.sexample.com
```

```bash
 kubectl get -n seizadi inferenceservices
NAME           URL                                                                       READY   DEFAULT TRAFFIC   CANARY TRAFFIC   AGE
sklearn-iris   http://sklearn-iris.seizadi.platform.example.com/v1/models/sklearn-iris   True    100                                31h
```

The cookies are long and difficult to work with curl so I decided to use python
to make the requests for testing...

```python
import requests

# api-endpoint 
url = 'https://kubeflow.platform.example.com/pipeline/apis/v1beta1/pipelines?page_token=&page_size=10&sort_by=created_at%20desc&filter='

cookies = {'AWSELBAuthSessionCookie-0': 'xxxxxx'
           'AWSELBAuthSessionCookie-1': 'xxxxxx'
          }

r = requests.get(url=url, cookies=cookies)
result = r.json()
```

This should work since it is what the Kubeflow UI uses for pipeline API. This tests to
make sure you have the cookies properly captured from browser session.

Now we test the kfserving:
```python
url = 'https://kubeflow.platform.example.com/v1/models/sklearn-iris:predict'

headers={'Host': 'sklearn-iris.seizadi.platform.sexample.com'}
# data to be sent to api 
data = { 'instances': [ [6.8,  2.8,  4.8,  1.4], [6.0,  3.4,  4.5,  1.6] ] } 

r = requests.post(url=url, cookies=cookies, data=data, headers=headers)

print(r)
```

This request returns 404 error. The log from istio-system namespace istio-gateway
show that the wrong endpoint used, when I hit the kubeflow endpoint and returns 404

```bash
[2020-10-22T02:11:42.455Z] "POST /v1/models/sklearn-iris:predict HTTP/1.1" 404 - "-" 111 170 4 1 "73.241.144.80,192.168.68.197" "python-requests/2.24.0" "44bfcc13-45d1-9d97-b207-b75504c24fe3" "sklearn-iris.seizadi.platform.example.com" "192.168.11.138:8082" outbound|80||centraldashboard.kubeflow.svc.cluster.local - 192.168.80.224:80 192.168.68.197:6436 -
```

Sicne we have routing problem, this is a good guide to show the
[flow of requests:](https://github.com/kubeflow/kfserving/blob/master/docs/KFSERVING_DEBUG_GUIDE.md#debug-kfserving-request-flow)

To debug lets start at serving namespace and follow it:
```bash
❯ k -n seizadi get vs
NAME                                   GATEWAYS                                                                          HOSTS                                                                                                                                                                                                      AGE
notebook-seizadi-kubecon-tutorial      [kubeflow/kubeflow-gateway]                                                       [*]                                                                                                                                                                                                        16d
notebook-seizadi-kubeflow-end-to-end   [kubeflow/kubeflow-gateway]                                                       [*]                                                                                                                                                                                                        6d16h
sklearn-iris                           [knative-ingress-gateway.knative-serving]                                         [sklearn-iris.seizadi.platform.sexample.com]                                                                                                                                                                2d19h
sklearn-iris-predictor-default         [knative-serving/cluster-local-gateway knative-serving/knative-ingress-gateway]   [sklearn-iris-predictor-default.seizadi sklearn-iris-predictor-default.seizadi.platform.sexample.com sklearn-iris-predictor-default.seizadi.svc sklearn-iris-predictor-default.seizadi.svc.cluster.local]   2d19h
sklearn-iris-predictor-default-mesh    [mesh]                                                                            [sklearn-iris-predictor-default.seizadi sklearn-iris-predictor-default.seizadi.svc sklearn-iris-predictor-default.seizadi.svc.cluster.local] 
```
lets look at the ingress point and the gateway that is used:
```bash
❯ k -n seizadi get vs sklearn-iris -o json | jq -r ".spec.gateways"
[
  "knative-ingress-gateway.knative-serving"
]
```

Looking at the Gateway:
```bash
❯ kubectl get gateway knative-ingress-gateway -n knative-serving -oyaml
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  annotations:
    kubectl.kubernetes.io/last-applied-configuration: |
      {"apiVersion":"networking.istio.io/v1alpha3","kind":"Gateway","metadata":{"annotations":{},"labels":{"app.kubernetes.io/component":"knative-serving-install","app.kubernetes.io/instance":"knative-serving-install-v0.11.1","app.kubernetes.io/managed-by":"kfctl","app.kubernetes.io/name":"knative-serving-install","app.kubernetes.io/part-of":"kubeflow","app.kubernetes.io/version":"v0.11.1","kustomize.component":"knative","networking.knative.dev/ingress-provider":"istio"},"name":"knative-ingress-gateway","namespace":"knative-serving"},"spec":{"selector":{"app":"kfserving-ingressgateway","kfserving":"ingressgateway"},"servers":[{"hosts":["*"],"port":{"name":"http","number":80,"protocol":"HTTP"}}]}}
  creationTimestamp: "2020-08-03T19:52:14Z"
  generation: 1
  labels:
    app.kubernetes.io/component: knative-serving-install
    app.kubernetes.io/instance: knative-serving-install-v0.11.1
    app.kubernetes.io/managed-by: kfctl
    app.kubernetes.io/name: knative-serving-install
    app.kubernetes.io/part-of: kubeflow
    app.kubernetes.io/version: v0.11.1
    kustomize.component: knative
    networking.knative.dev/ingress-provider: istio
  name: knative-ingress-gateway
  namespace: knative-serving
  resourceVersion: "4951"
  selfLink: /apis/networking.istio.io/v1alpha3/namespaces/knative-serving/gateways/knative-ingress-gateway
  uid: 9c6b86ec-c843-410e-b963-922fe3106a0b
spec:
  selector:
    app: kfserving-ingressgateway
    kfserving: ingressgateway
  servers:
  - hosts:
    - '*'
    port:
      name: http
      number: 80
      protocol: HTTP
```
It seems our problem  might be related to similar 
[issue with GCP IAP](https://github.com/kubeflow/kfserving/issues/824) where there is
single Kubeflow endpoint that provides authentication and uses routes. The kfserving
endpoint requires Host based routing and has a seperate gateway. This is a gap that
is identified in the 
[GCP IAP Guide](https://github.com/kubeflow/kfserving/tree/master/docs/samples/gcp-iap#expose-the-inference-service-externally-using-an-additional-istio-virtual-service)

I [logged an issue](https://github.com/kubeflow/kfserving/issues/1154) 
and the recommendation was to upgrade from Kubeflow 1.0.2 to 1.1.0
release to fix the problem. Looks this will not in anycase have AuthZ that is gap
in kfserving for production, you can disable AuthZ to have it work with AuthN.

Create a new cluster to debug the fix from issue above, ran into 
[another issue](https://github.com/kubeflow/kubeflow/issues/5370#issuecomment-722053414)
on AWS Cognito 1.1.0. 

Now will the issue resolved can work on bringing up kfserving on kubeflow.
We will need to follow a similar pattern as for 
[GCloud IAP](https://github.com/kubeflow/kfserving/tree/master/docs/samples/gcp-iap).
There are no docs for AWS Cognito yet.

The kfserving model does not support AuthZ yet, so we need to turn
Istio side-car off as in in this manifest,
[sklearn-iap-no-authz.yaml](https://github.com/kubeflow/kfserving/blob/master/docs/samples/gcp-iap/sklearn-iap-no-authz.yaml)
```yaml
    sidecar.istio.io/inject: "false"
```
Note ***Warning***: The sklearn-iap-no-authz.yaml has an annotation that prevents 
the istio sidecar from being injected and thus disables istio RBAC authorization. 
This is unlikely to be suitable for production.

I'm not sure we will need to remove the side-car as I don't know how AuthZ is setup
with Cognito, as ther there is some access to the namespace for notebook server.

So I will start by setting up the Virtual Service.
The Virtual Service will match on a path-based route (required by AWS ALB/Cognito),
template is: https://<Ingress_DNS>/kfserving/<namespace>/sklearn-iap:predict,
such as: kubeflow.platform.sexample.com/kfserving/seizadi/sklearn-iap:predict
and will forward to cluster-local-gateway whilst rewriting host and uri. 
The uri is then a host based route as expected by kfserving:
template: https://sklearn-iap-predictor-default.<namespace>.svc.cluster.local/v1/models/sklearn-iap:predict,
such as: https://sklearn-iap-predictor-default.eizadi.svc.cluster.local/v1/models/sklearn-iap:predict.

We will use the 
[virual service example]()
```yaml
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: kfserving-iap
spec:
  gateways:
  - kubeflow/kubeflow-gateway
  hosts:
  - '*'
  http:
  - match:
    - uri:
        prefix: /kfserving/seizadi/sklearn-iap
    route:
    - destination:
        host: cluster-local-gateway.istio-system.svc.cluster.local
      headers:
        request:
          set:
            Host: sklearn-iap-predictor-default.seizadi.svc.cluster.local
      weight: 100
    rewrite:
        uri: /v1/models/sklearn-iap
    timeout: 300s
```
Then apply:
```bash
❯ k apply -f deploy/kfserving_seizadi_virtual_service.yaml
virtualservice.networking.istio.io/kfserving-iap created
```

Now instead of 404 error, I'm getting 400 error and it is routed correctly
to the kfserving pod for prediction:
```bash
❯ k logs sklearn-iap-predictor-default-stx69-deployment-5844ff4b5c-ttbnc kfserving-container
[I 201106 00:52:49 storage:35] Copying contents of /mnt/models to local
[I 201106 00:52:49 kfserver:88] Registering model: sklearn-iap
[I 201106 00:52:49 kfserver:77] Listening on port 8080
[I 201106 00:52:49 kfserver:79] Will fork 0 workers
[I 201106 00:52:49 process:126] Starting 4 processes
[W 201106 00:59:07 web:2250] 400 POST /v1/models/sklearn-iap:predict (127.0.0.1) 1.28ms
[W 201106 00:59:39 web:2250] 400 POST /v1/models/sklearn-iap:predict (127.0.0.1) 1.31ms
```
The error from client is: "", which comes from the 
[kfserving json decoder](https://github.com/kubeflow/kfserving/blob/master/python/kfserving/kfserving/handlers/http.py#L55)
```bash
        except json.decoder.JSONDecodeError as e:
            raise tornado.web.HTTPError(
                status_code=HTTPStatus.BAD_REQUEST,
                reason="Unrecognized request format: %s" % e
            )
```

To debug this I run tcpdump on the predictor container:
```bash
kubectl -n seizadi exec -it sklearn-iap-predictor-default-qgdh6-deployment-79bfd469cd-bn5rz -- /bin/bash
```
Install tcpdump and capture:
```bash
apt-get update
apt-get install tcpdump
tcpdump -s 0 -n -w /tmp/sklearn.pcap
```
Now load it to your laptop and use something friendly like WireShark to look at it:
```bash
kubectl cp seizadi/sklearn-iap-predictor-default-qgdh6-deployment-79bfd469cd-bn5rz:/tmp/sklearn.pcap ~/Downloads/sklearn.pcap
```
Updated the client script to send JSON and the POST request work now:
```bash
{"predictions": [1, 1]}
```


# Kubeflow Authentication and Authorization Prototype

***TODO*** Work on this approach versus Cognito

This implementation's target platforms are Kubernetes clusters with access to modify Kubernetes' API config file, which is generally possible with on Premise installations of Kubernetes.

**Note**: This setup assumes Kubeflow Pipelines is setup in namespace kubeflow and Istio is already setup in the Kubernetes cluster.

## High Level Diagram
![Authentication and Authorization in Kubeflow](/docs/dex-auth/assets/auth-istio.png)


## Create SSL Certificates

This example is going to require three domains:  
- dex.example.org: For the authentication server
- login.example.org: For the client application for authentication through dex (optional)
- ldap-admin.example.org: For the admin interface to create LDAP users and groups (optional)

**Note**: Replace *example.org* with your own domain.  

With your trusted certificate signing authority, please create a certificate for the above domains.

### Why Self Signed SSL Certs will not work

Authentication through OIDC in Kubernetes does work with self signed certificates since the `--oidc-ca-file` parameter in the Kubernetes API server allows for adding a trusted CA for your authentication server.

Though Istio's authentication policy parameter `jwksUri` for [End User Authentication](https://istio.io/docs/ops/security/end-user-auth/) does [not allow self signed certificates](https://github.com/istio/istio/issues/7290#issuecomment-420748056).

Please generate certificates with a trusted authority for enabling this example or follow this [work-around](#work-around-a-way-to-use-self-signed-certificates).

## Server Setup Instructions

### Authentication Server Setup

#### Setup Post Certificate Creation

*TODO*(krishnadurai): Make this a part of kfctl

`kubectl create namespace auth`

*Note*: This step is not required if you disable TLS in Dex configuration

`kubectl create secret tls dex.platform.sexample.com.tls --cert=ssl/cert.pem --key=ssl/key.pem -n auth`

Replace `dex.example.com.tls` with your own domain.

#### Parameterizing the setup

##### Variables in params environment files [dex-authenticator](dex-authenticator/base/params.env), [dex-crds](dex-crds/base/params.env) and [istio](/docs/dex-auth/examples/authentication/Istio):
 - dex_domain: Domain for your dex server
 - issuer: Issuer URL for dex server
 - static_email: User Email for staticPasswords configuration
 - static_password_hash: User's password for staticPasswords configuration
 - static_user_id: User id for staticPasswords configuration
 - static_username: Username for for staticPasswords configuration
 - ldap_host: URL for LDAP server for dex to connect to
 - ldap_bind_dn: LDAP Overlay's bind distinguished name (DN)
 - ldap_bind_pw: LDAP Overlay's bind password for the above account
 - ldap_user_base_dn: LDAP Server's user base DN
 - ldap_group_base_dn: LDAP Server's group base DN
 - dex_client_id: ID for the dex client application
 - oidc_redirect_uris: Redirect URIs for OIDC client callback
 - dex_application_secret: Application secret for dex client
 - jwks_uri: URL pointing to the hosted JWKS keys
 - cluster_name: Name for your Kubernetes Cluster for dex to refer to
 - dex_client_redirect_uri: Single redirect URI for OIDC client callback
 - k8s_master_uri: Kubernetes API master server's URI
 - dex_client_listen_addr: Listen address for dex client to login

 **Keycloak Gatekeeper variables in params [environment file](keycloak-gatekeeper/base/params.env):**

 - client_id: ID for the authentication proxy client application
 - client_secret: Application secret for authentication client
 - secure_cookie: Set to true for TLS based cookie
 - discovery_url: Is the url for retrieve the openid configuration - normally the <server>/auth/realm/<realm_name>
 - upstream_url: The upstream endpoint which we should proxy request
 - redirection_url: The redirection url, essentially the site url, note: /oauth/callback is added at the end
 - encryption_key: The encryption key used to encode the session state

##### Certificate files:

*Identity Provider (Dex) CA file:*

This is the CA cert generated for Dex.

```
kubectl create configmap ca --from-file=ca.pem -n auth
```

*Kubernetes API Server CA file:*

This is the CA cert for your Kubernetes cluster generated while installing Kubernetes.

```
kubectl create configmap k8s-ca --from-file=k8s_ca.pem -n auth
```

##### This kustomize configs sets up:
 - A Dex server with LDAP IdP and a client application (dex-k8s-authenticator) for issuing keys for Dex.

#### Apply Kustomize Configs

**LDAP**

```
cd dex-ldap
kustomize build base | kubectl apply -f -
```

**Dex**

*For staticPassword configuration:*
```
cd dex-crds
kustomize build base | kubectl apply -f -
```

*For LDAP configuration:*
```
cd dex-crds
kustomize build overlays/ldap | kubectl apply -f -
```

**Dex Kubernetes Authentication Client**

```
cd dex-authenticator
kustomize build base | kubectl apply -f -
```

**Keycloak Gatekeeper (Proxy) Authentication Client**

```
cd keycloak-gatekeeper
kustomize build base | kubectl apply -f -
```

### Setup Kubernetes OIDC Authentication

The following parameters need to be set in Kubernetes API Server configuration file usually found in: `/etc/kubernetes/manifests/kube-apiserver.yaml`.

- --oidc-issuer-url=https://dex.example.org:32000
- --oidc-client-id=ldapdexapp
- --oidc-ca-file=/etc/ssl/certs/openid-ca.pem
- --oidc-username-claim=email
- --oidc-groups-claim=groups

`oidc-ca-file` needs to have the path to the file containing the certificate authority for the dex server's domain: dex.example.com.

Refer [official documentation](https://kubernetes.io/docs/reference/access-authn-authz/authentication/#configuring-the-api-server) for meanings of these parameters.

When you have added these flags, Kubernetes should restart kube-apiserver pod. If not, run this command: `sudo systemctl restart kubelet` in your Kubernetes API Server master node. You can check flags in the pod description:

`kubectl describe pod kube-apiserver -n kube-system`


## Work-around: A way to use Self-Signed Certificates

* Execute `examples/gencert.sh` on your terminal and it should create a folder `ssl` containing all required self signed certificates.

* Copy the JWKS keys from `https://dex.example.com/keys` and host these keys in a public repository as a file. This public repository should have a verified a https SSL certificate (for e.g. github).

* Copy the file url from the public repository in the `jwks_uri` parameter for [Istio Authentication Policy](/docs/dex-auth/examples/authentication/Istio/params.env) config:

```
jwks_uri="https://raw.githubusercontent.com/example-organisation/jwks/master/auth-jwks.json"
```

* Note that this is just a work around and JWKS keys are rotated by the Authentication Server. These JWKS keys will become invalid after the rotation period and you will have to re-upload the new keys back to your public repository.

