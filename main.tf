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

provider "google" {
  project = var.project_id
  region  = var.region
}

# Variables from email will be injected here
variable "project_id" {}
variable "region" {}
variable "zone" {}
variable "machine_type" {}
variable "vm_name" {}
variable "image_family" {}

# VM Resource
resource "google_compute_instance" "vm_instance" {
  name         = var.vm_name
  machine_type = var.machine_type
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = var.image_family
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
  }
}

output "instance_ip" {
  value = google_compute_instance.vm_instance.network_interface[0].access_config[0].nat_ip
}