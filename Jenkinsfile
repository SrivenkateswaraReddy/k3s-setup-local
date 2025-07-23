pipeline {
    agent any
    stages {
        stage('Checkout') {
            steps {
                git branch: 'main', url: 'https://github.com/SrivenkateswaraReddy/k3s-setup-local.git'
            }
        }
        stage('Install Tools') {
           steps {
            sh '''
                which helm || curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
            
                if ! which kubectl; then
                    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/arm64/kubectl"
                    chmod +x kubectl
                    mv kubectl /usr/local/bin/
                fi
            '''
    }

        }
        stage('Run Installer') {
            steps {
                sh 'chmod +x ingress-nginx-argo.sh'
                sh './ingress-nginx-argo.sh'
            }
        }
    }
}

