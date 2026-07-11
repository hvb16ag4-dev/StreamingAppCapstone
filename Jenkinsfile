pipeline {
  agent any
  // deploy application into new EC2 instance - task wise not required but weekly wise we need it

  parameters {
    choice(name: 'ENVIRONMENT', choices: ['dev', 'staging', 'prod'], description: 'Target environment')
    string(name: 'SSH_CRED_ID', defaultValue: '13.234.30.51')
    string(name: 'EC2_HOST', defaultValue: '52.66.235.170')
  }

  environment {
    AWS_REGION = "ap-south-1" 
    MONGO_DB = "streamingapp"
    AWS_S3_BUCKET = "your_bucket_name"
    AWS_CDN_URL = "your_cdn_url"
    JWT_SECRET = "changeme"
    ECR_REGISTRY = "your-account-id.dkr.ecr.ap-south-1.amazonaws.com"
    AWS_ACCESS_KEY_ID = ""
    AWS_SECRET_ACCESS_KEY = ""


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

        stage('Prepare environment auth files') {
            steps {
                withCredentials([
                string(credentialsId: "${params.ENVIRONMENT}-jwt-secret", variable: 'JWT_SECRET'),
                string(credentialsId: "${params.ENVIRONMENT}-aws-access-key", variable: 'AWS_ACCESS_KEY_ID'),
                string(credentialsId: "${params.ENVIRONMENT}-aws-secret-key", variable: 'AWS_SECRET_ACCESS_KEY')
                ]) {
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
'''
                }
            }
        }


        stage('Prepare environment stream files') {
            steps {
                withCredentials([
                string(credentialsId: "${params.ENVIRONMENT}-jwt-secret", variable: 'JWT_SECRET'),
                string(credentialsId: "${params.ENVIRONMENT}-aws-access-key", variable: 'AWS_ACCESS_KEY_ID'),
                string(credentialsId: "${params.ENVIRONMENT}-aws-secret-key", variable: 'AWS_SECRET_ACCESS_KEY')
                ]) {
                sh '''
                    set -e

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
'''
                }
            }
        }

        stage('Prepare environment admin files') {
            steps {
                withCredentials([
                string(credentialsId: "${params.ENVIRONMENT}-jwt-secret", variable: 'JWT_SECRET'),
                string(credentialsId: "${params.ENVIRONMENT}-aws-access-key", variable: 'AWS_ACCESS_KEY_ID'),
                string(credentialsId: "${params.ENVIRONMENT}-aws-secret-key", variable: 'AWS_SECRET_ACCESS_KEY')
                ]) {
                sh '''
                    set -e

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
'''
                }
            }
        }

        stage('Prepare environment chat files') {
            steps {
                withCredentials([
                string(credentialsId: "${params.ENVIRONMENT}-jwt-secret", variable: 'JWT_SECRET'),
                string(credentialsId: "${params.ENVIRONMENT}-aws-access-key", variable: 'AWS_ACCESS_KEY_ID'),
                string(credentialsId: "${params.ENVIRONMENT}-aws-secret-key", variable: 'AWS_SECRET_ACCESS_KEY')
                ]) {
                sh '''
                    set -e

                    # Chat Service
                    cat > backend/chatService/.env <<EOF
PORT=$CHAT_PORT
MONGO_URI=mongodb://localhost:27017/$MONGO_DB
JWT_SECRET=$JWT_SECRET
CLIENT_URLS=$CLIENT_URLS
EOF
'''
                }
            }
        }

        stage('Prepare environment frontend files') {
            steps {
                withCredentials([
                string(credentialsId: "${params.ENVIRONMENT}-jwt-secret", variable: 'JWT_SECRET'),
                string(credentialsId: "${params.ENVIRONMENT}-aws-access-key", variable: 'AWS_ACCESS_KEY_ID'),
                string(credentialsId: "${params.ENVIRONMENT}-aws-secret-key", variable: 'AWS_SECRET_ACCESS_KEY')
                ]) {
                sh '''
                    set -e

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
                    echo "Copying files to EC2..."
                    scp -o StrictHostKeyChecking=no -r * ${EC2_USERNAME}@${EC2_HOST}:/home/ubuntu
                '''
                }
            }
        }

        stage('Installing dependencies in EC2') {
            steps {
                sshagent(credentials: ["${env.SSH_CRED_ID}"]) {
                sh """
                    ssh -o StrictHostKeyChecking=no ${EC2_USERNAME}@${EC2_HOST} '
                    sudo apt update && sudo apt install npm -y &&
                    cd backend/authService && npm install &&
                    cd ../streamingService && npm install &&
                    cd ../adminService && npm install &&
                    cd ../chatService && npm install &&
                    cd ../../frontend && npm install
                    '
                """
                }
            }
        }

        stage('Mongo DB setup in EC2') {
            steps {
                sshagent(credentials: ["${env.SSH_CRED_ID}"]) {
                sh """
                    ssh -o StrictHostKeyChecking=no ${EC2_USERNAME}@${EC2_HOST} '
            
                curl -fsSL https://www.mongodb.org/static/pgp/server-6.0.asc | \
                    sudo gpg --dearmor -o /usr/share/keyrings/mongodb-server-6.0.gpg &&

                echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-6.0.gpg ] \
                https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/6.0 multiverse" | \
                sudo tee /etc/apt/sources.list.d/mongodb-org-6.0.list &&

                sudo apt update &&
                sudo apt install -y mongodb-org &&
                sudo systemctl start mongod &&
                sudo systemctl enable mongod
                    '
                """
                }
            }
        }

        stage('Install PM2 on EC2') {
            steps {
                sshagent(credentials: ["${env.SSH_CRED_ID}"]) {
                sh """
                    ssh -o StrictHostKeyChecking=no ${EC2_USERNAME}@${EC2_HOST} '
                    sudo npm install -g pm2
                    '
                """
                }
            }
        }



        stage('Start services in EC2') {
            parallel {
                stage('Start authservice in EC2') {
                    steps {
                        sshagent(credentials: ["${env.SSH_CRED_ID}"]) {
                        sh """
                            ssh -o StrictHostKeyChecking=no ${EC2_USERNAME}@${EC2_HOST} '
                            cd backend/authService &&
                            pm2 start index.js --name authservice --watch --env $ENVIRONMENT_NAME
                            '
                        """
                        }
                    }
                }

                stage('Start streamingService in EC2') {
                    steps {
                        sshagent(credentials: ["${env.SSH_CRED_ID}"]) {
                        sh """
                            ssh -o StrictHostKeyChecking=no ${EC2_USERNAME}@${EC2_HOST} '
                            cd backend/streamingService &&
                            pm2 start index.js --name streamingService --watch --env $ENVIRONMENT_NAME
                            '
                        """
                        }
                    }
                }

                stage('Start adminService in EC2') {
                    steps {
                        sshagent(credentials: ["${env.SSH_CRED_ID}"]) {
                        sh """
                            ssh -o StrictHostKeyChecking=no ${EC2_USERNAME}@${EC2_HOST} '
                            cd backend/adminService &&
                            pm2 start index.js --name adminService --watch --env $ENVIRONMENT_NAME
                            '
                        """
                        }
                    }
                }

                stage('Start chatService in EC2') {
                    steps {
                        sshagent(credentials: ["${env.SSH_CRED_ID}"]) {
                        sh """
                            ssh -o StrictHostKeyChecking=no ${EC2_USERNAME}@${EC2_HOST} '
                            cd backend/chatService &&
                            pm2 start index.js --name chatService --watch --env $ENVIRONMENT_NAME
                            '
                        """
                        }
                    }
                }

                stage('Start frontend on EC2') {
                    steps {
                        sshagent(credentials: ["${env.SSH_CRED_ID}"]) {
                        sh """
                            ssh -o StrictHostKeyChecking=no ${EC2_USERNAME}@${EC2_HOST} '
                            cd frontend &&
                            pm2 start npm --name frontend -- start
                            '
                        """
                        }
                    }
                }
            }
        }

    }

}
