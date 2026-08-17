pipeline {

    agent any

    environment {

        // Python selected through pyenv
        PYTHON = "/home/sanju/.pyenv/versions/3.7.17/bin/python"

        IMAGE_NAME = "had"
        IMAGE_TAG = "${BUILD_NUMBER}"

        CONTAINER_NAME = "had-app"
        VOLUME_NAME = "had-venv"

        ACR_LOGIN_SERVER = "teammaverick.azurecr.io"
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm

                sh '''
                    set -e

                    echo "=============================="
                    echo "Git Information"
                    echo "=============================="

                    git branch --show-current
                    git rev-parse HEAD

                    echo "=============================="
                    echo "Project Files"
                    echo "=============================="

                    ls -la
                '''
            }
        }

        stage('Create Virtual Environment') {
            steps {
                sh '''
                    set -e

                    echo "=============================="
                    echo "Python Version"
                    echo "=============================="

                    ${PYTHON} --version

                    echo "=============================="
                    echo "Creating Virtual Environment"
                    echo "=============================="

                    rm -rf .venv

                    ${PYTHON} -m venv .venv

                    . .venv/bin/activate

                    python --version
                    python -m pip --version
                '''
            }
        }

        stage('Install Dependencies') {
            steps {
                sh '''
                    set -e

                    . .venv/bin/activate

                    echo "=============================="
                    echo "Installing Dependencies"
                    echo "=============================="

                    python -m pip install \
                        --no-cache-dir \
                        -r requirements.txt

                    echo "=============================="
                    echo "Dependencies Installed"
                    echo "=============================="

                    python -m pip list
                '''
            }
        }

        stage('Verify Application') {
            steps {
                sh '''
                    set -e

                    . .venv/bin/activate

                    echo "=============================="
                    echo "Python"
                    echo "=============================="

                    python --version

                    echo "=============================="
                    echo "PyTorch"
                    echo "=============================="

                    python -c "import torch; print('Torch:', torch.__version__)"

                    echo "=============================="
                    echo "TorchVision"
                    echo "=============================="

                    python -c "import torchvision; print('TorchVision:', torchvision.__version__)"

                    echo "=============================="
                    echo "six"
                    echo "=============================="

                    python -c "import six; print('six:', six.__version__)"

                    echo "=============================="
                    echo "Detectron2"
                    echo "=============================="

                    python -c "import detectron2; print('Detectron2: OK')"

                    echo "=============================="
                    echo "Starting Application"
                    echo "=============================="

                    nohup python app.py > app.log 2>&1 &

                    APP_PID=$!

                    echo "Application PID: ${APP_PID}"

                    sleep 10

                    if kill -0 ${APP_PID} 2>/dev/null; then
                        echo "Application started successfully"
                    else
                        echo "Application failed to start"
                        cat app.log
                        exit 1
                    fi

                    echo "=============================="
                    echo "Application Logs"
                    echo "=============================="

                    cat app.log || true

                    kill ${APP_PID} 2>/dev/null || true
                '''
            }
        }

        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('SonarQubeHAD') {
                    sh '''
                        set -e

                        echo "=============================="
                        echo "SonarQube Analysis"
                        echo "=============================="

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
                        echo "Login to ACR"
                        echo "=============================="

                        echo "$ACR_PASSWORD" | docker login ${ACR_LOGIN_SERVER} \
                            -u "$ACR_USERNAME" \
                            --password-stdin

                        echo "=============================="
                        echo "Tagging Image"
                        echo "=============================="

                        docker tag \
                            ${IMAGE_NAME}:${IMAGE_TAG} \
                            ${ACR_LOGIN_SERVER}/had:${IMAGE_TAG}

                        echo "=============================="
                        echo "Pushing Image"
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

                    echo "Stopping old container..."

                    docker rm -f ${CONTAINER_NAME} 2>/dev/null || true
                '''
            }
        }

        stage('Create Docker Volume') {
            steps {
                sh '''
                    set -e

                    if docker volume inspect ${VOLUME_NAME} >/dev/null 2>&1; then
                        echo "Volume ${VOLUME_NAME} already exists"
                    else
                        echo "Creating volume ${VOLUME_NAME}"
                        docker volume create ${VOLUME_NAME}
                    fi
                '''
            }
        }

        stage('Run Updated Container') {
            steps {
                sh '''
                    set -e

                    echo "=============================="
                    echo "Starting Container"
                    echo "=============================="

                    docker run -d \
                        --name ${CONTAINER_NAME} \
                        -p 5000:5000 \
                        -v ${VOLUME_NAME}:/app/.venv \
                        ${IMAGE_NAME}:${IMAGE_TAG}

                    docker ps
                '''
            }
        }

        stage('Verify Container') {
            steps {
                sh '''
                    set -e

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

                    echo "=============================="
                    echo "Container State"
                    echo "=============================="

                    RUNNING=$(docker inspect \
                        -f '{{.State.Running}}' \
                        ${CONTAINER_NAME})

                    if [ "$RUNNING" = "true" ]; then
                        echo "Container is running successfully"
                    else
                        echo "Container is NOT running"
                        exit 1
                    fi
                '''
            }
        }
    }

    post {

        success {
            echo "========================================"
            echo "CI/CD PIPELINE SUCCESSFUL"
            echo "========================================"

            echo "Build Number: ${BUILD_NUMBER}"
            echo "Image: ${ACR_LOGIN_SERVER}/had:${IMAGE_TAG}"
            echo "Container: ${CONTAINER_NAME}"
        }

        failure {
            echo "========================================"
            echo "CI/CD PIPELINE FAILED"
            echo "========================================"
        }

        always {
            echo "========================================"
            echo "Pipeline Completed"
            echo "========================================"
        }
    }
}
