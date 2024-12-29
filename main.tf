# main.tf
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
  }
  
  # Optional: Store state in GCS
  backend "gcs" {
    bucket = "your-terraform-state-bucket"
    prefix = "vm-deployments"
  }
}

# Enable required APIs
resource "google_project_service" "required_apis" {
  for_each = toset([
    "compute.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
    "serviceusage.googleapis.com",
    "cloudbuild.googleapis.com",
    "cloudapis.googleapis.com",
    "storage-api.googleapis.com",
    "storage-component.googleapis.com"
  ])
  
  project = var.project_id
  service = each.key
  disable_dependent_services = true
  disable_on_destroy = false
}

# Provider configuration
provider "google" {
  project = var.project_id
  region  = var.region
}

# Variables from email will be injected here
variable "project_id" {
    description = "Project ID to generate VM"
    type        = string
    default     = ""
}
variable "region" {
    description = "VM Region"
    type        = string
    default     = "asia-southeast2"
}
variable "zone" {
    description = "VM Zone"
    type        = string
    default     = "asia-southeast2-a"
}
variable "machine_type" {
    description = "VM Type (specification)"
    type        = string
}
variable "vm_name" {
    description = "VM Name"
    type        = string
}
variable "image_family" {}

# New variables for storage
variable "boot_disk_size" {
  description = "Size of the boot disk in GB"
  type        = number
  default     = 50
}

variable "additional_disks" {
  description = "Additional disks to attach to the instance"
  type = list(object({
    name = string
    size = number
    type = string  # pd-standard, pd-balanced, or pd-ssd
  }))
  default = []
}

# VM Instance with enhanced storage configuration
resource "google_compute_instance" "vm_instance" {
  name         = var.vm_name
  machine_type = var.machine_type
  zone         = var.zone

  # Depends on API enablement
  depends_on = [google_project_service.required_apis]

  boot_disk {
    initialize_params {
      image = var.image_family
      size  = var.boot_disk_size
      type  = "pd-balanced"  # You can change this to pd-standard or pd-balanced
    }
  }

  # Dynamic block for additional disks
  dynamic "attached_disk" {
    for_each = var.additional_disks
    content {
      source = google_compute_disk.additional_disks[attached_disk.key].self_link
      device_name = google_compute_disk.additional_disks[attached_disk.key].name
    }
  }

  network_interface {
    network = "default"
    access_config {
      // Ephemeral IP
    }
  }

  metadata = {
    created_by = "terraform-email-automation"
  }

  labels = {
    environment = "automated"
    managed_by = "terraform"
  }

  service_account {
    scopes = ["cloud-platform"]
  }
}

# Create additional disks
resource "google_compute_disk" "additional_disks" {
  count = length(var.additional_disks)
  name  = var.additional_disks[count.index].name
  type  = var.additional_disks[count.index].type
  zone  = var.zone
  size  = var.additional_disks[count.index].size

  labels = {
    environment = "automated"
    managed_by = "terraform"
  }
}

# Outputs
output "instance_ip" {
  value = google_compute_instance.vm_instance.network_interface[0].access_config[0].nat_ip
}

output "instance_self_link" {
  value = google_compute_instance.vm_instance.self_link
}

output "boot_disk_size" {
  value = var.boot_disk_size
}

output "additional_disks" {
  value = google_compute_disk.additional_disks[*].name
}