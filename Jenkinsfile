pipeline {

    agent any

    options {
        skipDefaultCheckout(true)
        timestamps()
    }

    environment {

        // =====================================================
        // Python 3.7.17
        // CHANGE THIS PATH IF YOUR PYTHON IS INSTALLED ELSEWHERE
        // =====================================================
        PYTHON = "C:\\Python37\\python.exe"

        // =====================================================
        // Docker
        // =====================================================
        IMAGE_NAME = "had"
        IMAGE_TAG = "${BUILD_NUMBER}"

        CONTAINER_NAME = "had-app"
        VOLUME_NAME = "had-venv"

        // =====================================================
        // ACR
        // =====================================================
        ACR_LOGIN_SERVER = "teammaverick.azurecr.io"
    }

    stages {

        // =====================================================
        // 1. CHECKOUT
        // =====================================================
        stage('Checkout') {

            steps {

                echo "========================================"
                echo "Checking out source code"
                echo "========================================"

                git(
                    branch: 'main',
                    url: 'https://github.com/sanjugm/Human-Activity-Detection.git'
                )

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


        // =====================================================
        // 2. CREATE VIRTUAL ENVIRONMENT
        // =====================================================
        stage('Create Virtual Environment') {

            steps {

                bat '''
                    echo ========================================
                    echo Python Version
                    echo ========================================

                    "%PYTHON%" --version

                    echo.
                    echo ========================================
                    echo Removing Old Virtual Environment
                    echo ========================================

                    if exist venv (
                        rmdir /s /q venv
                    )

                    echo.
                    echo ========================================
                    echo Creating Virtual Environment
                    echo ========================================

                    "%PYTHON%" -m venv venv

                    echo.
                    echo Virtual environment created.

                    venv\\Scripts\\python.exe --version
                    venv\\Scripts\\pip.exe --version
                '''
            }
        }


        // =====================================================
        // 3. INSTALL DEPENDENCIES
        // =====================================================
        stage('Install Dependencies') {

            steps {

                bat '''
                    echo ========================================
                    echo Installing requirements.txt
                    echo ========================================

                    venv\\Scripts\\pip.exe install ^
                        --no-cache-dir ^
                        --default-timeout=1000 ^
                        -r requirements.txt

                    echo.
                    echo ========================================
                    echo Installing six
                    echo ========================================

                    venv\\Scripts\\pip.exe install ^
                        --no-cache-dir ^
                        six

                    echo.
                    echo ========================================
                    echo Installing Detectron2
                    echo ========================================

                    venv\\Scripts\\pip.exe install ^
                        --no-cache-dir ^
                        --default-timeout=1000 ^
                        detectron2==0.6 ^
                        -f https://dl.fbaipublicfiles.com/detectron2/wheels/cpu/torch1.8/index.html

                    echo.
                    echo ========================================
                    echo Installed Packages
                    echo ========================================

                    venv\\Scripts\\pip.exe list
                '''
            }
        }


        // =====================================================
        // 4. VERIFY PYTHON APPLICATION
        // =====================================================
        stage('Verify Application') {

            steps {

                bat '''
                    echo ========================================
                    echo Python Version
                    echo ========================================

                    venv\\Scripts\\python.exe --version

                    echo.
                    echo ========================================
                    echo Testing PyTorch
                    echo ========================================

                    venv\\Scripts\\python.exe -c "import torch; print('Torch:', torch.__version__)"

                    echo.
                    echo ========================================
                    echo Testing TorchVision
                    echo ========================================

                    venv\\Scripts\\python.exe -c "import torchvision; print('TorchVision:', torchvision.__version__)"

                    echo.
                    echo ========================================
                    echo Testing Detectron2
                    echo ========================================

                    venv\\Scripts\\python.exe -c "import detectron2; print('Detectron2 imported successfully')"

                    echo.
                    echo ========================================
                    echo Starting Flask Application
                    echo ========================================

                    start "" /B venv\\Scripts\\python.exe app.py > app.log 2>&1

                    echo Application started.

                    timeout /t 10 /nobreak

                    echo.
                    echo ========================================
                    echo Application Logs
                    echo ========================================

                    type app.log
                '''
            }
        }


        // =====================================================
        // 5. SONARQUBE ANALYSIS
        // =====================================================
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

                        echo.
                        echo ========================================
                        echo SonarQube Analysis Completed
                        echo ========================================
                    '''
                }
            }
        }


        // =====================================================
        // 6. QUALITY GATE
        // =====================================================
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


        // =====================================================
        // 7. BUILD DOCKER IMAGE
        // =====================================================
        stage('Build Docker Image') {

            steps {

                bat '''
                    echo ========================================
                    echo Building Docker Image
                    echo ========================================

                    echo Image:
                    echo %IMAGE_NAME%:%IMAGE_TAG%

                    docker build ^
                        -t %IMAGE_NAME%:%IMAGE_TAG% .

                    echo.
                    echo ========================================
                    echo Docker Image Created
                    echo ========================================

                    docker images %IMAGE_NAME%
                '''
            }
        }


        // =====================================================
        // 8. PUSH IMAGE TO ACR
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

                    bat '''
                        echo ========================================
                        echo Login to Azure Container Registry
                        echo ========================================

                        docker login %ACR_LOGIN_SERVER% ^
                            -u "%ACR_USERNAME%" ^
                            -p "%ACR_PASSWORD%"

                        echo.
                        echo ACR login successful.

                        echo ========================================
                        echo Tagging Docker Image
                        echo ========================================

                        docker tag ^
                            %IMAGE_NAME%:%IMAGE_TAG% ^
                            %ACR_LOGIN_SERVER%/had:%IMAGE_TAG%

                        echo.
                        echo ========================================
                        echo Pushing Docker Image
                        echo ========================================

                        docker push ^
                            %ACR_LOGIN_SERVER%/had:%IMAGE_TAG%

                        echo.
                        echo ========================================
                        echo Image pushed successfully
                        echo ========================================

                        echo %ACR_LOGIN_SERVER%/had:%IMAGE_TAG%
                    '''
                }
            }
        }


        // =====================================================
        // 9. STOP OLD CONTAINER
        // =====================================================
        stage('Stop Old Container') {

            steps {

                bat '''
                    echo ========================================
                    echo Stopping Old Container
                    echo ========================================

                    docker rm -f %CONTAINER_NAME% 2>nul

                    echo Old container removed if it existed.
                '''
            }
        }


        // =====================================================
        // 10. CREATE DOCKER VOLUME
        // =====================================================
        stage('Create Docker Volume') {

            steps {

                bat '''
                    echo ========================================
                    echo Checking Docker Volume
                    echo ========================================

                    docker volume inspect %VOLUME_NAME% >nul 2>&1

                    if %ERRORLEVEL% EQU 0 (

                        echo Docker volume "%VOLUME_NAME%" already exists.

                    ) else (

                        echo Creating Docker volume "%VOLUME_NAME%".

                        docker volume create %VOLUME_NAME%
                    )

                    echo.
                    echo ========================================
                    echo Docker Volumes
                    echo ========================================

                    docker volume ls
                '''
            }
        }


        // =====================================================
        // 11. RUN UPDATED CONTAINER
        // =====================================================
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
                    echo Container Started
                    echo ========================================

                    docker ps
                '''
            }
        }


        // =====================================================
        // 12. VERIFY CONTAINER
        // =====================================================
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
                    echo Checking Container
                    echo ========================================

                    docker inspect %CONTAINER_NAME% ^
                        --format="{{.State.Running}}"
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
            echo "Docker Image: ${ACR_LOGIN_SERVER}/had:${IMAGE_TAG}"
            echo "Container: ${CONTAINER_NAME}"
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
