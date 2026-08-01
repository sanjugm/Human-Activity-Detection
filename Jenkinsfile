pipeline {
    agent any

    environment {
        IMAGE_NAME = "human-activity"
        IMAGE_TAG  = "latest"

        DOCKER_REPO = "sanju2000/human-activity"

        SONARQUBE_ENV = "SonarQube"

        AZURE_VM = "20.244.13.187"       
        AZURE_USER = "azureuser"
    }

    stages {

        

        stage('Docker Build') {
            steps {
                sh '''
                docker build -t $DOCKER_REPO:$IMAGE_TAG .
                '''
            }
        }

     stage('Docker Login') {
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'dockerhub-creds',
                        usernameVariable: 'DOCKER_USER',
                        passwordVariable: 'DOCKER_PASS'
                    )
                ]) {
                    sh '''
                    echo $DOCKER_PASS | docker login -u $DOCKER_USER --password-stdin
                    '''
                }
            }
        }

        stage('Docker Push') {
            steps {
                sh '''
                docker push $DOCKER_REPO:$IMAGE_TAG
                '''
            }
        }

        stage('Deploy to Azure VM') {
    steps {
        sshagent(['azure-vm-ssh']) {
            sh '''
            ssh -o StrictHostKeyChecking=no azureuser@20.244.13.187 "
            docker pull sanjugm2000/human-activity:latest
            docker stop human-activity || true
            docker rm human-activity || true
            docker run -d --name human-activity -p 5000:5000 sanjugm2000/human-activity:latest
            "
            '''
        }
    }
}

    }

    post {

        success {
            echo 'Application Successfully Deployed'
        }

        failure {
            echo 'Pipeline Failed'
        }

        always {
            cleanWs()
        }
    }
}
