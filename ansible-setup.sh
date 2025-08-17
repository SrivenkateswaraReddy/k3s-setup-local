#!/bin/bash

# Create directory structure for the project
echo "Creating project directory structure..."

# Create main directories
mkdir -p {playbooks,inventory,roles,group_vars,host_vars}

# Create the main playbook
cat > playbooks/k3s-helm-setup.yml << 'EOF'
---
- name: Install K3s and Helm on Raspberry Pi
  hosts: raspberry_pi
  become: yes
  vars:
    k3s_version: "v1.28.5+k3s1"
    helm_version: "v3.13.3"
    force_reinstall: "{{ force_reinstall | default(false) }}"
    
  tasks:
    # Check if K3s is already installed
    - name: Check if K3s is installed
      command: k3s --version
      register: k3s_check
      failed_when: false
      changed_when: false
      
    - name: Display K3s status
      debug:
        msg: "K3s is {{ 'already installed' if k3s_check.rc == 0 else 'not installed' }}"
        
    # Check if Helm is already installed
    - name: Check if Helm is installed
      command: helm version --short
      register: helm_check
      failed_when: false
      changed_when: false
      
    - name: Display Helm status
      debug:
        msg: "Helm is {{ 'already installed' if helm_check.rc == 0 else 'not installed' }}"

    # Install K3s only if not present or force reinstall
    - name: Download K3s installation script
      get_url:
        url: https://get.k3s.io
        dest: /tmp/k3s-install.sh
        mode: '0755'
      when: k3s_check.rc != 0 or force_reinstall
      
    - name: Uninstall existing K3s if force reinstall
      shell: /usr/local/bin/k3s-uninstall.sh
      when: force_reinstall and k3s_check.rc == 0
      failed_when: false
      
    - name: Install K3s
      shell: |
        INSTALL_K3S_VERSION={{ k3s_version }} /tmp/k3s-install.sh
      environment:
        INSTALL_K3S_EXEC: "--disable=traefik"
      when: k3s_check.rc != 0 or force_reinstall
      register: k3s_install_result
      
    - name: Wait for K3s to be ready
      wait_for:
        port: 6443
        host: localhost
        delay: 10
        timeout: 300
      when: k3s_check.rc != 0 or force_reinstall
      
    # Set up kubeconfig for non-root user
    - name: Create .kube directory for pi user
      file:
        path: /home/pi/.kube
        state: directory
        owner: pi
        group: pi
        mode: '0755'
      when: k3s_check.rc != 0 or force_reinstall
      
    - name: Copy kubeconfig for pi user
      copy:
        src: /etc/rancher/k3s/k3s.yaml
        dest: /home/pi/.kube/config
        owner: pi
        group: pi
        mode: '0600'
        remote_src: yes
      when: k3s_check.rc != 0 or force_reinstall
      
    # Install Helm only if not present or force reinstall
    - name: Remove existing Helm if force reinstall
      file:
        path: /usr/local/bin/helm
        state: absent
      when: force_reinstall and helm_check.rc == 0
      
    - name: Download Helm installation script
      get_url:
        url: https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
        dest: /tmp/get-helm-3.sh
        mode: '0755'
      when: helm_check.rc != 0 or force_reinstall
      
    - name: Install Helm
      shell: |
        HELM_INSTALL_DIR=/usr/local/bin /tmp/get-helm-3.sh --version {{ helm_version }}
      when: helm_check.rc != 0 or force_reinstall
      
    # Verify installations
    - name: Verify K3s installation
      command: k3s kubectl get nodes
      register: k3s_nodes
      changed_when: false
      
    - name: Display K3s nodes
      debug:
        var: k3s_nodes.stdout_lines
        
    - name: Verify Helm installation
      command: helm version --short
      register: helm_version_output
      changed_when: false
      
    - name: Display Helm version
      debug:
        var: helm_version_output.stdout
        
    # Clean up temporary files
    - name: Clean up installation scripts
      file:
        path: "{{ item }}"
        state: absent
      loop:
        - /tmp/k3s-install.sh
        - /tmp/get-helm-3.sh
EOF

# Create initial inventory file (template)
cat > inventory/hosts.template << 'EOF'
[raspberry_pi]
# Replace with your actual Raspberry Pi IP address
raspberrypi ansible_host=YOUR_PI_IP_HERE ansible_user=pi ansible_ssh_private_key_file=~/.ssh/id_rsa

[raspberry_pi:vars]
ansible_python_interpreter=/usr/bin/python3
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
EOF

