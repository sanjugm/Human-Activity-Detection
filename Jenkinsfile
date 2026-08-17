pipeline {

    agent any

    environment {
        PYTHON = "/home/azureuser/.pyenv/versions/3.7.17/bin/python"
    }

    options {
        skipDefaultCheckout(true)
        timestamps()
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm

                sh '''
                    echo "========================================"
                    echo "Git Information"
                    echo "========================================"

                    git --version
                    git branch --show-current
                    git rev-parse HEAD

                    echo "========================================"
                    echo "Project Files"
                    echo "========================================"

                    ls -la
                '''
            }
        }


        stage('Check Python') {
            steps {
                sh '''
                    echo "========================================"
                    echo "Python Version"
                    echo "========================================"

                    ${PYTHON} --version

                    echo "Python Path:"
                    which ${PYTHON}
                '''
            }
        }


        stage('Create Virtual Environment') {
            steps {
                sh '''
                    echo "========================================"
                    echo "Creating Virtual Environment"
                    echo "========================================"

                    rm -rf .venv

                    ${PYTHON} -m venv .venv

                    echo "Virtual Environment Created"

                    .venv/bin/python --version
                    .venv/bin/pip --version
                '''
            }
        }


        stage('Install Dependencies') {
            steps {
                sh '''
                    set -e

                    echo "========================================"
                    echo "Installing Dependencies"
                    echo "========================================"

                    .venv/bin/python -m pip install --upgrade "pip<24"

                    .venv/bin/pip install \
                        --no-cache-dir \
                        -r requirements.txt

                    echo "========================================"
                    echo "Checking Packages"
                    echo "========================================"

                    .venv/bin/python -c "import torch; print('Torch:', torch.__version__)"

                    .venv/bin/python -c "import torchvision; print('TorchVision:', torchvision.__version__)"

                    .venv/bin/python -c "import six; print('six:', six.__version__)"

                    .venv/bin/python -c "import cv2; print('OpenCV:', cv2.__version__)"

                    .venv/bin/python -c "import detectron2; print('Detectron2: OK')"
                '''
            }
        }


        stage('Run Application') {
            steps {
                sh '''
                    echo "========================================"
                    echo "Starting Flask Application"
                    echo "========================================"

                    rm -f app.log

                    .venv/bin/python app.py > app.log 2>&1 &

                    echo $! > app.pid

                    sleep 15

                    echo "========================================"
                    echo "Application Logs"
                    echo "========================================"

                    cat app.log
                '''
            }
        }


        stage('Verify Application') {
            steps {
                sh '''
                    echo "========================================"
                    echo "Verifying Application"
                    echo "========================================"

                    if kill -0 $(cat app.pid) 2>/dev/null
                    then
                        echo "Flask application is running"
                    else
                        echo "Flask application failed"
                        cat app.log
                        exit 1
                    fi

                    echo "========================================"
                    echo "Testing Port 5000"
                    echo "========================================"

                    curl -f http://127.0.0.1:5000/ || {

                        echo "Application is not responding"

                        cat app.log

                        exit 1
                    }

                    echo "========================================"
                    echo "Application Verification Successful"
                    echo "========================================"
                '''
            }
        }
    }


    post {

        always {
            sh '''
                if [ -f app.pid ]; then
                    kill $(cat app.pid) 2>/dev/null || true
                fi
            '''

            echo '''
========================================
Pipeline Completed
========================================
'''
        }

        success {
            echo '''
========================================
CI PIPELINE SUCCESSFUL
========================================
'''
        }

        failure {
            echo '''
========================================
CI PIPELINE FAILED
========================================
'''
        }
    }
}
