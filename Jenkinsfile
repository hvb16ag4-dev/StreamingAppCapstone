pipeline {
  agent any
  // deploy application into new EC2 instance - task wise not required but weekly wise we need it

  parameters {
    choice(name: 'ENVIRONMENT', choices: ['dev', 'staging', 'prod'], description: 'Target environment')
    string(name: 'SSH_CRED_ID', defaultValue: '3.110.51.45')
    string(name: 'EC2_HOST', defaultValue: '3.110.51.45')
    string(name: 'DOCKER_CRED_ID', defaultValue: 'Capstone_Grp4_Doc_ID')
    string(name: 'DOCKER_IMAGE', defaultValue: 'harika130822/streamingapp')
  }

  environment {
    AWS_REGION = "ap-south-1" 
    MONGO_DB = "streamingapp"
    AWS_S3_BUCKET = "your_bucket_name"
    AWS_CDN_URL = "your_cdn_url"
    JWT_SECRET = "changeme"
    AWS_ACCOUNT_ID  = "129373676098"
    ECR_REGISTRY    = "public.ecr.aws/l5r9g0t4" //"${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com"
    AWS_ACCESS_KEY_ID = ""
    AWS_SECRET_ACCESS_KEY = ""
    IMAGE_TAG = "${BUILD_NUMBER}"


    SSH_CRED_ID = "${params.SSH_CRED_ID}"
    EC2_USERNAME = "ubuntu"
    EC2_HOST = "${params.EC2_HOST}"
    GIT_REPO = "https://github.com/hvb16ag4-dev/StreamingAppCapstone.git"

    ENVIRONMENT_NAME = "${params.ENVIRONMENT}"
    AUTH_PORT = "3001"
    STREAMING_PORT = "3002"
    ADMIN_PORT = "3003"
    CHAT_PORT = "3004"

    CLIENT_URLS = "http://localhost:3000"
    STREAMING_PUBLIC_URL = "http://localhost:3002"
    REACT_APP_AUTH_API_URL = "http://localhost:3001/api"
    REACT_APP_STREAMING_API_URL = "http://localhost:3002/api"
    REACT_APP_STREAMING_PUBLIC_URL = "http://localhost:3002"
    REACT_APP_CHAT_API_URL = "http://localhost:3004/api/chat"
    REACT_APP_CHAT_SOCKET_URL = "http://localhost:3004"
  }

  stages {

        stage('Git Checkout') {
            steps {
                git branch: 'Jenkins_CICD_Setup', url: "${GIT_REPO}"
            }
        }
        
        stage('pwd') {
            steps {
                sh """
                pwd
                ls -alh
                """
            }
        }

        stage('Login to ECR') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                                credentialsId: 'AWS_PROD_CRED_G4']]) {
                sh """
                    aws ecr-public get-login-password --region us-east-1 \
                    | docker login --username AWS --password-stdin public.ecr.aws
                """
                }
            }
        }

        stage('Build and Push Images') {
            steps {
                script {
                def services = [
                    "backend/adminService"      : "capstone/adminservice",
                    "backend/authService"       : "capstone/authservice",
                    "backend/chatService"       : "capstone/chatservice",
                    "backend/streamingService"  : "capstone/streamingservice",
                    "frontend"                  : "capstone/frontend",
                ]

                services.each { folder, repoName ->
                    echo "Building image for ${folder}"

                    sh """
                    docker build -t ${repoName}:${IMAGE_TAG} ./${folder}
                    docker tag ${repoName}:${IMAGE_TAG} ${ECR_REGISTRY}/${repoName}:${IMAGE_TAG}
                    docker push ${ECR_REGISTRY}/${repoName}:${IMAGE_TAG}
                    """
                    }
                }
            }
        }

        stage('Update kubeconfig') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                                credentialsId: 'AWS_PROD_CRED_G4']]) {
                sh "aws eks update-kubeconfig --region ${AWS_REGION} --name ${EKS_CLUSTER_NAME}"
                }
            }
        }

    }

}
