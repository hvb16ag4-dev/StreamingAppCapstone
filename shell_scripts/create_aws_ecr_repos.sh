#!/bin/bash

echo "----- streamingapp-frontend -----"
aws ecr create-repository \
  --repository-name streamingapp-frontend \
  --region ap-south-1

echo "----- streamingapp-auth -----"
aws ecr create-repository \
  --repository-name streamingapp-auth \
  --region ap-south-1

echo "----- streamingapp-streaming -----"
aws ecr create-repository \
  --repository-name streamingapp-streaming \
  --region ap-south-1

echo "----- streamingapp-admin -----"
aws ecr create-repository \
  --repository-name streamingapp-admin \
  --region ap-south-1

echo "----- streamingapp-chat -----"
aws ecr create-repository \
  --repository-name streamingapp-chat \
  --region ap-south-1

echo "----- verify ECR repositories -----"

aws ecr describe-repositories --region ap-south-1 --no-cli-pager
