resource "google_gke_hub_fleet" "dev-fleet" {
  display_name = "My Dev Fleet"
}

resource "google_container_cluster" "gcp-cluster" {
  name             = "gcp-cluster"
  location         = var.region
  enable_autopilot = true
  network          = google_compute_network.gke-vpc.name
  subnetwork       = google_compute_subnetwork.gke-subnet.name
}

resource "google_gke_hub_membership" "membership" {
  membership_id = "basic"
  location      = var.region
  endpoint {
    gke_cluster {
      resource_link = "//container.googleapis.com/${google_container_cluster.gcp-cluster.id}"
    }
  }
}

data "google_client_config" "provider" {}

data "google_container_cluster" "gcp-cluster" {
  name     = "gcp-cluster"
  location = var.region
}

provider "kubernetes" {
  host  = "https://${data.google_container_cluster.gcp-cluster.endpoint}"
  token = data.google_client_config.provider.access_token
  cluster_ca_certificate = base64decode(
    data.google_container_cluster.gcp-cluster.master_auth[0].cluster_ca_certificate,
  )
}
