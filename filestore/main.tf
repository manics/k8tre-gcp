terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }

  required_version = ">= 1.15.0"
}

resource "google_filestore_instance" "instance" {
  name     = replace(var.name, "/[^a-z0-9-]/", "-")
  location = var.location
  tier     = var.tier

  file_shares {
    capacity_gb = 1024
    name        = "share1"
  }

  networks {
    network = var.network
    modes   = ["MODE_IPV4"]
  }

  kms_key_name = var.kms_key_name
}


