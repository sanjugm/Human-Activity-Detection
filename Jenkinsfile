pipeline {
    agent any

    environment {

        // Python 3.7.17 installed on Jenkins server
        PYTHON = "/var/lib/jenkins/.pyenv/versions/3.7.17/bin/python"

        IMAGE_NAME = "had"
        IMAGE_TAG = "${BUILD_NUMBER}"

        CONTAINER_NAME = "had-app"
        VOLUME_NAME = "had-venv"

        ACR_LOGIN_SERVER = "teammaverick.azurecr.io"
    }

    stages {

        // =====================================================
        // 1. Checkout
        // =====================================================
        stage('Checkout') {
            steps {

                git branch: 'main',
                    url: 'https://github.com/sanjugm/Human-Activity-Detection.git'

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


        // =====================================================
        // 2. Create Virtual Environment
        // =====================================================
        stage('Create Virtual Environment') {
            steps {

                sh '''
                    set -eux

                    echo "=============================="
                    echo "Python Version"
                    echo "=============================="

                    $PYTHON --version

                    echo "=============================="
                    echo "Creating Virtual Environment"
                    echo "=============================="

                    rm -rf venv

                    $PYTHON -m venv venv

                    . venv/bin/activate

                    python --version
                    pip --version
                '''
            }
        }


        // =====================================================
        // 3. Install Dependencies
        // =====================================================
        stage('Install Dependencies') {
            steps {

                sh '''
                    set -eux

                    . venv/bin/activate

                    echo "=============================="
                    echo "Upgrading pip"
                    echo "=============================="

                    pip install --upgrade pip

                    echo "=============================="
                    echo "Installing requirements.txt"
                    echo "=============================="

                    pip install -r requirements.txt

                    echo "=============================="
                    echo "Installing six"
                    echo "=============================="

                    pip install six

                    echo "=============================="
                    echo "Installing Detectron2"
                    echo "=============================="

                    pip install detectron2==0.6 \
                        -f https://dl.fbaipublicfiles.com/detectron2/wheels/cpu/torch1.8/index.html

                    echo "=============================="
                    echo "Installed Packages"
                    echo "=============================="

                    pip list
                '''
            }
        }


        // =====================================================
        // 4. Verify Python Application
        // =====================================================
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
                    echo "Testing Application Import"
                    echo "=============================="

                    python -c "import torch; print('Torch:', torch.__version__)"
                    python -c "import torchvision; print('TorchVision:', torchvision.__version__)"
                    python -c "import detectron2; print('Detectron2 imported successfully')"

                    echo "=============================="
                    echo "Starting Flask Application"
                    echo "=============================="

                    nohup python app.py > app.log 2>&1 &

                    APP_PID=$!

                    echo "Application PID: $APP_PID"

                    echo "Waiting for application..."

                    sleep 15

                    echo "=============================="
                    echo "Application Process"
                    echo "=============================="

                    ps -ef | grep app.py | grep -v grep || true

                    echo "=============================="
                    echo "Application Logs"
                    echo "=============================="

                    cat app.log || true
                '''
            }
        }


        // =====================================================
        // 5. SonarQube Analysis
        // =====================================================
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


        // =====================================================
        // 6. Quality Gate
        // =====================================================
        stage('Quality Gate') {
            steps {

                timeout(time: 5, unit: 'MINUTES') {

                    waitForQualityGate abortPipeline: true
                }
            }
        }


        // =====================================================
        // 7. Build Docker Image
        // =====================================================
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


        // =====================================================
        // 8. Push Docker Image to ACR
        // =====================================================
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

                        echo "Image pushed successfully:"
                        echo "${ACR_LOGIN_SERVER}/had:${IMAGE_TAG}"
                    '''
                }
            }
        }


        // =====================================================
        // 9. Stop Old Container
        // =====================================================
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


        // =====================================================
        // 10. Create Docker Volume
        // =====================================================
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


        // =====================================================
        // 11. Run Updated Container
        // =====================================================
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


        // =====================================================
        // 12. Verify Container
        // =====================================================
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


    // =========================================================
    // Post Actions
    // =========================================================
    post {

        success {
            echo '================================'
            echo 'CI/CD Pipeline Successful'
            echo '================================'
            echo "Docker Image: ${ACR_LOGIN_SERVER}/had:${IMAGE_TAG}"
        }

        failure {
            echo '================================'
            echo 'CI/CD Pipeline Failed'
            echo '================================'
        }
    }
}
