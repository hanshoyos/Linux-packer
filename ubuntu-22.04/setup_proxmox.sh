#!/bin/bash

set -e

# Function to display error message and exit
error_exit() {
  echo "$1" 1>&2
  exit 1
}

# Function to update and upgrade the system
update_system() {
  echo "Updating and upgrading the system..."
  sudo apt update && sudo apt upgrade -y || error_exit "System update and upgrade failed."
  sudo apt install -y git gpg vim tmux curl gnupg software-properties-common mkisofs python3-venv || error_exit "Failed to install required packages."
}

# Function to create and activate Python virtual environment
create_venv() {
  echo "Creating and activating Python virtual environment..."
  python3 -m venv /root/ProxmoxAutoADEnv/venv || error_exit "Failed to create Python virtual environment."
  echo "source /root/ProxmoxAutoADEnv/venv/bin/activate" >> ~/.bashrc
  source /root/ProxmoxAutoADEnv/venv/bin/activate || error_exit "Failed to activate Python virtual environment."
}

# Function to install Ansible
install_ansible() {
  echo "Installing Ansible..."
  UBUNTU_CODENAME=jammy
  wget -O- "https://keyserver.ubuntu.com/pks/lookup?fingerprint=on&op=get&search=0x6125E2A8C77F2818FB7BD15B93C4A3FD7BB9C367" | sudo gpg --dearmor --yes -o /usr/share/keyrings/ansible-archive-keyring.gpg
  echo "deb [signed-by=/usr/share/keyrings/ansible-archive-keyring.gpg] http://ppa.launchpad.net/ansible/ansible/ubuntu $UBUNTU_CODENAME main" | sudo tee /etc/apt/sources.list.d/ansible.list
  sudo apt update && sudo apt install -y ansible || error_exit "Failed to install Ansible."
}

# Function to install Packer and Terraform
install_packer_terraform() {
  echo "Installing Packer and Terraform..."
  wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor --yes | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null
  echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
  sudo apt update && sudo apt install -y packer terraform || error_exit "Failed to install Packer and Terraform."
}

# Function to download Cloudbase-Init MSI
download_cloudbase_init() {
  echo "Downloading Cloudbase-Init MSI..."
  cd /root/ProxmoxAutoADEnv/packer/proxmox/scripts/sysprep/
  wget https://cloudbase.it/downloads/CloudbaseInitSetup_Stable_x64.msi || error_exit "Failed to download Cloudbase-Init MSI."
}

# Function to download all ISO files on Proxmox server
download_all_iso_files_proxmox() {
  echo "Downloading all ISO files on Proxmox server..."
  ssh root@192.168.10.20 << 'EOF'
cd /var/lib/vz/template/iso/ || exit 1
nohup wget -O virtio-win.iso https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso &
nohup wget -O windows10.iso https://software-static.download.prss.microsoft.com/dbazure/988969d5-f34g-4e03-ac9d-1f9786c66750/19045.2006.220908-0225.22h2_release_svc_refresh_CLIENTENTERPRISEEVAL_OEMRET_x64FRE_en-us.iso &
nohup wget -O windows_server_2019.iso https://software-static.download.prss.microsoft.com/dbazure/988969d5-f34g-4e03-ac9d-1f9786c66749/17763.3650.221105-1748.rs5_release_svc_refresh_SERVER_EVAL_x64FRE_en-us.iso &
nohup wget -O ubuntu-22.iso https://releases.ubuntu.com/jammy/ubuntu-22.04.4-live-server-amd64.iso &
EOF
  # Wait for downloads to complete
  echo "Waiting for ISO downloads to complete..."
  sleep 60
}

# Function to download a specific ISO file on Proxmox server
download_specific_iso_file_proxmox() {
  local iso_url=$1
  local iso_name=$2
  echo "Downloading ${iso_name} on Proxmox server..."
  ssh root@192.168.10.20 << EOF
cd /var/lib/vz/template/iso/ || exit 1
nohup wget -O ${iso_name} ${iso_url} &
EOF
  # Wait for downloads to complete
  echo "Waiting for ${iso_name} download to complete..."
  sleep 60
}

