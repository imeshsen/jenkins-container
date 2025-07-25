pipeline {
    agent any

    stages {
        
        stage('Clone Repo') {
            steps {
                echo "Cloning repository..."
                git credentialsId: 'github-token',
                    url: 'https://github.com/n-ablePrivateLimitedColomboSriLanka/DFCC_ACE_COLLATERELS.git',
                    branch: 'CICD_TEST'
                echo "Repository cloned Branch is."
            }
        }

        stage('Build BAR') {
            steps {
                echo "Building BAR file using ibmint..."
                sh '''
                    docker images
                    pwd
                    ls -l
                    docker run --rm \\
                      --volumes-from jenkins \\
                      ibmint:latest package \\
                      --input-path /var/jenkins_home/workspace/app-connect \\
                      --output-bar-file /var/jenkins_home/workspace/app-connect/MyIntegrationTestProject.bar \\
                      --do-not-compile-java
                    echo "BAR file built: MyIntegrationTestProject.bar"
                    ls -l /var/jenkins_home/workspace/app-connect/MyIntegrationTestProject.bar
                '''
            }
        }

        stage('Start ACE Integration Server') {
            steps {
                script {
                    echo "Ensuring no old ACE server container or network is running..."

                    sh 'docker rm -f ace-server || true' // '|| true' prevents pipeline failure if container doesn't exist

                    sh 'docker network rm ace-network || true'

                    echo "Creating a custom Docker network for ACE and ibmint containers..."

                    sh 'docker network create ace-network'

                    echo "Starting IBM App Connect Enterprise integration server container on custom network..."
                    
                    sh 'docker run -d --name ace-server -p 7600:7600 --volumes-from jenkins -e LICENSE=accept --network ace-network ibmcom/ace:latest '
                    
                    echo "Waiting for ACE server to start up (30 seconds)..."
                    // IMPORTANT: This 'sleep' is a simple wait. For production, consider a more robust health check
                    // (e.g., polling the ACE REST API or checking container logs for "ready" messages).
                    sleep 30

                    echo "ACE server should be up and running now."

                    echo "Fetching ACE server logs for verification..."

                    sh 'docker logs ace-server' 
                }
            }
        }

        stage('Deploy BAR') {
            steps {
                echo "Deploying BAR file to ACE integration server..."
                
                sh '''
                    docker run --rm \\
                      --volumes-from jenkins \\
                      --network ace-network \\
                      ibmint:latest deploy \\
                      --input-bar-file /var/jenkins_home/workspace/app-connect/MyIntegrationTestProject.bar \\
                      --output-host ace-server \\
                      --output-port 7600
                    echo "BAR file deployment initiated successfully."
                '''
            }
        }

        // stage('Clean up ACE Server') {
        //     steps {
        //         script {
        //             echo "Stopping and removing ACE integration server container..."

        //             sh 'docker stop ace-server' // Stop the container gracefully

        //             sh 'docker rm ace-server'   // Remove the container

        //             echo "ACE server container cleaned up."
        //         }
        //     }
        // }
    }
    // Post-build actions, runs regardless of stage success/failure
    // post {
    //     always {
    //         script {
    //             echo "Performing post-build cleanup for ACE server (ensuring it's removed)..."

    //             // This ensures the container is removed even if a previous stage failed.
    //             sh 'docker rm -f ace-server || true'
    //         }
    //     }
    // }
}


