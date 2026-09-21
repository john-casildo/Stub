terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "docker" {}

# Owned by server/docker-compose.yml (Compose's default project-scoped
# network name for that project, "server") — looked up, never created or
# destroyed here.
data "docker_network" "server_default" {
  name = "server_default"
}

resource "docker_volume" "analytics_postgres_data" {
  name = "analytics_postgres_data"
}

resource "docker_image" "analytics_postgres" {
  name = "postgres:16"
}

resource "docker_container" "analytics_db" {
  name  = "analytics-db"
  image = docker_image.analytics_postgres.image_id

  env = [
    "POSTGRES_USER=postgres",
    "POSTGRES_PASSWORD=postgres",
    "POSTGRES_DB=analytics",
  ]

  ports {
    internal = 5432
    external = 5433
  }

  networks_advanced {
    name = data.docker_network.server_default.name
  }

  volumes {
    volume_name    = docker_volume.analytics_postgres_data.name
    container_path = "/var/lib/postgresql/data"
  }

  restart = "unless-stopped"
}

resource "docker_image" "pipeline" {
  name = "stub-analytics-pipeline:latest"
  build {
    context    = "${path.module}/.."
    dockerfile = "pipeline/Dockerfile"
  }
}

resource "docker_container" "pipeline" {
  name  = "analytics-pipeline"
  image = docker_image.pipeline.image_id

  env = [
    "DATABASE_URL=${var.production_database_url}",
    "ANALYTICS_DATABASE_URL=postgres://postgres:postgres@analytics-db:5432/analytics",
  ]

  networks_advanced {
    name = data.docker_network.server_default.name
  }

  volumes {
    host_path      = abspath("${path.module}/../department-files/output")
    container_path = "/app/department-files/output"
    read_only      = true
  }

  restart = "unless-stopped"

  depends_on = [docker_container.analytics_db]
}
