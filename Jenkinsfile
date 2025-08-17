pipeline {
    agent any
    
    environment {
        ANSIBLE_HOST_KEY_CHECKING = 'False'
        ANSIBLE_STDOUT_CALLBACK = 'yaml'
    }
    
    parameters {
        string(name: 'RASPBERRY_PI_IP', defaultValue: '192.168.1.100', description: 'IP address of Raspberry Pi')
        booleanParam(name: 'FORCE_REINSTALL', defaultValue: false, description: 'Force reinstall even if already present')
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
                echo "Checked out code from repository"
            }
        }
        
        stage('Prepare Inventory') {
            steps {
                withCredentials([file(credentialsId: 'ansible_ssh', variable: 'SSH_KEY')]) {
                    script {
                        writeFile file: 'inventory/hosts', text: """
[raspberry_pi]
raspberrypi ansible_host=${params.RASPBERRY_PI_IP} ansible_user=pi ansible_ssh_private_key_file=\$SSH_KEY

[raspberry_pi:vars]
ansible_python_interpreter=/usr/bin/python3
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
"""
                    }
                    sh 'chmod 600 $SSH_KEY'
                }
            }
        }
        
        stage('Test Connectivity') {
            steps {
                sh 'ansible raspberry_pi -i inventory/hosts -m ping'
            }
        }
        
        stage('Run Ansible Playbook') {
            steps {
                withCredentials([file(credentialsId: 'ansible_ssh', variable: 'SSH_KEY')]) {
                    script {
                        def extraVars = params.FORCE_REINSTALL ? "--extra-vars 'force_reinstall=true'" : ""
                        sh "ansible-playbook -i inventory/hosts playbooks/k3s-helm-setup.yml -v ${extraVars}"
                    }
                }
            }
        }
        
        stage('Verify Installation') {
            steps {
                sh '''
                    ansible raspberry_pi -i inventory/hosts -m shell -a "k3s kubectl get nodes"
                    ansible raspberry_pi -i inventory/hosts -m shell -a "helm version --short"
                '''
            }
        }
    }
    
    post {
        always {
            echo 'Pipeline completed!'
            sh 'rm -f inventory/hosts'
        }
    }
}
