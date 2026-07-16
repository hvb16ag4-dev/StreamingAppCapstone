pipeline {
  agent { label 'CICD_ASSIGN_NODE' }

  parameters {
    choice(name: 'ENVIRONMENT', choices: ['dev', 'staging', 'prod'], description: 'Target environment')
    string(name: 'SSH_CRED_ID', defaultValue: '13.234.30.51')
    string(name: 'EC2_HOST', defaultValue: '15.207.55.9')
    string(name: 'DOCKER_USERNAME', defaultValue: 'harika130822')
    string(name: 'DOCKER_CRED', defaultValue: 'DOCKER_CRED_ID_GRP4')
    string(name: 'EKS_CLUSTER_NAME', defaultValue: 'your_eks_cluster_name')
  }

  environment {
    // cluster
    EKS_CLUSTER_NAME = "${params.EKS_CLUSTER_NAME}"
    AWS_REGION = "ap-south-1" 
    AWS_S3_BUCKET = "your_bucket_name"
    AWS_CDN_URL = "your_cdn_url"
    
    //others
    MONGO_DB = "streamingapp"    
    JWT_SECRET = "changeme"
    ECR_REGISTRY = "your-account-id.dkr.ecr.ap-south-1.amazonaws.com"
    AWS_ACCESS_KEY_ID = ""
    AWS_SECRET_ACCESS_KEY = ""

    // Docker credentials
    DOCKER_USERNAME = "${params.DOCKER_USERNAME}"
    DOCKER_CRED = "${params.DOCKER_CRED}"

    // Ec2 credentials
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
                git branch: 'Jenkins_CICD_Setup', url: "${env.GIT_REPO}"
            }
        }
        
