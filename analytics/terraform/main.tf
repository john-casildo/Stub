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

# The "data lake" raw zone from the instructor's reference diagram —
# an S3-compatible object store holding the 10 raw department files
# before the ETL reads them. generate.ts uploads to it; etl.ts downloads
# from it before parsing, both via the AWS S3 SDK against MinIO's
# S3-compatible API.
resource "docker_volume" "minio_data" {
  name = "minio_data"
}

resource "docker_image" "minio" {
  # MinIO discontinued the Docker Hub "minio/minio" repo (licensing
  # change); the current official distribution point is quay.io.
  name = "quay.io/minio/minio:latest"
}

resource "docker_container" "minio" {
  name    = "analytics-datalake"
  image   = docker_image.minio.image_id
  command = ["server", "/data", "--console-address", ":9001"]

  env = [
    "MINIO_ROOT_USER=minioadmin",
    "MINIO_ROOT_PASSWORD=minioadmin123",
  ]

  ports {
    internal = 9000
    external = 9000
  }

  ports {
    internal = 9001
    external = 9001
  }

  networks_advanced {
    name = data.docker_network.server_default.name
  }

  volumes {
    volume_name    = docker_volume.minio_data.name
    container_path = "/data"
  }

  restart = "unless-stopped"
}

resource "docker_image" "pipeline" {
  name = "stub-analytics-pipeline:latest"
  build {
    context    = "${path.module}/.."
    dockerfile = "pipeline/Dockerfile"
  }
  triggers = {
    dockerfile_sha = filesha256("${path.module}/../pipeline/Dockerfile")
    source_sha     = sha256(join("", [for f in fileset("${path.module}/../pipeline/src", "**") : filesha256("${path.module}/../pipeline/src/${f}")]))
    package_sha    = filesha256("${path.module}/../package.json")
  }
}

resource "docker_container" "pipeline" {
  name  = "analytics-pipeline"
  image = docker_image.pipeline.image_id

  env = [
    "DATABASE_URL=${var.production_database_url}",
    "ANALYTICS_DATABASE_URL=postgres://postgres:postgres@analytics-db:5432/analytics",
    "DATALAKE_ENDPOINT=http://analytics-datalake:9000",
  ]

  networks_advanced {
    name = data.docker_network.server_default.name
  }

  # No department-files/output bind mount here anymore — since the ETL
  # now fetches every file from the data lake (MinIO) at the start of
  # each run, the host's local copy is no longer the pipeline's source
  # of truth (it's just generate.ts's own convenience output for
  # inspection before upload).

  restart = "unless-stopped"

  depends_on = [docker_container.analytics_db, docker_container.minio]
}

# BI dashboard layer, matching the instructor's reference diagram
# (PowerBI/Tableau/Metabase feeding Business Analysts) — out of scope for
# the original assignment deliverable, added on request afterward.
# Metabase keeps its own small app database (embedded, in this volume) to
# store dashboards/questions/users; the actual data it visualizes comes
# from connecting it to analytics-db through its own web setup wizard on
# first launch, not through Terraform.
resource "docker_volume" "metabase_data" {
  name = "metabase_data"
}

resource "docker_image" "metabase" {
  name = "metabase/metabase:latest"
}

resource "docker_container" "metabase" {
  name  = "analytics-metabase"
  image = docker_image.metabase.image_id

  ports {
    internal = 3000
    external = 3002
  }

  networks_advanced {
    name = data.docker_network.server_default.name
  }

  volumes {
    volume_name    = docker_volume.metabase_data.name
    container_path = "/metabase-data"
  }

  env = [
    "MB_DB_FILE=/metabase-data/metabase.db",
  ]

  restart = "unless-stopped"

  depends_on = [docker_container.analytics_db]
}
