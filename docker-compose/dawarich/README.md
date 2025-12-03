# Dawarich - Location Tracking Service

Dawarich is a self-hosted location tracking service that uses shared Redis and PostgreSQL infrastructure.

## Architecture

This setup uses:
- **Shared Redis**: `shared_redis` container from the `db` stack (database 1)
- **Shared PostgreSQL**: `postgre_db` container from the `db` stack with PostGIS extension
- **Separate database**: `dawarich` database within the shared PostgreSQL instance

## Prerequisites

1. **Database stack must be running** with the custom PostgreSQL image that includes PostGIS
2. **External network** `dawarich` must be created
3. **Environment variables** must be configured

## Setup Instructions

### 1. Create External Network

```bash
docker network create dawarich
```

Also ensure the `db` stack containers can access this network. You may need to connect them:

```bash
docker network connect dawarich shared_redis
docker network connect dawarich postgre_db
```

### 2. Configure Environment Variables

```bash
cd docker-compose/dawarich
cp .env.example .env
nano .env  # Edit with your values
```

**Important**: Generate a secure `SECRET_KEY_BASE`:
```bash
openssl rand -hex 64
```

### 3. Deploy with Portainer

1. Go to Portainer → Stacks
2. Add new stack named "dawarich"
3. Upload or paste the `docker-compose.yaml` content
4. Add environment variables from `.env` file
5. Deploy

### 4. First Run

The `setup_db` container will automatically:
- Wait for PostgreSQL to be ready
- Create the `dawarich` database if it doesn't exist
- Enable PostGIS and PostGIS Topology extensions
- Exit after setup

Then the main app will run database migrations automatically on first start.

## Service Details

### dawarich_app
- **Port**: 3000 (configurable via `DAWARICH_APP_PORT`)
- **Purpose**: Main web application
- **Health Check**: HTTP endpoint at `/api/v1/health`

### dawarich_sidekiq
- **Purpose**: Background job processor
- **Depends on**: dawarich_app must be healthy

### setup_db
- **Purpose**: One-time database initialization
- **Runs once**: Creates database and enables extensions

## Connecting to Other Services

### Redis Connection
```
redis://shared_redis:6379/1
```
Using database `1` to avoid conflicts with other services (Immich uses default database `0`)

### PostgreSQL Connection
```
Host: postgre_db
Port: 5432
Database: dawarich
User: ${POSTGRES_USER}
Password: ${POSTGRES_PASSWORD}
```

## Troubleshooting

### App won't start
1. Check if db stack is running: `docker ps | grep postgre`
2. Check if networks exist: `docker network ls | grep dawarich`
3. Check logs: `docker logs dawarich_app`
4. Verify PostgreSQL has PostGIS: `docker exec postgre_db psql -U postgres -d dawarich -c "SELECT PostGIS_version();"`

### Database connection errors
1. Ensure containers are on the same network
2. Check PostgreSQL is accepting connections: `docker exec postgre_db pg_isready`
3. Verify credentials match between stacks

### Redis connection errors
1. Check Redis is running: `docker exec shared_redis redis-cli ping`
2. Verify network connectivity: `docker exec dawarich_app ping shared_redis`

## Updating

```bash
docker-compose pull
docker-compose up -d
```

Dawarich will automatically run migrations on startup.

## Backup

### Database
```bash
docker exec postgre_db pg_dump -U postgres dawarich > dawarich_backup.sql
```

### Restore
```bash
cat dawarich_backup.sql | docker exec -i postgre_db psql -U postgres dawarich
```

### Volumes
- `dawarich_public` - Public assets
- `dawarich_watched` - Watched imports directory
- `dawarich_storage` - Application storage

## Resource Usage

Default limits:
- CPU: 0.5 core (50%)
- Memory: 4GB

Adjust in `.env`:
```
APP_CPU_LIMIT=1.0
APP_MEMORY_LIMIT=8G
```

## Accessing the Application

Once deployed, access at:
- Development: `http://localhost:3000`
- Production: Configure reverse proxy to point to port 3000

Make sure to add your domain to `APPLICATION_HOSTS` environment variable.