//environment files for each service and frontend not required but weekly wise we need it as we create our own EC2 setup
        stage('Prepare environment files') {
            steps {
                sh '''
                    set -e
                    # cd workspace/${JOB_NAME} # not required as its already in this path
                    cd ${WORKSPACE}
                    # Auth Service
                    cat > backend/authService/.env <<EOF
PORT=$AUTH_PORT
MONGO_URI=mongodb://localhost:27017/$MONGO_DB
JWT_SECRET=$JWT_SECRET
CLIENT_URLS=$CLIENT_URLS
AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY
AWS_REGION=$AWS_REGION
AWS_S3_BUCKET=$AWS_S3_BUCKET
EOF

                    # Streaming Service
                    cat > backend/streamingService/.env <<EOF
PORT=$STREAMING_PORT
MONGO_URI=mongodb://localhost:27017/$MONGO_DB
JWT_SECRET=$JWT_SECRET
CLIENT_URLS=$CLIENT_URLS
AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY
AWS_REGION=$AWS_REGION
AWS_S3_BUCKET=$AWS_S3_BUCKET
AWS_CDN_URL=$AWS_CDN_URL
STREAMING_PUBLIC_URL=$STREAMING_PUBLIC_URL
EOF

                    # Admin Service
                    cat > backend/adminService/.env <<EOF
PORT=$ADMIN_PORT
MONGO_URI=mongodb://localhost:27017/$MONGO_DB
JWT_SECRET=$JWT_SECRET
CLIENT_URLS=$CLIENT_URLS
AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY
AWS_REGION=$AWS_REGION
AWS_S3_BUCKET=$AWS_S3_BUCKET
EOF

                    # Chat Service
                    cat > backend/chatService/.env <<EOF
PORT=$CHAT_PORT
MONGO_URI=mongodb://localhost:27017/$MONGO_DB
JWT_SECRET=$JWT_SECRET
CLIENT_URLS=$CLIENT_URLS
EOF

                    # Frontend
                    cat > frontend/.env <<EOF
REACT_APP_AUTH_API_URL=$REACT_APP_AUTH_API_URL
REACT_APP_STREAMING_API_URL=$REACT_APP_STREAMING_API_URL
REACT_APP_STREAMING_PUBLIC_URL=$REACT_APP_STREAMING_PUBLIC_URL
REACT_APP_ADMIN_API_URL=$REACT_APP_ADMIN_API_URL
REACT_APP_CHAT_API_URL=$REACT_APP_CHAT_API_URL
REACT_APP_CHAT_SOCKET_URL=$REACT_APP_CHAT_SOCKET_URL
EOF
'''
                }
            }


        stage('Build Docker Images and Start Services') {
            steps {
                sh '''
                    set -e
                    cd ${WORKSPACE}
                    # Build Docker compose up
                    docker compose up -d --build
                    docker ps
                '''
            }
        }

        stage('Health Checks') {
            steps {
                sh '''
                    set -e
                    echo "Checking service health..."

                    # Auth Service
                    curl -f ${REACT_APP_AUTH_API_URL}/health || exit 1

                    # Streaming Service
                    curl -f ${REACT_APP_STREAMING_API_URL}/health || exit 1

                    # Streaming Public URL
                    curl -f ${REACT_APP_STREAMING_PUBLIC_URL} || exit 1

                    # Admin Service
                    curl -f ${REACT_APP_ADMIN_API_URL}/health || exit 1

                    # Chat Service API
                    curl -f ${REACT_APP_CHAT_API_URL}/health || exit 1

                    # Chat Socket (basic connectivity check)
                    curl -f ${REACT_APP_CHAT_SOCKET_URL} || exit 1

                    echo "✅ All services are healthy!"
                '''
            }
        }

        stage('Build and Push Docker Images') {
            when {
                anyOf {
                environment name: 'ENVIRONMENT_NAME', value: 'staging'
                environment name: 'ENVIRONMENT_NAME', value: 'prod'
                }
            }
            steps {
                script {
                    def services = [
                        'authService',
                        'streamingService',
                        'adminService',
                        'chatService'
                    ]

                    // Build & push backend services
                    services.each { service ->
                        dir("backend/${service}") {
                            sh """
                                docker tag ${JOB_NAME}-${service}:${BUILD_NUMBER} ${DOCKER_USERNAME}/${JOB_NAME}-${service}:${BUILD_NUMBER}
                            """
                        }
                    }

                    // Build & push frontend
                    dir("frontend") {
                        sh """
                            docker tag ${JOB_NAME}-frontend:${BUILD_NUMBER} ${DOCKER_USERNAME}/${JOB_NAME}-frontend:${BUILD_NUMBER}
                        """
                    }

                    stage("Push to DockerHub backend") {
                        steps {
                            script {
                                docker.withRegistry('', "${DOCKER_CRED}") {
                                    services.each { service ->
                                        dir("backend/${service}") {
                                            sh """
                                                docker push ${DOCKER_USERNAME}/${JOB_NAME}-${service}:${BUILD_NUMBER}
                                            """
                                        }
                                    }
                                }
                            }
                        }
                    }

                    stage("Push to DockerHub backend") {
                        steps {
                            script {
                                docker.withRegistry('', "${DOCKER_CRED}") {
                                    services.each { service ->
                                        dir("backend/${service}") {
                                            sh """
                                                docker push ${DOCKER_USERNAME}/${JOB_NAME}-frontend:${BUILD_NUMBER}
                                            """
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        stage('Update Kubeconfig') {
            when {
                anyOf {
                environment name: 'ENVIRONMENT_NAME', value: 'prod'
                branch 'main'
                }
            }
            steps {
                sh "aws eks --region ${AWS_REGION} update-kubeconfig --name ${EKS_CLUSTER_NAME}"
            }
        }

        stage('Deploy to EKS') {
            when {
                anyOf {
                environment name: 'ENVIRONMENT_NAME', value: 'prod'
                branch 'main'
                }
            }
            steps {
                sh "kubectl apply -f k8s/"
            }
        }
        
    }

}

