terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.10"
    }
  }

  required_version = ">= 1.15.0"
}

data "google_project" "current" {}

data "google_client_config" "default" {}
