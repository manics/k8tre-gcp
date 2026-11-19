# Initial setup of GCS bucket to store tfstate file

variable "region" {
  type        = string
  default     = "europe-west2"
  description = "GCP region"
}

variable "google_project" {
  type        = string
  description = "GCP project"
}

variable "bucket_name" {
  type = string
  # Generate a random bucket name, e.g. `openssl rand -hex 8`
  default     = "k8tre-tfstate-0123456789abcdef"
  description = "Bucket name for storing Terraform state"
}

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.10"
    }
  }
  required_version = ">= 1.15.0"
}

# Configure the GCP Provider
provider "google" {
  region  = var.region
  project = var.google_project
  default_labels = {
    owner = "tetres"
  }
}

resource "google_storage_bucket" "bucket" {
  name                        = var.bucket_name
  location                    = var.region
  force_destroy               = false
  public_access_prevention    = "enforced"
  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }
}
