packer {
  required_plugins {
    proxmox = {
      version = ">= 1.1.2"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}


source "proxmox-iso" "linux" {
  boot_command = ["c", "linux /casper/vmlinuz --- autoinstall ds='nocloud-net;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/' ", "<enter><wait>", "initrd /casper/initrd<enter><wait>", "boot<enter>"]
  boot_wait    = "5s"
  disks {
      disk_size         = "${var.vm_disk_size}"
      format            = "${var.vm_disk_format}"
      storage_pool      = "${var.proxmox_vm_storage}"
      type              = "scsi"
  }

  http_directory          = "http"
  cloud_init              = true
  cloud_init_storage_pool = "${var.proxmox_iso_storage}"
  communicator            = "ssh"
  cores                   = "${var.vm_cpu_cores}"
  
  insecure_skip_tls_verify = "${var.proxmox_skip_tls_verify}"
  iso_file                 = "${var.iso_file}"
  memory                   = "${var.vm_memory}"
  network_adapters {
    bridge = "vmbr0"
    model  = "virtio"
  }

  node                 = "${var.proxmox_node}"
  password             = "${var.proxmox_password}"
  pool                 = "${var.proxmox_pool}"
  proxmox_url          = "${var.proxmox_url}"
  sockets              = "${var.vm_sockets}"
  template_description = "${var.template_description}"
  template_name        = "${var.vm_name}"
  username             = "${var.proxmox_username}"
  vm_name              = "${var.vm_name}"
  ssh_password         = "${var.ssh_password}"
  ssh_timeout          = "20m" #new
  ssh_username         = "${var.ssh_username}"
  task_timeout         = "40m" # New
  unmount_iso          = true
}


build {
  sources = ["source.proxmox.linux"]

  provisioner "shell" {
    inline = ["while [ ! -f /var/lib/cloud/instance/boot-finished ]; do echo 'Waiting for cloud-init...'; sleep 1; done"]
  }

}
