pipeline {

    agent any

    options {
        skipDefaultCheckout(true)
        timestamps()
    }

    environment {

        // ==========================================
        // Python
        // ==========================================
        PYTHON = "/var/lib/jenkins/.pyenv/versions/3.7.17/bin/python"

        // ==========================================
        // Docker
        // ==========================================
        IMAGE_NAME = "had"
        IMAGE_TAG = "${BUILD_NUMBER}"

        CONTAINER_NAME = "had-app"
        VOLUME_NAME = "had-venv"

        // ==========================================
        // Azure Container Registry
        // ==========================================
        ACR_LOGIN_SERVER = "teammaverick.azurecr.io"
    }

    stages {

        // =========================================================
        // 1. CHECKOUT
        // =========================================================
        stage('Checkout') {

            steps {

                echo "=============================="
                echo "Checking out source code"
                echo "=============================="

                git(
                    branch: 'main',
                    url: 'https://github.com/sanjugm/Human-Activity-Detection.git'
                )

                sh '''
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


        // =========================================================
        // 2. CREATE VIRTUAL ENVIRONMENT
        // =========================================================
        stage('Create Virtual Environment') {

            steps {

                sh '''
                    set -eux

                    echo "=============================="
                    echo "Python Version"
                    echo "=============================="

                    $PYTHON --version

                    echo "=============================="
                    echo "Removing old virtual environment"
                    echo "=============================="

                    rm -rf venv

                    echo "=============================="
                    echo "Creating virtual environment"
                    echo "=============================="

                    $PYTHON -m venv venv

                    echo "=============================="
                    echo "Activating virtual environment"
                    echo "=============================="

                    . venv/bin/activate

                    python --version
                    pip --version
                '''
            }
        }


        // =========================================================
        // 3. INSTALL DEPENDENCIES
        // =========================================================
        stage('Install Dependencies') {

            steps {

                sh '''
                    set -eux

                    . venv/bin/activate

                    echo "=============================="
                    echo "Python"
                    echo "=============================="

                    python --version
                    pip --version

                    echo "=============================="
                    echo "Installing requirements.txt"
                    echo "=============================="

                    pip install \
                        --no-cache-dir \
                        --default-timeout=1000 \
                        -r requirements.txt

                    echo "=============================="
                    echo "Installing six"
                    echo "=============================="

                    pip install \
                        --no-cache-dir \
                        six

                    echo "=============================="
                    echo "Installing Detectron2"
                    echo "=============================="

                    pip install \
                        --no-cache-dir \
                        --default-timeout=1000 \
                        detectron2==0.6 \
                        -f https://dl.fbaipublicfiles.com/detectron2/wheels/cpu/torch1.8/index.html

                    echo "=============================="
                    echo "Installed Packages"
                    echo "=============================="

                    pip list
                '''
            }
        }


        // =========================================================
        // 4. VERIFY PYTHON APPLICATION
        // =========================================================
        stage('Verify Application') {

            steps {

                sh '''
                    set -e

                    . venv/bin/activate

                    echo "=============================="
                    echo "Python Version"
                    echo "=============================="

                    python --version

                    echo "=============================="
                    echo "Testing PyTorch"
                    echo "=============================="

                    python -c "import torch; print('Torch:', torch.__version__)"

                    echo "=============================="
                    echo "Testing TorchVision"
                    echo "=============================="

                    python -c "import torchvision; print('TorchVision:', torchvision.__version__)"

                    echo "=============================="
                    echo "Testing Detectron2"
                    echo "=============================="

                    python -c "import detectron2; print('Detectron2 imported successfully')"

                    echo "=============================="
                    echo "Starting Flask Application"
                    echo "=============================="

                    nohup python app.py > app.log 2>&1 &

                    APP_PID=$!

                    echo "Application PID: $APP_PID"

                    echo "Waiting for application startup..."

                    sleep 10

                    echo "=============================="
                    echo "Checking Application Process"
                    echo "=============================="

                    if kill -0 $APP_PID 2>/dev/null; then

                        echo "Application is running"

                    else

                        echo "Application failed to start"

                        echo "=============================="
                        echo "Application Logs"
                        echo "=============================="

                        cat app.log

                        exit 1

                    fi

                    echo "=============================="
                    echo "Application Logs"
                    echo "=============================="

                    cat app.log || true

                    echo "=============================="
                    echo "Stopping test application"
                    echo "=============================="

                    kill $APP_PID 2>/dev/null || true
                '''
            }
        }


        // =========================================================
        // 5. SONARQUBE ANALYSIS
        // =========================================================
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

                        echo "=============================="
                        echo "SonarQube Analysis Completed"
                        echo "=============================="
                    '''
                }
            }
        }


        // =========================================================
        // 6. QUALITY GATE
        // =========================================================
        stage('Quality Gate') {

            steps {

                echo "Waiting for SonarQube Quality Gate..."

                timeout(
                    time: 5,
                    unit: 'MINUTES'
                ) {

                    waitForQualityGate(
                        abortPipeline: true
                    )
                }

                echo "SonarQube Quality Gate Passed"
            }
        }


        // =========================================================
        // 7. BUILD DOCKER IMAGE
        // =========================================================
        stage('Build Docker Image') {

            steps {

                sh '''
                    set -e

                    echo "=============================="
                    echo "Building Docker Image"
                    echo "=============================="

                    echo "Image:"
                    echo "${IMAGE_NAME}:${IMAGE_TAG}"

                    docker build \
                        -t ${IMAGE_NAME}:${IMAGE_TAG} .

                    echo "=============================="
                    echo "Docker Image Created"
                    echo "=============================="

                    docker images ${IMAGE_NAME}
                '''
            }
        }


        // =========================================================
        // 8. PUSH DOCKER IMAGE TO ACR
        // =========================================================
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
                        echo "Logging in to ACR"
                        echo "=============================="

                        echo "$ACR_PASSWORD" | docker login ${ACR_LOGIN_SERVER} \
                            -u "$ACR_USERNAME" \
                            --password-stdin

                        echo "ACR login successful"

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

                        echo "=============================="
                        echo "Image pushed successfully"
                        echo "=============================="

                        echo "${ACR_LOGIN_SERVER}/had:${IMAGE_TAG}"
                    '''
                }
            }
        }


        // =========================================================
        // 9. STOP OLD CONTAINER
        // =========================================================
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


        // =========================================================
        // 10. CREATE DOCKER VOLUME
        // =========================================================
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


        // =========================================================
        // 11. RUN UPDATED CONTAINER
        // =========================================================
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


        // =========================================================
        // 12. VERIFY CONTAINER
        // =========================================================
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

                    echo "=============================="
                    echo "Checking Container State"
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


    // =========================================================
    // POST ACTIONS
    // =========================================================
    post {

        success {

            echo "========================================"
            echo "CI/CD PIPELINE SUCCESSFUL"
            echo "========================================"

            echo "Build Number: ${BUILD_NUMBER}"

            echo "Docker Image:"
            echo "${ACR_LOGIN_SERVER}/had:${IMAGE_TAG}"

            echo "Container:"
            echo "${CONTAINER_NAME}"
        }

        failure {

            echo "========================================"
            echo "CI/CD PIPELINE FAILED"
            echo "========================================"

            echo "Build Number: ${BUILD_NUMBER}"

            echo "Check the failed stage above."
        }

        always {

            echo "========================================"
            echo "Pipeline Completed"
            echo "========================================"
        }
    }
}
