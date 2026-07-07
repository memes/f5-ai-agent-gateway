terraform {
  required_version = ">= 1.5"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 7.16"
    }
  }
  backend "gcs" {
    bucket = "emes-stuff"
    prefix = "tofu/f5-ai-agent-gateway"
  }
}

provider "google" {
  default_labels = merge({
    demo_id = "f5-ai-agent-gateway"
    },
  var.labels == null ? {} : var.labels)
}

data "google_project" "project" {
  project_id = var.project_id
}

data "google_compute_zones" "zones" {
  project = var.project_id
  region  = var.region
}

data "google_compute_image" "cos" {
  project = "confidential-vm-images"
  family  = "cos-stable"
}
