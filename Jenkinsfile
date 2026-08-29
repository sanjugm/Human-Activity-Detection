pipeline {

agent {
        label 'linux-wsl'
    }
    environment {

        PYTHON = "C:\\Users\\sanju\\AppData\\Local\\Programs\\Python\\Python37\\python.exe"

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

                bat '''
                    echo ========================================
                    echo Git Information
                    echo ========================================

                    git branch --show-current
                    git rev-parse HEAD

                    echo.
                    echo ========================================
                    echo Project Files
                    echo ========================================

                    dir
                '''
            }
        }

        stage('Check Python') {
            steps {
                bat '''
                    echo ========================================
                    echo Python Version
                    echo ========================================

                    "%PYTHON%" --version

                    if %ERRORLEVEL% NEQ 0 (
                        echo Python 3.7 was not found.
                        exit /b 1
                    )
                '''
            }
        }

        stage('Create Virtual Environment') {
            steps {
                bat '''
                    echo ========================================
                    echo Creating Virtual Environment
                    echo ========================================

                    if exist .venv (
                        rmdir /s /q .venv
                    )

                    "%PYTHON%" -m venv .venv

                    .venv\\Scripts\\python.exe --version
                    .venv\\Scripts\\pip.exe --version
                '''
            }
        }

        stage('Install Dependencies') {
            steps {
                bat '''
                    echo ========================================
                    echo Installing Dependencies
                    echo ========================================

                    .venv\\Scripts\\python.exe -m pip install ^
                        --no-cache-dir ^
                        -r requirements.txt

                    echo.
                    echo ========================================
                    echo Installing six
                    echo ========================================

                    .venv\\Scripts\\python.exe -m pip install ^
                        --no-cache-dir ^
                        six

                    echo.
                    echo ========================================
                    echo Installed Packages
                    echo ========================================

                    .venv\\Scripts\\pip.exe list
                '''
            }
        }

        stage('Verify Python Application') {
            steps {
                bat '''
                    echo ========================================
                    echo Python
                    echo ========================================

                    .venv\\Scripts\\python.exe --version

                    echo.
                    echo ========================================
                    echo PyTorch
                    echo ========================================

                    .venv\\Scripts\\python.exe -c "import torch; print('Torch:', torch.__version__)"

                    echo.
                    echo ========================================
                    echo TorchVision
                    echo ========================================

                    .venv\\Scripts\\python.exe -c "import torchvision; print('TorchVision:', torchvision.__version__)"

                    echo.
                    echo ========================================
                    echo six
                    echo ========================================

                    .venv\\Scripts\\python.exe -c "import six; print('six:', six.__version__)"

                    echo.
                    echo ========================================
                    echo Detectron2
                    echo ========================================

                    .venv\\Scripts\\python.exe -c "import detectron2; print('Detectron2: OK')"
                '''
            }
        }

        stage('Run Application Test') {
            steps {
                bat '''
                    echo ========================================
                    echo Starting Application
                    echo ========================================

                    start "" /B .venv\\Scripts\\python.exe app.py > app.log 2>&1

                    timeout /t 10 /nobreak

                    echo.
                    echo ========================================
                    echo Application Logs
                    echo ========================================

                    if exist app.log (
                        type app.log
                    )

                    echo.
                    echo ========================================
                    echo Checking Application Process
                    echo ========================================

                    tasklist | findstr /I "python.exe"

                    echo.
                    echo Stopping Test Application
                    echo ========================================

                    taskkill /F /IM python.exe >nul 2>&1 || echo Python process already stopped.
                '''
            }
        }

        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('SonarQubeHAD') {

                    bat '''
                        echo ========================================
                        echo SonarQube Analysis
                        echo ========================================

                        sonar-scanner.bat ^
                            -Dsonar.projectKey=had ^
                            -Dsonar.projectName=had ^
                            -Dsonar.sources=src,app.py ^
                            -Dsonar.exclusions="**/*.ipynb,**/*.mp4,**/*.lock,models/**,images/**,dist/**,*.egg-info/**"
                    '''
                }
            }
        }

        stage('Quality Gate') {
            steps {

                timeout(
                    time: 5,
                    unit: 'MINUTES'
                ) {

                    waitForQualityGate abortPipeline: true
                }
            }
        }

        stage('Build Docker Image') {
            steps {

                bat '''
                    echo ========================================
                    echo Building Docker Image
                    echo ========================================

                    docker build ^
                        -t %IMAGE_NAME%:%IMAGE_TAG% .

                    echo.
                    echo ========================================
                    echo Docker Images
                    echo ========================================

                    docker images %IMAGE_NAME%
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

                    bat '''
                        echo ========================================
                        echo Login to ACR
                        echo ========================================

                        docker login %ACR_LOGIN_SERVER% ^
                            -u "%ACR_USERNAME%" ^
                            -p "%ACR_PASSWORD%"

                        if %ERRORLEVEL% NEQ 0 (
                            echo ACR login failed.
                            exit /b 1
                        )

                        echo.
                        echo ========================================
                        echo Tagging Image
                        echo ========================================

                        docker tag ^
                            %IMAGE_NAME%:%IMAGE_TAG% ^
                            %ACR_LOGIN_SERVER%/had:%IMAGE_TAG%

                        echo.
                        echo ========================================
                        echo Pushing Image
                        echo ========================================

                        docker push ^
                            %ACR_LOGIN_SERVER%/had:%IMAGE_TAG%
                    '''
                }
            }
        }

        stage('Stop Old Container') {
            steps {

                bat '''
                    echo ========================================
                    echo Stopping Old Container
                    echo ========================================

                    docker rm -f %CONTAINER_NAME% 2>nul || echo No old container found.
                '''
            }
        }

        stage('Create Docker Volume') {
            steps {

                bat '''
                    echo ========================================
                    echo Checking Docker Volume
                    echo ========================================

                    docker volume inspect %VOLUME_NAME% >nul 2>&1

                    if %ERRORLEVEL% EQU 0 (

                        echo Volume already exists:
                        echo %VOLUME_NAME%

                    ) else (

                        echo Creating volume:
                        echo %VOLUME_NAME%

                        docker volume create %VOLUME_NAME%
                    )
                '''
            }
        }

        stage('Run Updated Container') {
            steps {

                bat '''
                    echo ========================================
                    echo Starting Updated Container
                    echo ========================================

                    docker run -d ^
                        --name %CONTAINER_NAME% ^
                        -p 5000:5000 ^
                        -v %VOLUME_NAME%:/app/.venv ^
                        %IMAGE_NAME%:%IMAGE_TAG%

                    echo.
                    echo ========================================
                    echo Running Containers
                    echo ========================================

                    docker ps
                '''
            }
        }

        stage('Verify Container') {
            steps {

                bat '''
                    echo ========================================
                    echo Waiting for Container
                    echo ========================================

                    timeout /t 10 /nobreak

                    echo.
                    echo ========================================
                    echo Container Status
                    echo ========================================

                    docker ps -a --filter "name=%CONTAINER_NAME%"

                    echo.
                    echo ========================================
                    echo Container Logs
                    echo ========================================

                    docker logs %CONTAINER_NAME%

                    echo.
                    echo ========================================
                    echo Container State
                    echo ========================================

                    docker inspect %CONTAINER_NAME% --format="{{.State.Running}}"
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
