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
        stage 'Promotion' {
            timeout(time: 1, unit: 'HOURS') {
                input 'Deploy to Production?'
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
            }
        }
    }
}
