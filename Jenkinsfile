pipeline {
    agent any
    environment {
        PATH = "$HOME/.local/bin:$PATH"
        IMAGE_NAME = "had"
        CONTAINER_NAME = "had-app"
        VOLUME_NAME = "had-venv"
    }
    stages {
        stage('Build Python .Whl file') {
            steps {
                sh '''
                    set -eux
                    curl -LsSf https://astral.sh/uv/install.sh | sh
                    uv python install 3.10
                    which python3.10 
                    python3.10 --version
                    rm -rf .venv
                    uv venv --python 3.10
                    rm -rf dist build *.egg-info
                    uv build
                '''
                script {
                    env.IMAGE_TAG = sh(
                        script: '''
                            sed -n 's/^version = "\\([^"]*\\)"/\\1/p' pyproject.toml
                        ''',
                        returnStdout: true
                    ).trim()
                    if (!env.IMAGE_TAG) {
                        error "Version not found in pyproject.toml"
                    }

            echo "Application version: ${env.IMAGE_TAG}"
            }
        }
        }
        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('SonarQubeHAD') {
                    sh '''
                    /opt/sonar-scanner/bin/sonar-scanner \
                -Dsonar.projectKey=had \
                  -Dsonar.projectName=had \
                  -Dsonar.sources=src,app.py \
                  -Dsonar.exclusions="*/.ipynb,*/.mp4,*/.lock,models/*,images/,dist/,.egg-info/**"

                    '''
                }
            }
        }

        stage('Quality Gate') {
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }
        stage('Build Docker Image') {
            steps {
                sh '''
                    docker build \
                        -t ${IMAGE_NAME}:${IMAGE_TAG} .
                '''
            }
        }
        stage('Push Docker Image to ACR') {
    steps {
        withCredentials([
                    usernamePassword(
                        credentialsId: 'acr-service-principal',
                        usernameVariable: 'ACR_USERNAME',
                        passwordVariable: 'ACR_PASSWORD'
            )
        ]) {
            sh '''
                set -e

                echo "$ACR_PASSWORD" | docker login teammaverick.azurecr.io \
                    -u "$ACR_USERNAME" \
                    --password-stdin
                docker tag ${IMAGE_NAME}:${IMAGE_TAG} teammaverick.azurecr.io/had:${IMAGE_TAG}

                docker push teammaverick.azurecr.io/had:${IMAGE_TAG}
            '''
        }
    }
}
        stage('Stop Old Container') {
            steps {
                sh '''
                    docker rm -f ${CONTAINER_NAME} || true
                    echo "Removing previous stopped container..."
                    docker rm -f had-app 2>/dev/null || true
                '''
            }
        }
        stage('Create Docker Volume') {
    steps {
        sh '''
            if docker volume inspect had-venv >/dev/null 2>&1; then
                echo "Docker volume 'had-venv' already exists"
            else
                echo "Creating Docker volume 'had-venv'"
                docker volume create had-venv
            fi
        '''
    }
}
                stage('Run Updated Container') {
            steps {
                sh '''
                    docker run -d \
                        --name ${CONTAINER_NAME} \
                        -p 5000:5000 \
                        -v ${VOLUME_NAME}:/app/.venv \
                        ${IMAGE_NAME}:${IMAGE_TAG}
                '''
            }
        }
    }
}
