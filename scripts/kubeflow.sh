#!/bin/sh
# Inputs:
# $1 - AWS Region
# $2 - Cognito User Pool Name
# $3 - Kubeflow App Name
# $4 - AWS EKS Cluster Name

# AWS Cognito - Assumes you have setup Cognito before you run this script
# See -> https://www.kubeflow.org/docs/aws/aws-e2e/#cognito
COGNITO_ID=`aws cognito-idp --region $1 list-user-pools --max-results 60  |
				jq -r ".UserPools[] | select(.Name | startswith(\"$2\")) .Id"`

COGNITO_POOL=`aws cognito-idp --region $1 describe-user-pool --user-pool-id  $COGNITO_ID`

COGNITO_USER_POOL_DOMAIN=`echo $COGNITO_POOL | jq -r ".UserPool.Domain"`

COGNITO_USER_POOL_ARN=`echo $COGNITO_POOL | jq -r ".UserPool.Arn"`

COGNITO_CLIENT_ID=`aws cognito-idp --region $1 list-user-pool-clients --user-pool-id  $COGNITO_ID --max-results 60  |
					jq -r ".UserPoolClients[] | \
		select(.ClientName | startswith(\"$3\")) .ClientId"`

COGNITO_CDN=`aws cognito-idp --region $1 describe-user-pool-domain --domain  $COGNITO_USER_POOL_DOMAIN  |
				jq -r ".DomainDescription.CloudFrontDistribution"`

COGNITO_CERT_ARN=`aws cognito-idp --region $1 describe-user-pool-domain --domain  $COGNITO_USER_POOL_DOMAIN  |
					jq -r ".DomainDescription.CustomDomainConfig.CertificateArn"`

KUBEFLOW_CLUSTER_ROLE=`aws iam list-roles | jq -r ".Roles[] | \
		select(.RoleName | startswith(\"$4\") \
		and contains(\"NodeInstanceRole\")) .RoleName"`

touch deploy/kfctl_aws_cognito.v1.0.2.yaml

# The AWS ARN arguments have '/' they will confuse sed command parser, so use '~' for delimiter
sed "s/{{ .Region }}/$1/g;
	s~{{ .CertArn }}~$COGNITO_CERT_ARN~g;
	s~{{ .CognitoUserPoolArn }}~$COGNITO_USER_POOL_ARN~g;
	s/{{ .CognitoUserPoolDomain }}/$COGNITO_USER_POOL_DOMAIN/g;
	s/{{ .KubeflowClusterRole }}/$KUBEFLOW_CLUSTER_ROLE/g
	" deploy/kfctl_aws_cognito.v1.0.2.yaml.in > deploy/kfctl_aws_cognito.v1.0.2.yaml
