pipeline {
    agent any


    stages {
        stage('Clone') {
            steps {
                // Get some code from a GitHub repository
                git credentialsId: 'github-token',
                    url: 'https://github.com/n-ablePrivateLimitedColomboSriLanka/DFCC_ACE_COLLATERELS.git',
                    branch: 'kasun_dev'
            }
        }
        stage('Build'){
            steps{
                sh '''
                docker images
                pwd
                ls
                 docker run --rm \
                  --volumes-from jenkins \
                  ibmint package \
                  --input-path /var/jenkins_home/workspace/app-connect \
                  --output-bar-file /var/jenkins_home/workspace/app-connect/MyIntegrationTestProject.bar \
                  --do-not-compile-java

                '''
            }
        }
    }
}

