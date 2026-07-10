pipeline {
  agent any

  parameters {
    choice(name: 'ENVIRONMENT', choices: ['dev', 'staging', 'prod'], description: 'Target environment')
    
    string(name: 'AUTH_PORT', defaultValue: '3001')
    string(name: 'STREAMING_PORT', defaultValue: '3002')
    string(name: 'ADMIN_PORT', defaultValue: '3003')
    string(name: 'CHAT_PORT', defaultValue: '3004')

    string(name: 'CLIENT_URLS', defaultValue: 'http://localhost:3000')    
    string(name: 'REACT_APP_AUTH_API_URL', defaultValue: 'http://localhost:3001/api')
    string(name: 'STREAMING_PUBLIC_URL', defaultValue: 'http://localhost:3002')
    string(name: 'REACT_APP_STREAMING_API_URL', defaultValue: 'http://localhost:3002/api')
    string(name: 'REACT_APP_STREAMING_PUBLIC_URL', defaultValue: 'http://localhost:3002')
    string(name: 'REACT_APP_CHAT_API_URL', defaultValue: 'http://localhost:3004/api/chat')
    string(name: 'REACT_APP_CHAT_SOCKET_URL', defaultValue: 'http://localhost:3004')
  }

  environment {
    AWS_REGION = "ap-south-1"
    MONGO_DB="streamingapp"
    AWS_S3_BUCKET="your_bucket_name"
    AWS_CDN_URL="your_cdn_url"
    JWT_SECRET="changeme"
    ECR_REGISTRY = "your-account-id.dkr.ecr.ap-south-1.amazonaws.com"

    SSH_CRED_ID = "test-cbd-Jenkins-EC2"
    EC2_USERNAME = "ubuntu"
    EC2_HOST = "13.203.230.208"

    ENVIRONMENT_NAME = "${params.ENVIRONMENT}"
    
    AUTH_PORT = "${params.AUTH_PORT}"
    STREAMING_PORT = "${params.STREAMING_PORT}"
    ADMIN_PORT = "${params.ADMIN_PORT}"
    CHAT_PORT = "${params.CHAT_PORT}"

    CLIENT_URLS = "${params.CLIENT_URLS}"
    STREAMING_PUBLIC_URL = "${params.STREAMING_PUBLIC_URL}"
    REACT_APP_AUTH_API_URL = "${params.REACT_APP_AUTH_API_URL}"
    REACT_APP_STREAMING_API_URL = "${params.REACT_APP_STREAMING_API_URL}"
    REACT_APP_STREAMING_PUBLIC_URL = "${params.REACT_APP_STREAMING_PUBLIC_URL}"
    REACT_APP_CHAT_API_URL = "${params.REACT_APP_CHAT_API_URL}"
    REACT_APP_CHAT_SOCKET_URL = "${params.REACT_APP_CHAT_SOCKET_URL}"
  }

  stages {
    stage('Checkout') {
      steps { checkout scm }
    }

    stage('Prepare environment files') {
      steps {
        withCredentials([
          string(credentialsId: "${params.ENVIRONMENT}-jwt-secret", variable: 'JWT_SECRET'),
          string(credentialsId: "${params.ENVIRONMENT}-aws-access-key", variable: 'AWS_ACCESS_KEY_ID'),
          string(credentialsId: "${params.ENVIRONMENT}-aws-secret-key", variable: 'AWS_SECRET_ACCESS_KEY')
          ]) 
        {
          sh '''
            set -e

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
    }

    stage('Copy files to EC2') {
      steps {
        sshagent(credentials: ["${env.SSH_CRED_ID}"]) {
            sh '''
                scp -o StrictHostKeyChecking=no -r * ${EC2_USERNAME}@${EC2_HOST}:/home/ubuntu
            '''
        }
      }
    }

    stage('Copy files to EC2') {
      steps {
        sshagent(credentials: ["${env.SSH_CRED_ID}"]) {
            sh '''
                ssh -o StrictHostKeyChecking=no ${EC2_USERNAME}@${EC2_HOST} '
                cd ~/frontend
                npm start 
            '''
        }
      }
    }
}
