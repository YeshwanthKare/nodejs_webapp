#!/bin/bash

set -e

# ENV Variables
REGION="eu-central-1"
CLUSTER="webapp-cicd-cluster"
SERVICE="webapp-cicd-service"
REPO="my-webapp"
ROLE_NAME="ecsTaskExecutionRole-${CLUSTER}"
LOG_GROUP="/ecs/${CLUSTER}"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "=========================================="
echo "🧹 Cleaning up AWS ECS infrastructure"
echo "=========================================="

echo "🔻 Deleting ECS service..."
aws ecs update-service --cluster "$CLUSTER" --service "$SERVICE" --desired-count 0 --region "$REGION" || true
aws ecs delete-service --cluster "$CLUSTER" --service "$SERVICE" --force --region "$REGION" || true

echo "🧼 Deleting ECS cluster..."
aws ecs delete-cluster --cluster "$CLUSTER" --region "$REGION" || true

echo "🧨 Deleting all task definitions..."
TASK_DEFS=$(aws ecs list-task-definitions --family-prefix "$SERVICE" --region "$REGION" --query 'taskDefinitionArns' --output text)
for td in $TASK_DEFS; do
  echo "Deregistering: $td"
  aws ecs deregister-task-definition --task-definition "$td" --region "$REGION"
done

echo "🧯 Deleting ECR repository..."
aws ecr delete-repository --repository-name "$REPO" --force --region "$REGION" || true

echo "🔐 Detaching and deleting IAM role: $ROLE_NAME"
aws iam detach-role-policy --role-name "$ROLE_NAME" --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy || true
aws iam delete-role --role-name "$ROLE_NAME" || true

echo "🗑️ Deleting CloudWatch log group (optional)..."
aws logs delete-log-group --log-group-name "$LOG_GROUP" --region "$REGION" || true

echo "✅ Cleanup complete!"

