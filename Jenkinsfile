pipeline {
  agent any
  // deploy application into new EC2 instance - task wise not required but weekly wise we need it

  parameters {
    choice(name: 'ENVIRONMENT', choices: ['dev', 'staging', 'prod'], description: 'Target environment')
    string(name: 'SSH_CRED_ID', defaultValue: '13.234.30.51')
    string(name: 'EC2_HOST', defaultValue: '52.66.235.170')
    string(name: 'DOCKER_CRED_ID', defaultValue: 'Capstone_Grp4_Doc_ID')
    string(name: 'DOCKER_IMAGE', defaultValue: 'harika130822/StreamingApp')
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

        stage('Docker build image') {
            steps {
                script {
                  def customImage = docker.build("${env.DOCKER_IMAGE}:${env.BUILD_ID}")
                }
            }
        }

        stage('Docker build Push') {
            steps {
                script {
                  docker.withRegistry('',"${env.DOCKER_CRED_ID}"){
                    customImage.push()
                  }
                }
            }
        }

        stage('Pull Docker Image into EC2') {
            steps {
                script {
                    sh '''
                        ssh -o StrictHostKeyChecking=no ec2-user@<EC2_INSTANCE_IP> << EOF
                        docker pull ${customImage}
                        EOF
                    '''
                }
            }
        }

        stage('Docker Compose Restart in EC2') {
            steps {
                script {
                    sh '''
                        ssh -o StrictHostKeyChecking=no ec2-user@<EC2_INSTANCE_IP> << EOF
                        cd /path/to/docker-compose-directory
                        docker-compose down
                        docker-compose up -d
                        EOF
                    '''
                }
            }
        }

        // stage('Docker build push image to ECR') {
        //     steps {
        //         script {
        //             sh '''
        //                 aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin <account_id>.dkr.ecr.$AWS_REGION.amazonaws.com
        //                 docker tag my-image:latest <account_id>.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO:$IMAGE_TAG
        //                 docker push <account_id>.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO:$IMAGE_TAG
        //             '''
        //         }
        //     }
        // }

    }

}
