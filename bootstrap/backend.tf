# Initial setup of GCS bucket to store tfstate file

variable "project_id" {
  type        = string
  default     = "k8tre-dev-project"
  description = "GCP Project ID"
}

variable "region" {
  type        = string
  default     = "europe-west2"
  description = "GCP region"
}

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
  required_version = ">= 1.15.0"
}

# Configure the GCP Provider
provider "google" {
  project = var.project_id
  region  = var.region
}

resource "google_storage_bucket" "bucket" {
  name                     = "k8tre-tfstate-0123456789abcdef"
  location                 = var.region
  force_destroy            = false
  public_access_prevention = "enforced"

  versioning {
    enabled = true
  }

  labels = {
    owner = "trevolution"
  }
}

