pipeline {
    agent any

    stages {
        stage('Clone Repo') {
            steps {
                git credentialsId: 'github-token',
                    url: 'https://github.com/n-ablePrivateLimitedColomboSriLanka/DFCC_ACE_COLLATERELS.git',
                    branch: 'kasun_dev'
            }
        }


        stage('Build BAR') {
            steps {
                sh '''
                    docker images
                    pwd
                    ls -l
                    
                    docker run -v /var/lib/jenkins/jobs/app-connect/workspace:/workspace mqsicreatebar:latest -data /workspace -l ExceptionManagerRest   -l Logger  -b /workspace/dfcc.bar -skipWSErrorCheck
                    
                '''
            }
        }
    }
}