# Create Jenkinsfile
cat > Jenkinsfile << 'EOF'
pipeline {
    agent any
    
    environment {
        ANSIBLE_HOST_KEY_CHECKING = 'False'
        ANSIBLE_STDOUT_CALLBACK = 'yaml'
    }
    
    parameters {
        string(name: 'RASPBERRY_PI_IP', defaultValue: '192.168.1.100', description: 'IP address of Raspberry Pi')
        choice(name: 'ENVIRONMENT', choices: ['dev', 'staging', 'production'], description: 'Target environment')
        booleanParam(name: 'FORCE_REINSTALL', defaultValue: false, description: 'Force reinstall even if already present')
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
                echo "Checked out code from repository"
            }
        }
        
        stage('Prepare Environment') {
            steps {
                script {
                    writeFile file: 'inventory/hosts', text: """
[raspberry_pi]
raspberrypi ansible_host=${params.RASPBERRY_PI_IP} ansible_user=pi

[raspberry_pi:vars]
ansible_python_interpreter=/usr/bin/python3
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
"""
                }
                
                sh '''
                    if [ ! -f ~/.ssh/id_rsa ]; then
                        echo "SSH private key not found. Please configure SSH key for Pi access."
                        exit 1
                    fi
                    chmod 600 ~/.ssh/id_rsa
                '''
            }
        }
        
        stage('Test Connectivity') {
            steps {
                sh '''
                    echo "Testing Ansible connectivity to Raspberry Pi..."
                    ansible raspberry_pi -i inventory/hosts -m ping
                '''
            }
        }
        
        stage('Run Ansible Playbook') {
            steps {
                script {
                    def extraVars = ""
                    if (params.FORCE_REINSTALL) {
                        extraVars = "--extra-vars 'force_reinstall=true'"
                    }
                    
                    sh """
                        echo "Running K3s and Helm installation playbook..."
                        ansible-playbook -i inventory/hosts playbooks/k3s-helm-setup.yml -v ${extraVars}
                    """
                }
            }
        }
        
        stage('Verify Installation') {
            steps {
                sh '''
                    echo "Verifying K3s and Helm installations..."
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
        
        success {
            echo 'K3s and Helm setup completed successfully!'
        }
        
        failure {
            echo 'Pipeline failed! Check the logs for details.'
        }
        
        cleanup {
            cleanWs()
        }
    }
}
EOF

# Create ansible.cfg
cat > ansible.cfg << 'EOF'
[defaults]
inventory = inventory/hosts
host_key_checking = False
stdout_callback = yaml
callback_whitelist = profile_tasks, timer
retry_files_enabled = False
gathering = smart
fact_caching = memory
roles_path = roles
collections_paths = collections

[ssh_connection]
ssh_args = -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no
pipelining = True
control_path = /tmp/ansible-ssh-%%h-%%p-%%r
EOF

# Create README.md
cat > README.md << 'EOF'
# K3s and Helm Ansible Setup

This project automates the installation of K3s and Helm on Raspberry Pi using Ansible, orchestrated through Jenkins.

## Features

- Idempotent installation (checks if already installed)
- Force reinstall option
- Jenkins pipeline integration
- Parameterized deployments
- Installation verification
- Proper error handling and cleanup

## Prerequisites

1. Jenkins server with Ansible installed
2. SSH access to Raspberry Pi configured
3. SSH key pair set up for Pi access

## Usage

### Manual Execution

```bash
# Test connectivity
ansible raspberry_pi -i inventory/hosts -m ping

# Run playbook
ansible-playbook -i inventory/hosts playbooks/k3s-helm-setup.yml

# Force reinstall
ansible-playbook -i inventory/hosts playbooks/k3s-helm-setup.yml --extra-vars 'force_reinstall=true'
```

### Jenkins Pipeline

1. Create new Pipeline job in Jenkins
2. Point to this repository
3. Configure parameters as needed
4. Run the pipeline

## Configuration

Update `inventory/hosts` with your Raspberry Pi IP address and SSH configuration.
EOF

echo "Project structure created successfully!"
echo ""
echo "Next steps:"
echo "1. Update inventory/hosts with your Raspberry Pi IP address"
echo "2. Ensure SSH key is configured for Pi access"
echo "3. Create Jenkins pipeline job pointing to this repository"
echo "4. Run the pipeline!"
echo ""
echo "Directory structure:"
find . -type f -name "*.yml" -o -name "*.cfg" -o -name "Jenkinsfile" -o -name "*.md" | sort