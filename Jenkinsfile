pipeline {
    agent any
    parameters {
        string(name: 'ANSIBLE_HOST', defaultValue: '192.168.1.190', description: 'Raspberry Pi IP')
        string(name: 'ANSIBLE_USER', defaultValue: 'pi', description: 'SSH User')
    }
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
                # Install Helm if missing
                which helm || curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

                # Install kubectl if missing
                which kubectl || (
                    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/arm64/kubectl" &&
                    chmod +x kubectl &&
                    sudo mv kubectl /usr/local/bin/
                )

                # Install Ansible if missing
                which ansible || (sudo apt-get update && sudo apt-get install -y ansible)
                '''
            }
        }

        stage('Install K3s and Helm with Ansible') {
            steps {
                sh """
                ansible-playbook -i "${ANSIBLE_HOST}," \
                    -u "${ANSIBLE_USER}" \
                    --ssh-extra-args='-o StrictHostKeyChecking=no' \
                    playbook.yml --become
                """
            }
        }
    }
}