# Function to run build_proxmox_iso.sh script
build_proxmox_iso() {
  echo "Running build_proxmox_iso.sh script..."
  cd /root/ProxmoxAutoADEnv/packer/proxmox || error_exit "Failed to navigate to the build_proxmox_iso.sh directory."
  ./build_proxmox_iso.sh || error_exit "Failed to build Proxmox ISO."
}

# Function to SCP files to Proxmox server
scp_files_to_proxmox() {
  echo "Copying ISO files to Proxmox server..."
  scp /root/ProxmoxAutoADEnv/packer/proxmox/iso/* root@192.168.10.20:/var/lib/vz/template/iso/ || error_exit "Failed to copy ISO files to Proxmox server."
}

# Function to setup Proxmox user and roles
setup_proxmox_user() {
  echo "Setting up Proxmox user and roles..."
  ssh root@192.168.10.20 << 'EOF'
pveum useradd infra_as_code@pve
pveum passwd infra_as_code@pve
pveum roleadd Packer -privs "VM.Config.Disk VM.Config.CPU VM.Config.Memory Datastore.AllocateTemplate Datastore.Audit Datastore.AllocateSpace Sys.Modify VM.Config.Options VM.Allocate VM.Audit VM.Console VM.Config.CDROM VM.Config.Cloudinit VM.Config.Network VM.PowerMgmt VM.Config.HWType VM.Monitor SDN.Use"
pveum acl modify / -user 'infra_as_code@pve' -role Packer
EOF
}

# Submenu for downloading specific ISO files
download_iso_files_proxmox_menu() {
  echo "Choose an ISO to download on Proxmox server:"
  echo "1) Download all ISO files"
  echo "2) Download Virtio ISO"
  echo "3) Download Windows 10 ISO"
  echo "4) Download Windows Server 2019 ISO"
  echo "5) Back to main menu"
  read -p "Enter choice [1-5]: " sub_choice
  case $sub_choice in
    1) download_all_iso_files_proxmox ;;
    2) download_specific_iso_file_proxmox "https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso" "virtio-win.iso" ;;
    3) download_specific_iso_file_proxmox "https://software-static.download.prss.microsoft.com/dbazure/988969d5-f34g-4e03-ac9d-1f9786c66750/19045.2006.220908-0225.22h2_release_svc_refresh_CLIENTENTERPRISEEVAL_OEMRET_x64FRE_en-us.iso" "windows10.iso" ;;
    4) download_specific_iso_file_proxmox "https://software-static.download.prss.microsoft.com/dbazure/988969d5-f34g-4e03-ac9d-1f9786c66749/17763.3650.221105-1748.rs5_release_svc_refresh_SERVER_EVAL_x64FRE_en-us.iso" "windows_server_2019.iso" ;;
    5) download_specific_iso_file_proxmox "https://releases.ubuntu.com/jammy/ubuntu-22.04.4-live-server-amd64.iso" "ubuntu-22.iso" ;;
    6) show_menu ;;
    *) echo "Invalid choice!"; download_iso_files_proxmox_menu ;;
  esac
}

# Display main menu
show_menu() {
  echo "Choose an option:"
  echo "1) Update and upgrade the system"
  echo "2) Create and activate Python virtual environment"
  echo "3) Install Ansible"
  echo "4) Install Packer and Terraform"
  echo "5) Download Cloudbase-Init MSI"
  echo "6) Download ISO files on Proxmox server"
  echo "7) Build Proxmox ISO"
  echo "8) SCP files to Proxmox server"
  echo "9) Setup Proxmox user and roles"
  echo "10) Exit"
  read -p "Enter choice [1-10]: " choice
  case $choice in
    1) update_system ;;
    2) create_venv ;;
    3) install_ansible ;;
    4) install_packer_terraform ;;
    5) download_cloudbase_init ;;
    6) download_iso_files_proxmox_menu ;;
    7) build_proxmox_iso ;;
    8) scp_files_to_proxmox ;;
    9) setup_proxmox_user ;;
    10) exit 0 ;;
    *) echo "Invalid choice!"; show_menu ;;
  esac
}

# Show the main menu until the user exits
while true; do
  show_menu
done
