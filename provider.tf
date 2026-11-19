terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.10"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.5"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "3.3"
    }

    http = {
      source  = "hashicorp/http"
      version = "~> 3.6"
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
  region  = var.region
  project = var.google_project
  zone    = var.zone
  default_labels = {
    owner = "tetres"
  }
}

data "google_project" "project" {}

data "google_client_config" "default" {}

provider "kubernetes" {
  alias                  = "k8tre-dev"
  host                   = "https://${module.k8tre-gke.cluster_endpoint}"
  cluster_ca_certificate = base64decode(module.k8tre-gke.cluster_ca_certificate)
  token                  = data.google_client_config.default.access_token
}

provider "helm" {
  alias = "k8tre-dev"
  kubernetes = {
    host                   = "https://${module.k8tre-gke.cluster_endpoint}"
    cluster_ca_certificate = base64decode(module.k8tre-gke.cluster_ca_certificate)
    token                  = data.google_client_config.default.access_token
  }
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
