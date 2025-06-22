#!/bin/bash
# undo_aws.sh - Destroys AWS CI/CD infrastructure

set -e

CLUSTER_NAME="webapp-cicd-cluster"
SERVICE_NAME="webapp-cicd-service"
TASK_FAMILY="webapp-cicd-task"
ECR_REPOSITORY="my-webapp"
SECURITY_GROUP_NAME="webapp-cicd-sg"
LOG_GROUP_NAME="/ecs/$TASK_FAMILY"
EXECUTION_ROLE_NAME="ecsTaskExecutionRole-$CLUSTER_NAME"
GITHUB_USER_NAME="github-actions-user"
AWS_REGION="eu-central-1"

echo "🧹 Cleaning up AWS infrastructure..."

# Delete ECS service
aws ecs update-service --cluster $CLUSTER_NAME --service $SERVICE_NAME --desired-count 0 --region $AWS_REGION || true
aws ecs delete-service --cluster $CLUSTER_NAME --service $SERVICE_NAME --force --region $AWS_REGION || true

# Deregister task definitions
TASK_DEFS=$(aws ecs list-task-definitions --family-prefix $TASK_FAMILY --region $AWS_REGION --query 'taskDefinitionArns' --output text)
for def in $TASK_DEFS; do
    aws ecs deregister-task-definition --task-definition "$def" --region $AWS_REGION || true
done

# Delete CloudWatch log group
aws logs delete-log-group --log-group-name $LOG_GROUP_NAME --region $AWS_REGION || true

# Delete security group
SG_ID=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=$SECURITY_GROUP_NAME" --query 'SecurityGroups[0].GroupId' --output text --region $AWS_REGION 2>/dev/null || echo "")
if [ -n "$SG_ID" ]; then
    aws ec2 delete-security-group --group-id $SG_ID --region $AWS_REGION || true
fi

# Delete ECS cluster
aws ecs delete-cluster --cluster $CLUSTER_NAME --region $AWS_REGION || true

# Delete ECR repository
aws ecr delete-repository --repository-name $ECR_REPOSITORY --force --region $AWS_REGION || true

# Delete IAM role
aws iam detach-role-policy --role-name $EXECUTION_ROLE_NAME --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy || true
aws iam delete-role --role-name $EXECUTION_ROLE_NAME || true

# Delete IAM user and keys
KEY_IDS=$(aws iam list-access-keys --user-name $GITHUB_USER_NAME --query 'AccessKeyMetadata[*].AccessKeyId' --output text 2>/dev/null || echo "")
for key in $KEY_IDS; do
    aws iam delete-access-key --user-name $GITHUB_USER_NAME --access-key-id $key || true
done
aws iam detach-user-policy --user-name $GITHUB_USER_NAME --policy-arn arn:aws:iam::aws:policy/AmazonECS_FullAccess || true
aws iam detach-user-policy --user-name $GITHUB_USER_NAME --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess || true
aws iam delete-user --user-name $GITHUB_USER_NAME || true

echo "✅ Cleanup complete."

