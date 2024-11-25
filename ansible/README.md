# Proxmox Provisioning

This directory uses **Ansible** playbooks to setup Ubuntu and Debian containers/VMs in **Proxmox** as Github Runners. It has been heavily inspired by [`ansible-github_actions_runner`](https://github.com/MonolithProjects/ansible-github_actions_runner).

## Usage

You'll need to have ansible installed on your control machine but once you do you can simply type:

```sh
ansible-playbook main.yml 
```
