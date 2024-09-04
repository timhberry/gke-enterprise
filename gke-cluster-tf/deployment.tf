resource "kubernetes_deployment" "hello-world" {
  metadata {
    name = "hello-world"
    labels = {
      app = "hello-world"
    }
  }
  spec {
    selector {
      match_labels = {
        app = "hello-world"
      }
    }
    template {
      metadata {
        labels = {
          app = "hello-world"
        }
      }
      spec {
        container {
          image = "us-docker.pkg.dev/google-samples/containers/gke/hello-app:1.0"
          name  = "hello-world"
        }
      }
    }
  }
}

resource "kubernetes_service" "hello-world" {
  metadata {
    name = "hello-world"
  }
  spec {
    selector = {
      app = kubernetes_deployment.hello-world.spec.0.template.0.metadata.0.labels.app
    }
    port {
      port        = 80
      target_port = 8080
    }
    type = "LoadBalancer"
  }
}
