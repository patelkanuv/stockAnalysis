pipeline {
    agent any

    stages {
        stage('Initialize') {
            steps {
                echo 'Initializing..'
            }
        }
        stage('Build') {
            steps {
                echo 'Building..'
            }
        }
        stage('Promotion') {
            steps {
                timeout(time: 1, unit: 'MINUTES') {
                    input 'Deploy to Production?'
                }
            }
        }
        stage('content-release') {
            steps {
                echo 'Deploying contents....'
            }
        }
        stage('Deploy') {
            steps {
                echo 'Deploying code ....'
                sh """
                    date
                    ls -la
                """
            }
        }
    }
}
