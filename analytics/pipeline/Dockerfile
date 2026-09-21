FROM node:20-slim

# Debian bookworm's default apt repo only ships postgresql-client 15, but
# both the production and analytics Postgres servers this image talks to
# are version 16 (see server/docker-compose.yml and this package's own
# terraform/main.tf, both pinned to postgres:16) — pg_dump refuses to run
# against a newer server than itself ("aborting because of server version
# mismatch"). This was a real, confirmed bug found during Task 8's
# clean-slate verification: clone.ts's own error handling only checked
# psql's exit code, so a pg_dump version-mismatch failure went completely
# silent (psql just received no input and exited 0 having restored
# nothing) — see clone.ts's file-map entry for the accompanying fix.
# Install postgresql-client-16 explicitly from the PGDG apt repo instead
# of the distro default, so pg_dump/psql actually match the servers.
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl gnupg lsb-release \
    && install -d /usr/share/postgresql-common/pgdg \
    && curl -o /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc \
      --fail https://www.postgresql.org/media/keys/ACCC4CF8.asc \
    && echo "deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.asc] https://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" \
      > /etc/apt/sources.list.d/pgdg.list \
    && apt-get update && apt-get install -y --no-install-recommends postgresql-client-16 \
    && apt-get purge -y curl gnupg lsb-release \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build

CMD ["node", "dist/pipeline/src/index.js"]
