pipeline {
    agent { label 'Ranjeet_node' }

    environment {
        AWS_REGION = 'ap-south-1'
        AWS_CREDENTIALS = 'aws-prod-ranjeet'
    }

    options {
        timestamps()
        timeout(time: 30, unit: 'MINUTES') // Fails the build if it takes longer than  30 mins
        //wrap([$class: 'AnsiColorBuildWrapper', colorMapName: 'Xterm'])
        buildDiscarder(logRotator(numToKeepStr: '10'))
    }

    stages {

        stage('Clean Workspace') {
            steps {
                echo 'Cleaning Workspace...'
                cleanWs()
            }
        }

        stage('Checkout') {
            steps {
                echo 'Checking out source code...'
                checkout scm
            }
        }

        stage('Verify Environment') {
            steps {
                sh '''
                    echo "===== Environment ====="
                    hostname
                    pwd
                    whoami
                    docker --version
                    docker compose version
                    aws --version
                '''
            }
        }

        stage('Build Images') {
            steps {
                sh '''
                    docker compose build
                '''
            }
        }

        stage('Login to Amazon ECR') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-prod-ranjeet']]) {
                    sh '''
                        ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

                        aws ecr get-login-password --region $AWS_REGION | \
                        docker login \
                        --username AWS \
                        --password-stdin \
                        ${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

                        echo "ECR Login Successful"
                    '''
                }
            }
        }

        stage('Tag Images') {
            steps {
                sh '''
                    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

                    for IMAGE in auth admin chat streaming frontend
                    do
                        docker tag streamingapp-$IMAGE:latest \
                        ${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/streamingapp-$IMAGE:${BUILD_NUMBER}
                    done
                '''
            }
        }

        stage('Push Images') {
            steps {
                sh '''
                    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

                    for IMAGE in auth admin chat streaming frontend
                    do
                        docker push \
                        ${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/streamingapp-$IMAGE:${BUILD_NUMBER}
                    done
                '''
            }
        }

        stage('Deploy to EKS') {
            steps {
		                
		withCredentials([
		    string(credentialsId: 'RANJEET_JWT_SECRET', variable: 'JWT_SECRET'),
		    string(credentialsId: 'RANJEET_AWS_ACCESS_KEY_ID', variable: 'AWS_ACCESS_KEY_ID'),
		    string(credentialsId: 'RANJEET_AWS_SECRET_ACCESS_KEY', variable: 'AWS_SECRET_ACCESS_KEY')
		]) {		


			sh '''
	                aws eks update-kubeconfig \
	                  --region ap-south-1 \
	                  --name streamingapp-eks
	                  
	                ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

			kubectl create secret generic streamingapp-secret \
			  --namespace streamingapp \
			  --from-literal=JWT_SECRET="$JWT_SECRET" \
			  --from-literal=AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID" \
			  --from-literal=AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY" \
			  --dry-run=client -o yaml | kubectl apply -f -                

			helm upgrade --install streamingapp ./helm/streamingapp \
	                  -n streamingapp \
	                  --create-namespace \
	                  --set accountId=$ACCOUNT_ID \
	                  --set images.auth.tag=$BUILD_NUMBER \
	                  --set images.streaming.tag=$BUILD_NUMBER \
	                  --set images.admin.tag=$BUILD_NUMBER \
	                  --set images.chat.tag=$BUILD_NUMBER \
	                  --set images.frontend.tag=$BUILD_NUMBER
	                '''
		    }
	      }
        }
    }

    post {

        success {
            echo "Images pushed successfully."
        }

        failure {
            echo "Pipeline failed."
        }

        always {
            sh 'docker image prune -f || true'
        }
    }
}
