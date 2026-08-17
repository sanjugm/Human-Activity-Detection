pipeline {

    agent any

    environment {
        PYTHON = "/opt/python37/bin/python"
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

                    echo "Python Location:"
                    ${PYTHON} -c "import sys; print(sys.executable)"
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

            .venv/bin/pip install --no-cache-dir -r requirements.txt

            .venv/bin/pip install --no-cache-dir six

            echo "Installing Detectron2"

            .venv/bin/pip install \
                detectron2==0.6 \
                -f https://dl.fbaipublicfiles.com/detectron2/wheels/cu102/torch1.8/index.html

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
                    set -e

                    echo "========================================"
                    echo "Starting Flask Application"
                    echo "========================================"

                    rm -f app.log app.pid

                    .venv/bin/python app.py > app.log 2>&1 &

                    echo $! > app.pid

                    echo "Application PID:"
                    cat app.pid

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
                    set -e

                    echo "========================================"
                    echo "Verifying Application"
                    echo "========================================"

                    if kill -0 $(cat app.pid) 2>/dev/null
                    then
                        echo "Flask application is running"
                    else
                        echo "Flask application failed to start"
                        cat app.log
                        exit 1
                    fi

                    echo "========================================"
                    echo "Testing Port 5000"
                    echo "========================================"

                    curl -f http://127.0.0.1:5000/

                    echo ""
                    echo "Application verification successful"
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
