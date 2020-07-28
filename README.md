# eksctl

## Prerequisites
   You'll need the following tools installed locally:
   
   * AWS CLI
   * git
   * jq
   * kubectl
   * eksctl
   * fluxctl
   * kustomize

## Build

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

```bash
make mesh
....
Cloning into '/var/folders/49/3pxhjsps4fx4q21nkbj1j6n00000gp/T/appmesh-820023803'...
....
Branch 'demo' set up to track remote branch 'demo' from 'origin'.
Switched to a new branch 'demo'
....
Total 29 (delta 5), reused 0 (delta 0)
remote: Resolving deltas: 100% (5/5), done.        
To github.com:seizadi/appmesh
   edae2f8..5f2f37b  master -> master
# Flux does a git-cluster reconciliation every five minutes,
# the following command can be used to speed up the synchronization.
fluxctl sync --k8s-fwd-ns flux
Synchronizing with ssh://git@github.com/seizadi/appmesh
Revision of master to apply is 5f2f37b
Waiting for 5f2f37b to be applied ...
Done.
```
At this point everything should be deployed, you can check the helmreleases CRD in the appmesh-system namespace.
The prometheus metrics-server is deployed in kube-system. There is also appmesh CRD you can check the status of the
service mesh, make sure it is active:
```bash
make status
# kubectl get --watch helmreleases --all-namespaces
kubectl get helmreleases --all-namespaces
NAMESPACE        NAME                 RELEASE              PHASE              STATUS     MESSAGE                                                                             AGE
appmesh-system   appmesh-controller   appmesh-controller   ChartFetchFailed   deployed   Release was successful for Helm release 'appmesh-controller' in 'appmesh-system'.   31h
appmesh-system   appmesh-grafana      appmesh-grafana      Succeeded          deployed   Release was successful for Helm release 'appmesh-grafana' in 'appmesh-system'.      31h
appmesh-system   appmesh-inject       appmesh-inject       ChartFetchFailed   deployed   Release was successful for Helm release 'appmesh-inject' in 'appmesh-system'.       31h
appmesh-system   appmesh-prometheus   appmesh-prometheus   ChartFetchFailed   deployed   Release was successful for Helm release 'appmesh-prometheus' in 'appmesh-system'.   31h
appmesh-system   flagger              flagger              Succeeded          deployed   Release was successful for Helm release 'flagger' in 'appmesh-system'.              31h
kube-system      metrics-server       metrics-server       Succeeded          deployed   Release was successful for Helm release 'metrics-server' in 'kube-system'.          31h
kubectl describe mesh
Name:         seizadi-appmesh
Namespace:    
Labels:       <none>
Annotations:  helm.fluxcd.io/antecedent: appmesh-system:helmrelease/appmesh-inject
              helm.sh/resource-policy: keep
API Version:  appmesh.k8s.aws/v1beta1
Kind:         Mesh
Metadata:
  Creation Timestamp:  2020-05-22T06:40:49Z
  Finalizers:
    meshDeletion.finalizers.appmesh.k8s.aws
  Generation:        1
  Resource Version:  54095
  Self Link:         /apis/appmesh.k8s.aws/v1beta1/meshes/seizadi-appmesh
  UID:               3bc9c3ad-c818-42b4-be0c-e93fd9179c34
Spec:
  Egress Filter:
    Type:                  DROP_ALL
  Service Discovery Type:  dns
Status:
  Mesh Condition:
    Last Transition Time:  2020-05-22T06:41:06Z
    Status:                True
    Type:                  MeshActive
Events:                    <none>
```
## Minikube
In setting this up using eksctl we lose sight of how FluxCD is installed and options.
The [Flux Get Started](https://docs.fluxcd.io/en/1.17.0/tutorials/get-started.html) is
a good starting point for basic setup and 
[Flux Get Started with Helm](https://docs.fluxcd.io/en/1.17.0/tutorials/get-started-helm.html) for
more advanced setup using helm. Here are some notes in addition to the links above for reference.

The basic installation is missing the helm operator:
```bash
kubectl -n flux get pods                                                                      sc-l-seizadi-2.local: Tue Jun  2 20:48:49 2020

NAME                         READY   STATUS    RESTARTS   AGE
flux-9675fbd48-csljf         1/1     Running   0          2m34s
memcached-86bdf9f56b-489cz   1/1     Running   0          2m34s
```
The [detail about fluxctl is here](https://docs.fluxcd.io/en/1.17.1/references/fluxctl.html).
fluxctl can Flux Operator given write access to the repo can update the manifests in the
repo, in some cases the commit will have other changes as it might format the file differently than
the original and will make in some changes more changes to the file than expected, or in some cases
make a commit where you would not expect one.

Some useful fluxctl commands:
To extract the public key used for GitRepo Deploy access:
```bash
fluxctl --k8s-fwd-ns flux identity
```

To display workloads on cluster, 
(workload == Deployments, DaemonSets, StatefulSets and CronJobs):
```bash
fluxctl --k8s-fwd-ns flux list-workloads --all-namespaces
WORKLOAD                          CONTAINER   IMAGE                          RELEASE  POLICY
demo:deployment/podinfo           podinfod    stefanprodan/podinfo:3.1.5     ready    automated
```
You can see that the podinfod workload policy is set to automated. 
There are two strategies for deployment, you can set it to release or automated. The release policy
is for the use case where you want some other tool to control the update to the deployment, e.g.
some workflow engine like Spinnaker, where releases have approval step before pushed to deployment.
If automated is set Flux will deploy a new version of a workload whenever one is available and 
commit the new configuration to the GitRepo.
Automation is enabled by adding the annotation fluxcd.io/automated: "true" to the deployment.

You set automation using:
```bash
fluxctl --k8s-fwd-ns flux automate --workload=demo:deployment/podinfo
```
or turn it off:
```bash
fluxctl --k8s-fwd-ns flux deautomate --workload=demo:deployment/podinfo
```

If automation is turned off you can relase using:
```bash
fluxctl --k8s-fwd-ns flux release --workload=demo:deployment/podinfo --user=seizadi --message="New version" --update-all-images
```
Flux release has options to control if a specific image or all images should be updated and also what to display
for the checkin message for the commit.

Once you have the workloads above you can inspect which versions 
of the image are running:
```bash
fluxctl --k8s-fwd-ns flux list-images --workload demo:deployment/podinfo
```
So lets say you had to rollback to another release you would turn off automation and select a release:
```bash
fluxctl --k8s-fwd-ns flux deautomate --workload=demo:deployment/podinfo
fluxctl --k8s-fwd-ns flux release --workload=demo:deployment/podinfo --update-image=stefanprodan/podinfo:3.3.1 
```
The release command fails with this silent error:
```bash
Submitting release ...
Error: no changes made in repo
```
The annotation I see in podinfo are:
```yaml
    fluxcd.io/tag.podinfod: semver:~3.1
```
So looks like the selected release is violating the tag policy, which causes the error,
 but the error "no changes made in repo" is not very helpful. So this release will work:
```bash
fluxctl --k8s-fwd-ns flux release --workload=demo:deployment/podinfo --update-image=stefanprodan/podinfo:3.1.5
```
There is lock command to stop manual or automated releases to that workload. 
Other changes made in the deployment will still be synced.
```bash
fluxctl --k8s-fwd-ns flux lock --workload=demo:deployment/podinfo
```
This add following annotations to the repo:
```yaml
    fluxcd.io/locked: 'true'
    fluxcd.io/locked_user: Soheil Eizadi <seizadi@gmail.com>
```
You can unlock:
```bash
fluxctl --k8s-fwd-ns flux unlock --workload=demo:deployment/podinfo
```
Now if you know what you are doing you can do this when you get those errors and cross your fingers:
```bash
fluxctl --k8s-fwd-ns flux release --workload=demo:deployment/podinfo --update-image=stefanprodan/podinfo:3.3.1 --force
```
The halth check works:
```bash
kubectl -n demo port-forward deployment/podinfo 9898:9898 &
curl localhost:9898
```
All of the above fluxctl command were updating the policy and are shortcuts for the following policy commands:
```bash
fluxctl policy --k8s-fwd-ns flux --automate --workload=demo:deployment/podinfo
fluxctl policy --k8s-fwd-ns flux --deautomate --workload=demo:deployment/podinfo

fluxctl policy --k8s-fwd-ns flux --lock --workload=demo:deployment/podinfo
fluxctl policy --k8s-fwd-ns flux --unlock --workload=demo:deployment/podinfo
```
Flux has filtering policy
[options for the Image Tags](https://docs.fluxcd.io/en/1.17.1/references/fluxctl.html#image-tag-filtering)
you can create them using:
```bash
fluxctl policy --k8s-fwd-ns flux --workload=demo:deployment/podinfo --tag='podinfod=master-*'
fluxctl policy --k8s-fwd-ns flux --workload=demo:deployment/podinfo --tag='podinfod=semver:~3.3'
```

## Helm setup
You could start from scratch and delete minikube and start it again, trying out just deleting the
flux and demo namespaces to see how well things are isolated.
```bash
kubectl delete ns flux
kubectl delete ns demo
```
flux namespace was recreated, I didn't debug it just started with fresh minikube and
followed [Flux Get Started with Helm](https://docs.fluxcd.io/en/1.17.0/tutorials/get-started-helm.html) 
for setup.

Here I tried a little different path, created a private repo and tired the https with GIT_AUTH key
```bash
kubectl create secret generic flux-git-auth --namespace flux --from-literal=GIT_AUTHUSER=seizadi --from-literal=GIT_AUTHKEY=<token>
helm upgrade -i flux \
--set git.url='https://$(GIT_AUTHUSER):$(GIT_AUTHKEY)@github.com/private-flux.git' \
--set env.secretName=flux-git-auth \
--namespace flux fluxcd/flux
```
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

### AppMesh can not Fetch Chart
The AWS AppMesh opensource 
[troubleshooting guide](https://github.com/aws/aws-app-mesh-controller-for-k8s/blob/master/docs/troubleshoot.md)
is a good reference.

The cluster swith from PHASE 'succeeded' to 'ChartFetchFailed' for some of the services:
```bash
kubectl get helmreleases --all-namespaces
NAMESPACE        NAME                 RELEASE              PHASE       STATUS     MESSAGE                                                                             AGE
appmesh-system   appmesh-controller   appmesh-controller   Succeeded   deployed   Release was successful for Helm release 'appmesh-controller' in 'appmesh-system'.   9h
appmesh-system   appmesh-grafana      appmesh-grafana      Succeeded   deployed   Release was successful for Helm release 'appmesh-grafana' in 'appmesh-system'.      9h
appmesh-system   appmesh-inject       appmesh-inject       Succeeded   deployed   Release was successful for Helm release 'appmesh-inject' in 'appmesh-system'.       9h
appmesh-system   appmesh-prometheus   appmesh-prometheus   Succeeded   deployed   Release was successful for Helm release 'appmesh-prometheus' in 'appmesh-system'.   9h
appmesh-system   flagger              flagger              Succeeded   deployed   Release was successful for Helm release 'flagger' in 'appmesh-system'.              9h
kube-system      metrics-server       metrics-server       Succeeded   deployed   Release was successful for Helm release 'metrics-server' in 'kube-system'.          9h
```
```bash
kubectl get helmreleases --all-namespaces
NAMESPACE        NAME                 RELEASE              PHASE              STATUS     MESSAGE                                                                             AGE
appmesh-system   appmesh-controller   appmesh-controller   ChartFetchFailed   deployed   Release was successful for Helm release 'appmesh-controller' in 'appmesh-system'.   31h
appmesh-system   appmesh-grafana      appmesh-grafana      Succeeded          deployed   Release was successful for Helm release 'appmesh-grafana' in 'appmesh-system'.      31h
appmesh-system   appmesh-inject       appmesh-inject       ChartFetchFailed   deployed   Release was successful for Helm release 'appmesh-inject' in 'appmesh-system'.       31h
appmesh-system   appmesh-prometheus   appmesh-prometheus   ChartFetchFailed   deployed   Release was successful for Helm release 'appmesh-prometheus' in 'appmesh-system'.   31h
appmesh-system   flagger              flagger              Succeeded          deployed   Release was successful for Helm release 'flagger' in 'appmesh-system'.              31h
kube-system      metrics-server       metrics-server       Succeeded          deployed   Release was successful for Helm release 'metrics-server' in 'kube-system'.          31h
```
The appmesh shows 'MeshActive'!!

```bash
$ kubectl logs -n appmesh-system pod/appmesh-controller-54dd6bdfd8-jjrzk
Version: v0.5.0
GitCommit: acc24d6593dc2d62a0146b27cfe24b1ab37c90cb
BuildDate: 2020-04-22T22:05:46Z
GoVersion: go1.13.9
Compiler: gc
Platform: linux/amd64

W0522 06:41:02.560909       1 client_config.go:541] Neither --kubeconfig nor --master was specified.  Using the inClusterConfig.  This might not work.
I0522 06:41:02.562187       1 root.go:146] Running controller with threadiness=5
I0522 06:41:02.562203       1 controller.go:217] Starting controller
I0522 06:41:02.562208       1 controller.go:227] Waiting for informer caches to sync
I0522 06:41:02.662422       1 leaderelection.go:235] attempting to acquire leader lease  appmesh-system/app-mesh-controller-leader...
I0522 06:41:02.672000       1 leaderelection.go:245] successfully acquired lease appmesh-system/app-mesh-controller-leader
I0522 06:41:02.672105       1 controller.go:290] Starting workers
I0522 06:41:02.672151       1 controller.go:299] Started workers
I0522 06:41:06.290618       1 mesh.go:60] Created mesh seizadi-appmesh
W0522 07:10:29.733209       1 reflector.go:302] pkg/mod/k8s.io/client-go@v0.0.0-20190620085101-78d2af792bab/tools/cache/reflector.go:98: watch of *v1beta1.VirtualNode ended with: too old resource version: 53754 (57394)
W0522 09:26:29.685210       1 reflector.go:302] pkg/mod/k8s.io/client-go@v0.0.0-20190620085101-78d2af792bab/tools/cache/reflector.go:98: watch of *v1beta1.VirtualService ended with: too old resource version: 53757 (72613)
W0522 10:06:10.582241       1 reflector.go:302] pkg/mod/k8s.io/client-go@v0.0.0-20190620085101-78d2af792bab/tools/cache/reflector.go:98: watch of *v1beta1.Mesh ended with: too old resource version: 54095 (77025)
```
Looks like the AppMesh controller is running fine.
```bash
$ kubectl -n appmesh-system describe helmrelease appmesh-controller
Name:         appmesh-controller
Namespace:    appmesh-system
Labels:       fluxcd.io/sync-gc-mark=sha256.ZHrf64-v0mZOUqcgxzkwMOqA8GiGlwZQm2cxAyzlx-c
Annotations:  fluxcd.io/sync-checksum: a293032fecabfd9f8a766b6db58815d7f671bd45
              kubectl.kubernetes.io/last-applied-configuration:
                {"apiVersion":"helm.fluxcd.io/v1","kind":"HelmRelease","metadata":{"annotations":{"fluxcd.io/sync-checksum":"a293032fecabfd9f8a766b6db5881...
API Version:  helm.fluxcd.io/v1
Kind:         HelmRelease
Metadata:
  Creation Timestamp:  2020-05-22T06:40:38Z
  Generation:          1
  Resource Version:    145410
  Self Link:           /apis/helm.fluxcd.io/v1/namespaces/appmesh-system/helmreleases/appmesh-controller
  UID:                 07bae25e-4a84-46f1-bbd3-99c04538554e
Spec:
  Chart:
    Git:         https://github.com/aws/eks-charts
    Path:        stable/lerappmesh-control
    Ref:         master
  Release Name:  appmesh-controller
Status:
  Conditions:
    Last Transition Time:  2020-05-22T06:40:49Z
    Last Update Time:      2020-05-22T06:40:49Z
    Message:               Release was successful for Helm release 'appmesh-controller' in 'appmesh-system'.
    Reason:                Succeeded
    Status:                True
    Type:                  Released
    Last Transition Time:  2020-05-22T06:40:38Z
    Last Update Time:      2020-05-22T20:21:33Z
    Message:               Chart fetch failed for Helm release 'appmesh-controller' in 'appmesh-system'.
    Reason:                ChartFetchFailed
    Status:                False
    Type:                  ChartFetched
  Observed Generation:     1
  Phase:                   ChartFetchFailed
  Release Name:            appmesh-controller
  Release Status:          deployed
  Revision:                1203e5d3087754df6a0ca93a7b8fa33807d717cf
Events:
  Type    Reason         Age                  From           Message
  ----    ------         ----                 ----           -------
  Normal  ReleaseSynced  61s (x649 over 32h)  helm-operator  managed release 'appmesh-controller' in namespace 'appmesh-system' sychronized
```

Looking at the logs for the Flux Helm Operator don't give us any idea why the Phase changes happended.
```bash
$ kubectl -n flux logs helm-operator-74546bd6f5-d6trh | grep -i appmesh-control
ts=2020-05-24T01:33:33.149339214Z caller=release.go:75 component=release release=appmesh-controller targetNamespace=appmesh-system resource=appmesh-system:helmrelease/appmesh-controller helmVersion=v3 info="starting sync run"
ts=2020-05-24T01:33:33.322614798Z caller=release.go:247 component=release release=appmesh-controller targetNamespace=appmesh-system resource=appmesh-system:helmrelease/appmesh-controller helmVersion=v3 info="running dry-run upgrade to compare with release version '1'" action=dry-run-compare
ts=2020-05-24T01:33:33.324059625Z caller=helm.go:69 component=helm version=v3 info="preparing upgrade for appmesh-controller" targetNamespace=appmesh-system release=appmesh-controller
ts=2020-05-24T01:33:33.331587259Z caller=helm.go:69 component=helm version=v3 info="resetting values to the chart's original version" targetNamespace=appmesh-system release=appmesh-controller
ts=2020-05-24T01:33:33.625751191Z caller=helm.go:69 component=helm version=v3 info="performing update for appmesh-controller" targetNamespace=appmesh-system release=appmesh-controller
ts=2020-05-24T01:33:33.651241211Z caller=helm.go:69 component=helm version=v3 info="dry run for appmesh-controller" targetNamespace=appmesh-system release=appmesh-controller
ts=2020-05-24T01:33:33.693600861Z caller=release.go:266 component=release release=appmesh-controller targetNamespace=appmesh-system resource=appmesh-system:helmrelease/appmesh-controller helmVersion=v3 info="no changes" phase=dry-run-compare
....
ts=2020-05-24T02:42:33.650811662Z caller=release.go:266 component=release release=appmesh-controller targetNamespace=appmesh-system resource=appmesh-system:helmrelease/appmesh-controller helmVersion=v3 info="no changes" phase=dry-run-compare
ts=2020-05-24T02:45:33.155967259Z caller=release.go:75 component=release release=appmesh-controller targetNamespace=appmesh-system resource=appmesh-system:helmrelease/appmesh-controller helmVersion=v3 info="starting sync run"
ts=2020-05-24T02:45:33.304840269Z caller=release.go:247 component=release release=appmesh-controller targetNamespace=appmesh-system resource=appmesh-system:helmrelease/appmesh-controller helmVersion=v3 info="running dry-run upgrade to compare with release version '1'" action=dry-run-compare
ts=2020-05-24T02:45:33.306636292Z caller=helm.go:69 component=helm version=v3 info="preparing upgrade for appmesh-controller" targetNamespace=appmesh-system release=appmesh-controller
ts=2020-05-24T02:45:33.314613573Z caller=helm.go:69 component=helm version=v3 info="resetting values to the chart's original version" targetNamespace=appmesh-system release=appmesh-controller
ts=2020-05-24T02:45:33.611291871Z caller=helm.go:69 component=helm version=v3 info="performing update for appmesh-controller" targetNamespace=appmesh-system release=appmesh-controller
ts=2020-05-24T02:45:33.627573529Z caller=helm.go:69 component=helm version=v3 info="dry run for appmesh-controller" targetNamespace=appmesh-system release=appmesh-controller
ts=2020-05-24T02:45:33.670997761Z caller=release.go:266 component=release release=appmesh-controller targetNamespace=appmesh-system resource=appmesh-system:helmrelease/appmesh-controller helmVersion=v3 info="no changes" phase=dry-run-compare
```

Nothing about ChartFetchFailed in logs
```bash
$ kubectl -n flux logs helm-operator-74546bd6f5-d6trh | grep -i ChartFetchFailed
```
### Flux failed to work with Git AuthKey

I followed instruction on 
[setting up Flux with Auth Key](https://github.com/fluxcd/flux/blob/master/chart/flux/README.md#flux-with-git-over-https)
with HTTPS, I setup a private repo with the Auth Key,
but could not get it to clone the repo, here is the error message:
```bash
❯ fluxctl sync --k8s-fwd-ns flux
Error: git repository file://@https://seizadi%0A:43,,,,,,,,,,,,,,,,,,,,,%0A@github.com/seizadi/private-flux.git is not ready to sync

Full error message: git clone --mirror: fatal: unable to access 'https://github.com/seizadi/private-flux.git/': URL using bad/illegal format or missing URL, full output:
 Cloning into bare repository '/tmp/flux-gitclone152170752'...
fatal: unable to access 'https://github.com/seizadi/private-flux.git/': URL using bad/illegal format or missing URL


```
I am not sure the the additional character 'seizadi%0A' is getting in there, the GIT_AUTHUSER from the environment 
variable is 'seizadi'
```bash
> kubectl -n flux get secret flux-git-auth -o yaml
apiVersion: v1
data:
  GIT_AUTHKEY: .......
  GIT_AUTHUSER: c2VpemFkaQo=
kind: Secret
metadata:
  name: flux-git-auth
  namespace: flux
type: Opaque

❯ echo c2VpemFkaQo= | base64 --decode
seizadi
```
I opened a 
[GithUb Issue](https://github.com/fluxcd/flux/issues/2934) 
to track this problem, this would be a good place 
to [setup a Flux devlopment environment](https://docs.fluxcd.io/en/1.17.0/contributing/get-started-developing.html)
and see what is going on with this.
