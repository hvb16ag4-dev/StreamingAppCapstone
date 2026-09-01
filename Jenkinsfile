pipeline {
  agent any

  parameters {
    choice(name: 'ENVIRONMENT', choices: ['dev', 'staging', 'prod'], description: 'Target environment')
    string(name: 'SSH_CRED_ID', defaultValue: 'EC2_SSH_CRED', description: 'Jenkins credential ID for EC2 SSH')
    string(name: 'EC2_HOST', defaultValue: '3.110.51.45', description: 'Target EC2 host')
    string(name: 'DOCKER_CRED_ID', defaultValue: 'Capstone_Grp4_Doc_ID', description: 'Docker registry credential ID')
    string(name: 'DOCKER_IMAGE', defaultValue: 'harika130822/streamingapp', description: 'Base Docker image')
  }

  environment {
    AWS_REGION       = "ap-south-1"
    AWS_ACCOUNT_ID   = "129373676098"
    ECR_REGISTRY     = "public.ecr.aws/l5r9g0t4"
    IMAGE_TAG        = "${BUILD_NUMBER}"
    GIT_REPO         = "https://github.com/hvb16ag4-dev/StreamingAppCapstone.git"
    EC2_USERNAME     = "ubuntu"
    ENVIRONMENT_NAME = "${params.ENVIRONMENT}"
  }

  stages {
    stage('Cleanup Docker Images') {
      steps {
        script {
          echo "Cleaning up old Docker images..."
    
          // Remove dangling (unused) images
          sh "docker image prune -f"
    
          // Optionally remove stopped containers too
          sh "docker container prune -f"
    
          // If you want to remove ALL images (be careful!)
           // sh """docker rmi -f \$(docker images -q) || true"""
        }
      }
    }
    

    stage('Git Checkout') {
      steps {
        git branch: 'CICD_DockerImage_ECR_EC2', url: "${GIT_REPO}"
      }
    }

    stage('Login to ECR') {
      steps {
        withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                          credentialsId: 'AWS_PROD_CRED_G4']]) {
          sh """
            aws ecr-public get-login-password --region us-east-1 \
            | docker login --username AWS --password-stdin ${ECR_REGISTRY}
          """
        }
      }
    }

    stage('Build and Push Images') {
      steps {
        script {
          def services = [
            "backend/adminService"     : "capstone/adminservice",
            "backend/authService"      : "capstone/authservice",
            "backend/chatService"      : "capstone/chatservice",
            "backend/streamingService" : "capstone/streamingservice",
            "frontend"                 : "capstone/frontend"
          ]
    
          services.each { folder, repoName ->
            echo "Building image for ${folder}"
            sh """
              docker build -t ${repoName}:${IMAGE_TAG} \
                -f ${folder}/Dockerfile .
              docker tag ${repoName}:${IMAGE_TAG} ${ECR_REGISTRY}/${repoName}:${IMAGE_TAG}
              docker push ${ECR_REGISTRY}/${repoName}:${IMAGE_TAG}
            """
          }
        }
      }
    }


    // stage('Deploy to EC2') {
    //   steps {
    //     sshagent (credentials: ["${params.SSH_CRED_ID}"]) {
    //       sh """
    //         ssh -o StrictHostKeyChecking=no ${EC2_USERNAME}@${params.EC2_HOST} << 'EOF'
    //           set -e
    //           echo "Pulling latest Docker images..."
    //           docker login -u AWS -p $(aws ecr-public get-login-password --region ${AWS_REGION}) ${ECR_REGISTRY}
              
    //           # Example: restart services with new images
    //           docker pull ${ECR_REGISTRY}/capstone/authservice:${IMAGE_TAG}
    //           docker pull ${ECR_REGISTRY}/capstone/streamingservice:${IMAGE_TAG}
    //           docker pull ${ECR_REGISTRY}/capstone/adminservice:${IMAGE_TAG}
    //           docker pull ${ECR_REGISTRY}/capstone/chatservice:${IMAGE_TAG}
    //           docker pull ${ECR_REGISTRY}/capstone/frontend:${IMAGE_TAG}

    //           echo "Restarting containers..."
    //           docker-compose -f /home/ubuntu/docker-compose.yml down
    //           docker-compose -f /home/ubuntu/docker-compose.yml up -d
    //         EOF
    //       """
    //     }
    //   }
    // }

    // stage('Update kubeconfig') {
    //   steps {
    //     withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
    //                       credentialsId: 'AWS_PROD_CRED_G4']]) {
    //       sh "aws eks update-kubeconfig --region ${AWS_REGION} --name ${ENVIRONMENT_NAME}-eks"
    //     }
    //   }
    // }
  }

  post {
    success {
      echo "✅ Deployment successful!"
    }
    failure {
      echo "❌ Deployment failed. Check logs."
    }
  }
}
