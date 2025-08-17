# K3s and Helm Ansible Setup

Automates installation of K3s and Helm on Raspberry Pi via Ansible, orchestrated through Jenkins.

## Prerequisites

1. Jenkins server with Ansible installed
2. SSH access to Raspberry Pi configured
3. SSH key uploaded as Jenkins Secret File (ID: ansible_ssh)

## Usage

- Jenkins Pipeline reads SSH key from secret file.
- Inventory is dynamically updated.
- Force reinstall option available via parameter.

