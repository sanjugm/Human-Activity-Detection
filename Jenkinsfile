pipeline {
    agent any

    environment {
        PATH = "$HOME/.local/bin:$PATH"

        IMAGE_NAME = "had"
        IMAGE_TAG = "${BUILD_NUMBER}"

        CONTAINER_NAME = "had-app"
        VOLUME_NAME = "had-venv"

        ACR_LOGIN_SERVER = "teammaverick.azurecr.io"
    }

    stages {

        stage('Build Python Application') {
            steps {
                sh '''
                    set -eux

                    echo "=============================="
                    echo "Installing uv"
                    echo "=============================="

                    curl -LsSf https://astral.sh/uv/install.sh | sh

                    export PATH="$HOME/.local/bin:$PATH"

                    uv --version

                    echo "=============================="
                    echo "Installing Python 3.10"
                    echo "=============================="

                    uv python install 3.10

                    which python3.10
                    python3.10 --version

                    echo "=============================="
                    echo "Creating Virtual Environment"
                    echo "=============================="

                    rm -rf .venv

                    uv venv --python 3.10

                    echo "=============================="
                    echo "Installing Dependencies"
                    echo "=============================="

                    uv pip install --python .venv/bin/python -r requirements.txt

                    echo "=============================="
                    echo "Python Application Build Completed"
                    echo "=============================="

                    echo "Application Version: ${IMAGE_TAG}"
                '''
            }
        }


        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('SonarQubeHAD') {

                    sh '''
                        set -e

                        /opt/sonar-scanner/bin/sonar-scanner \
                            -Dsonar.projectKey=had \
                            -Dsonar.projectName=had \
                            -Dsonar.sources=src,app.py \
                            -Dsonar.exclusions="**/*.ipynb,**/*.mp4,**/*.lock,models/**,images/**,dist/**,*.egg-info/**"
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
                    set -e

                    echo "=============================="
                    echo "Building Docker Image"
                    echo "=============================="

                    docker build \
                        -t ${IMAGE_NAME}:${IMAGE_TAG} .

                    echo "=============================="
                    echo "Docker Image Created"
                    echo "=============================="

                    docker images ${IMAGE_NAME}
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

                        echo "=============================="
                        echo "Login to Azure Container Registry"
                        echo "=============================="

                        echo "$ACR_PASSWORD" | docker login ${ACR_LOGIN_SERVER} \
                            -u "$ACR_USERNAME" \
                            --password-stdin

                        echo "=============================="
                        echo "Tagging Docker Image"
                        echo "=============================="

                        docker tag \
                            ${IMAGE_NAME}:${IMAGE_TAG} \
                            ${ACR_LOGIN_SERVER}/had:${IMAGE_TAG}

                        echo "=============================="
                        echo "Pushing Docker Image"
                        echo "=============================="

                        docker push \
                            ${ACR_LOGIN_SERVER}/had:${IMAGE_TAG}
                    '''
                }
            }
        }


        stage('Stop Old Container') {
            steps {

                sh '''
                    set +e

                    echo "=============================="
                    echo "Stopping Old Container"
                    echo "=============================="

                    docker rm -f ${CONTAINER_NAME} 2>/dev/null || true

                    echo "Old container removed if it existed."
                '''
            }
        }


        stage('Create Docker Volume') {
            steps {

                sh '''
                    set -e

                    echo "=============================="
                    echo "Checking Docker Volume"
                    echo "=============================="

                    if docker volume inspect ${VOLUME_NAME} >/dev/null 2>&1; then

                        echo "Docker volume '${VOLUME_NAME}' already exists"

                    else

                        echo "Creating Docker volume '${VOLUME_NAME}'"

                        docker volume create ${VOLUME_NAME}
                    fi

                    echo "=============================="
                    echo "Docker Volumes"
                    echo "=============================="

                    docker volume ls
                '''
            }
        }


        stage('Run Updated Container') {
            steps {

                sh '''
                    set -e

                    echo "=============================="
                    echo "Starting Updated Container"
                    echo "=============================="

                    docker run -d \
                        --name ${CONTAINER_NAME} \
                        -p 5000:5000 \
                        -v ${VOLUME_NAME}:/app/.venv \
                        ${IMAGE_NAME}:${IMAGE_TAG}

                    echo "=============================="
                    echo "Container Started"
                    echo "=============================="

                    docker ps
                '''
            }
        }


        stage('Verify Container') {
            steps {

                sh '''
                    set -e

                    echo "=============================="
                    echo "Waiting for Container"
                    echo "=============================="

                    sleep 10

                    echo "=============================="
                    echo "Container Status"
                    echo "=============================="

                    docker ps -a \
                        --filter "name=${CONTAINER_NAME}"

                    echo "=============================="
                    echo "Container Logs"
                    echo "=============================="

                    docker logs ${CONTAINER_NAME}
                '''
            }
        }
    }
}
