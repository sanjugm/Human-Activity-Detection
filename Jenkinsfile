pipeline {
    agent any

    stages {

        stage('Checkout') {
            steps {
                git branch: 'main',
                    url: 'https://github.com/sanjugm/Human-Activity-Detection.git'
            }
        }

        stage('Create Virtual Environment') {
            steps {
                sh '''
                pyenv local 3.7.17
                python -m venv venv
                '''
            }
        }

        stage('Install Dependencies') {
            steps {
                sh '''
                . venv/bin/activate
                pip install --upgrade pip
                pip install -r requirements.txt
                pip install six
                pip install detectron2==0.6 -f https://dl.fbaipublicfiles.com/detectron2/wheels/cpu/torch1.8/index.html
                '''
            }
        }

        stage('Verify Application') {
            steps {
                sh '''
                . venv/bin/activate
                python app.py &
                sleep 20
                pkill -f app.py || true
                '''
            }
        }
    }

    post {
        success {
            echo 'CI Pipeline Successful'
        }
        failure {
            echo 'CI Pipeline Failed'
        }
    }
}
