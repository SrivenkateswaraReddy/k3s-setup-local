pipeline {
    agent any
    environment {
        KUBECONFIG = '/var/lib/jenkins/.kube/config'
    }
    stages {
        stage('Checkout') {
            steps {
                git branch: 'feature/ansible_setup', url: 'https://github.com/SrivenkateswaraReddy/k3s-setup-local.git'
            }
        }

        stage('Install Tools') {
            steps {
                sh '''
                which helm || curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
                which kubectl || (
                    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/arm64/kubectl" &&
                    chmod +x kubectl &&
                    sudo mv kubectl /usr/local/bin/
                )
                which ansible || sudo apt-get update && sudo apt-get install -y ansible
                '''
            }
        }

        stage('Install K3s and Helm with Ansible') {
            steps {
                sh '''
                ansible-playbook -i inventory.ini install-k3s-helm.yaml
                '''
            }
        }

        stage('Run Installer Script') {
            steps {
                sh '''
                chmod +x ingress-nginx-argo.sh
                ./ingress-nginx-argo.sh
                '''
            }
        }
    }
}
