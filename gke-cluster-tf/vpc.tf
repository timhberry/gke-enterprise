variable "project_id" {
  description = "project id"
}

variable "region" {
  description = "region"
}

provider "google" {
  credentials = file("serviceaccount.json")
  project     = var.project_id
  region      = var.region
}

resource "google_compute_network" "gke-vpc" {
  name                    = "gke-vpc"
  auto_create_subnetworks = "false"
}

resource "google_compute_subnetwork" "gke-subnet" {
  name          = "gke-subnet"
  region        = var.region
  network       = google_compute_network.gke-vpc.name
  ip_cidr_range = "10.10.0.0/24"
}
