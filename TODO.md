Keep track of tasks, maybe track in Issues for more coarse items:
Areas to consider:
   - Upgrade to 1.17 (I actually had to downgrade to 1.15 for compatability)
   see [Kubeflow compatability guide](https://github.com/kubeflow/website/issues/2057)
   ```bash
    version: "1.17"
   ```
  - Use auto-scaling group right now it is fixed at 'desiredSize: 6', would need to find what min size would work.
  ```bash
      minSize: 1
      maxSize: 6
  ```
  - Turn on logging, using eksctl but also in cluster template
  ```bash
  [ℹ]  CloudWatch logging will not be enabled for cluster "seizadi-eks-kubeflow" in "us-west-1"
  [ℹ]  you can enable it with 'eksctl utils update-cluster-logging --region=us-west-1 --cluster=seizadi-eks-kubeflow'
  ```
  - SSH Access, does System Manager work or do we need key?
  ```bash
      ssh:  
        allow: true
        publicKeyPath: ~/keys/sample.pub
  ```
  - IAM Roles How many we need to specify versus what eskctl creates and manages
  ```bash
      iam:
        attachPolicyARNs:
          - arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy
          - arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy
          - arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly
          - arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess
        withAddonPolicies:
          imageBuilder: true
          autoScaler: true
          ebs: true
          fsx: true
          efs: true
          albIngress: true
          cloudWatch: true
  ```
  - VPC isolated versus shared, right now we create an isolated VPC
 
