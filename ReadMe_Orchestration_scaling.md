# StreamingApp - End-to-End CI/CD Pipeline on Amazon EKS

## Project Overview

This project demonstrates the implementation of a complete DevOps CI/CD pipeline for a containerized microservices-based Streaming Application using Docker, Jenkins, Amazon ECR, Amazon EKS, Kubernetes, and Helm.

The pipeline automatically builds Docker images, pushes them to Amazon Elastic Container Registry (ECR), and deploys the latest version to an Amazon EKS cluster using Helm charts.

---

# Architecture

```
Developer
      │
      ▼
GitHub Repository
      │
      ▼
Jenkins Pipeline
      │
      ├── Checkout Source
      ├── Build Docker Images
      ├── Push Images to Amazon ECR
      ├── Update Kubernetes Secret
      └── Helm Upgrade
                │
                ▼
          Amazon EKS Cluster
                │
      ┌─────────┼─────────┐
      │         │         │
Frontend    Backend APIs  MongoDB
```

---

# Technology Stack

| Component | Technology |
|------------|------------|
| Frontend | React |
| Backend | Node.js / Express |
| Database | MongoDB |
| Containerization | Docker |
| Orchestration | Kubernetes (Amazon EKS) |
| Package Manager | Helm |
| CI/CD | Jenkins |
| Container Registry | Amazon ECR |
| Source Control | GitHub |
| Cloud Platform | AWS |

---

# Project Structure

```
StreamingApp/
│
├── admin/
├── auth/
├── chat/
├── frontend/
├── streaming/
├── helm/
│   └── streamingapp/
├── k8s/
├── Jenkinsfile
├── docker-compose.yml
└── README.md
```

---

# Features

- Dockerized microservices
- Multi-container application
- Jenkins CI/CD Pipeline
- Automated Docker image builds
- Amazon ECR integration
- Amazon EKS deployment
- Kubernetes ConfigMaps
- Kubernetes Secrets
- Helm chart deployment
- Dynamic image versioning using Jenkins Build Number
- GitHub integration

---

# Prerequisites

- AWS Account
- Docker
- Kubernetes CLI (kubectl)
- Helm
- AWS CLI
- Jenkins
- Git

---

# Deployment Workflow

1. Developer pushes code to GitHub.
2. Jenkins detects source code changes.
3. Docker images are built.
4. Images are pushed to Amazon ECR.
5. Jenkins updates Kubernetes Secret.
6. Helm upgrades the application.
7. Kubernetes performs rolling deployment.
8. Application becomes available through AWS LoadBalancer.

---

# Jenkins Pipeline

The Jenkins pipeline performs the following stages:

- Checkout
- Docker Build
- Docker Push
- Update Kubernetes Secret
- Helm Deployment
- Rollout Verification

---

# Kubernetes Resources

The project deploys the following Kubernetes resources:

- Namespace
- Deployments
- Services
- ConfigMap
- Secret
- ReplicaSets
- Pods

---

# Helm

Helm is used to package and deploy the application.

Benefits include:

- Parameterized deployments
- Version control
- Easy upgrades
- Easy rollback
- Reusable templates

---

# Security

Sensitive information is not stored in the repository.

Security is implemented using:

- Jenkins Credentials
- Kubernetes Secrets
- GitHub Push Protection
- .gitignore
- Image Pull Secrets

---

# Monitoring

Amazon CloudWatch Observability add-on was installed for monitoring and logging.

During validation, the add-on reported a **DEGRADED** status because the worker nodes had reached their maximum pod scheduling capacity. The CI/CD pipeline and application deployment remained fully operational.

---

# Results

Successfully implemented:

- Automated CI/CD Pipeline
- Docker Image Build
- Amazon ECR Integration
- Amazon EKS Deployment
- Kubernetes Orchestration
- Helm Chart Deployment
- Secure Secret Management
- Automated Rolling Updates

---

# Challenges Faced

- Jenkins node disk space issue
- GitHub Push Protection
- ImagePullBackOff
- Kubernetes Secret management
- Helm value overrides
- Frontend environment configuration
- CloudWatch pod scheduling limitation

---

# Future Enhancements

- Prometheus & Grafana Monitoring
- Horizontal Pod Autoscaler
- AWS Secrets Manager
- Argo CD GitOps
- Blue/Green Deployments
- Canary Releases
- SonarQube Integration
- Complete CloudWatch Metrics & Logging

---

# Conclusion

This project demonstrates a complete cloud-native CI/CD implementation using modern DevOps practices. Docker, Jenkins, Amazon ECR, Amazon EKS, Kubernetes, and Helm work together to automate application deployment, improve scalability, and provide a repeatable deployment process suitable for production environments.
