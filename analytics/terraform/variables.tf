variable "production_database_url" {
  description = "Connection string for the production Stub Postgres (server/'s postgres service, reachable by its Compose service name on the shared network)"
  type        = string
  default     = "postgres://postgres:postgres@postgres:5432/stub"
}
