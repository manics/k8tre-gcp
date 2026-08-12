terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.38"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "3.0.2"
    }

    http = {
      source  = "hashicorp/http"
      version = "~> 3.5"
    }
  }

  required_version = ">= 1.15.0"

  # Bootstrapping: Create the bucket using the ./bootstrap directory
  # Must match google_storage_bucket.bucket in bootstrap/backend.tf
  backend "gcs" {
    bucket = "k8tre-tfstate-0123456789abcdef"
    prefix = "tfstate/dev/k8tre-dev"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

data "google_client_config" "default" {}

provider "kubernetes" {
  alias                  = "k8tre-dev"
  host                   = "https://${module.k8tre-gke.cluster_endpoint}"
  cluster_ca_certificate = base64decode(module.k8tre-gke.cluster_ca_certificate)
  token                  = data.google_client_config.default.access_token
}

provider "kubernetes" {
  alias                  = "k8tre-dev-argocd"
  host                   = "https://${module.k8tre-argocd-gke.cluster_endpoint}"
  cluster_ca_certificate = base64decode(module.k8tre-argocd-gke.cluster_ca_certificate)
  token                  = data.google_client_config.default.access_token
}

provider "helm" {
  alias = "k8tre-dev-argocd"
  kubernetes = {
    host                   = "https://${module.k8tre-argocd-gke.cluster_endpoint}"
    cluster_ca_certificate = base64decode(module.k8tre-argocd-gke.cluster_ca_certificate)
    token                  = data.google_client_config.default.access_token
  }
}

