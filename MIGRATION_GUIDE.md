# Migration Guide: Shared Database Infrastructure

This guide walks you through migrating to the new shared Redis and PostgreSQL infrastructure.

## Overview of Changes

### Before
- Immich had its own Redis container (`immich_redis`)
- PostgreSQL without PostGIS (`pgvector/pgvector:pg17`)
- No shared infrastructure

### After
- **Shared Redis** (`shared_redis`) for all services
- **Custom PostgreSQL** with PostGIS, pgvector, and other extensions
- Multiple databases in one PostgreSQL instance
- Better resource utilization

## Migration Steps

### Phase 1: Backup Everything

**IMPORTANT**: Always backup before making changes!

```bash
# 1. Backup PostgreSQL data
docker exec postgre_db pg_dumpall -U postgres > postgres_backup_$(date +%Y%m%d).sql

# 2. Backup Redis data (if needed)
docker exec immich_redis redis-cli SAVE
docker cp immich_redis:/data/dump.rdb redis_backup_$(date +%Y%m%d).rdb

# 3. Note down all environment variables
cd docker-compose/db
cat .env > .env.backup
cd ../photos
cat .env > .env.backup
```

### Phase 2: Build Custom PostgreSQL Image

**Option A: Using Docker CLI (Recommended)**

```bash
cd docker-compose/db

# Build the custom PostgreSQL image
docker-compose build postgre

# Verify the image was created
docker images | grep archivum-postgre
```

**Option B: Build from Git Repository**

If your repository is accessible via git, you can build directly from the repo:

```bash
# Build from git context
docker build -t archivum-postgre:latest \
  https://github.com/yourusername/archivum-infra.git#main:docker-compose/db/postgresql

# Or if using a private repo with SSH
docker build -t archivum-postgre:latest \
  git@github.com:yourusername/archivum-infra.git#main:docker-compose/db/postgresql
```

**Option C: Using Portainer with Git**

1. Go to **Portainer** → **Images** → **Build a new image**
2. Set **Name**: `archivum-postgre:latest`
3. **Build method**: Choose **Git Repository**
4. **Repository URL**: Your git repository URL
5. **Repository reference**: `refs/heads/main` (or your branch)
6. **Docker file path**: `docker-compose/db/postgresql/Dockerfile`
7. Click **Build the image**

> **Note**: Portainer can automatically rebuild images from git on webhook triggers for CI/CD workflows

### Phase 3: Deploy Database Stack via Portainer

1. **Create external network (if not exists)**
   ```bash
   docker network create dawarich
   ```

2. **Stop the current db stack** (if running via CLI)
   ```bash
   cd docker-compose/db
   docker-compose down
   # DO NOT use -v flag! We want to keep the volumes
   ```

   Or via **Portainer**: Go to **Stacks** → Select your db stack → **Stop** (don't delete!)

3. **Deploy/Update the Database Stack in Portainer**

   a. Go to **Portainer** → **Stacks** → **Add stack**

   b. **Stack name**: `db`

   c. **Build method**: Choose one of:
      - **Repository**: Point to your git repo
      - **Upload**: Upload your `docker-compose.yaml`
      - **Web editor**: Paste the contents of `docker-compose/db/docker-compose.yaml`

   d. **Environment variables**: Click **Add environment variable** and add all variables from your `.env` file:
      - `POSTGRES_PASSWORD`
      - `POSTGRES_USER`
      - Any other required variables

   e. Click **Deploy the stack**

4. **Restore PostgreSQL data (Optional but Recommended)**

   If you have critical data in your existing PostgreSQL:

   ```bash
   # Wait for PostgreSQL to initialize (check logs in Portainer)
   # Go to Portainer → Containers → postgre_db → Logs

   # Restore your backup via CLI
   cat postgres_backup_YYYYMMDD.sql | docker exec -i postgre_db psql -U postgres
   ```

5. **Verify services are healthy**

   **Via Portainer Console**:
   - Go to **Containers** → Click on container → **Console** → **Connect**

   ```bash
   # Test Redis (in shared_redis console)
   redis-cli ping
   # Should return: PONG

   # Test PostgreSQL (in postgre_db console)
   psql -U postgres -d default -c "SELECT extname FROM pg_extension;"
   # Should show: postgis, vector, uuid-ossp, pg_trgm, btree_gist
   ```

   **Or via CLI**:
   ```bash
   docker exec shared_redis redis-cli ping
   docker exec postgre_db psql -U postgres -d default -c "SELECT extname FROM pg_extension;"
   ```

### Phase 4: Update Immich Configuration via Portainer

**Preparation Steps (both options)**

1. **Update your docker-compose.yaml** file with the configuration shown in the section below
2. **Save your changes** to the `docker-compose/photos/docker-compose.yaml` file

**Option A: Quick Method (if Immich data is not critical)**

1. In **Portainer** → **Stacks** → Select `photos` stack
2. Click **Stop** and then **Remove**
3. Remove old Redis volume:
   - Go to **Volumes** → Find `photos_immich_redis` (or similar) → **Remove**
4. Create new stack:
   - **Stacks** → **Add stack**
   - **Stack name**: `photos`
   - Upload/paste your updated `docker-compose.yaml`
   - Add all environment variables from `.env`
   - Click **Deploy the stack**

**Option B: Preserve Method (to keep Immich data)**

1. **Backup Immich Redis data** (via CLI):
   ```bash
   docker exec immich_redis redis-cli SAVE
   docker cp immich_redis:/data/dump.rdb immich_redis_backup.rdb
   ```

2. In **Portainer** → **Stacks** → Select `photos` stack → **Stop**

3. **Copy Redis data to shared Redis** (if needed):
   ```bash
   docker cp immich_redis_backup.rdb shared_redis:/data/dump.rdb
   docker exec shared_redis redis-cli BGREWRITEAOF
   ```

4. Update the stack in Portainer:
   - Click **Editor** on the stopped stack
   - Paste your updated `docker-compose.yaml` (with redis service removed)
   - Update environment variables if needed
   - Click **Update the stack**
   - Click **Start** to restart the stack

#### Updated Immich docker-compose.yaml

Remove the `redis` service section and update `immich-server`:

```yaml
services:
  immich-server:
    container_name: immich_server
    image: ghcr.io/immich-app/immich-server:${IMMICH_VERSION:-release}
    user: 1000:0
    environment:
      IMMICH_MACHINE_LEARNING_URL: http://immich-machine-learning:3003
      # NEW: Point to shared Redis
      REDIS_HOSTNAME: shared_redis
      DB_HOSTNAME: immich_postgres  # Keep using its own database
    volumes:
      - ${UPLOAD_LOCATION}:/data
      - /etc/localtime:/etc/localtime:ro
      - /share/Media/Pictures:/pictures:ro
    ports:
      - '2283:2283'
    depends_on:
      - database
    networks:
      - default
      - db_redis  # NEW: Connect to db stack's redis network
    restart: always
    healthcheck:
      disable: false

  # ... rest of your services ...

  database:
    # Keep this as-is, Immich uses its own database
    user: 1000:0
    container_name: immich_postgres
    image: ghcr.io/immich-app/postgres:14-vectorchord0.4.3-pgvectors0.2.0@sha256:32324a2f41df5de9efe1af166b7008c3f55646f8d0e00d9550c16c9822366b4a
    environment:
      POSTGRES_PASSWORD: ${DB_PASSWORD}
      POSTGRES_USER: ${DB_USERNAME}
      POSTGRES_DB: ${DB_DATABASE_NAME}
      POSTGRES_INITDB_ARGS: '--data-checksums'
    volumes:
      - ${IMMICH_HOME}/.var/database:/var/lib/postgresql/data
    shm_size: 128mb
    restart: always

networks:
  db_redis:
    external: true
    name: db_redis
```

### Phase 5: Deploy Dawarich via Portainer

1. **Prepare environment file**
   ```bash
   cd docker-compose/dawarich

   # Copy and configure environment
   cp .env.example .env
   nano .env  # Edit with your values

   # Generate secret key
   openssl rand -hex 64
   # Copy output to SECRET_KEY_BASE in .env
   ```

2. **Connect db containers to dawarich network** (via CLI)
   ```bash
   docker network connect dawarich shared_redis
   docker network connect dawarich postgre_db
   ```

   Or via **Portainer**:
   - Go to **Networks** → Select `dawarich` network
   - Scroll to **Connected containers**
   - Click **Join network** → Select `shared_redis` and `postgre_db`

3. **Deploy Dawarich stack in Portainer**

   a. Go to **Portainer** → **Stacks** → **Add stack**

   b. **Stack name**: `dawarich`

   c. **Build method**: Choose one of:
      - **Repository**: If your repo is accessible via git
        - **Repository URL**: `https://github.com/yourusername/archivum-infra`
        - **Repository reference**: `refs/heads/main`
        - **Compose path**: `docker-compose/dawarich/docker-compose.yaml`
      - **Upload**: Upload your `docker-compose.yaml`
      - **Web editor**: Paste the contents

   d. **Environment variables**: Add all variables from your `.env` file:
      - `SECRET_KEY_BASE`
      - `DATABASE_HOST=postgre_db`
      - `REDIS_URL=redis://shared_redis:6379/1`
      - All other required variables

   e. Click **Deploy the stack**

4. **Monitor first-time setup**

   In **Portainer** → **Containers**:
   - Click on `dawarich_setup` → **Logs** → Watch initialization
   - Click on `dawarich_app` → **Logs** → Verify it starts successfully

### Phase 6: Verification

**Via Portainer UI**:
1. Go to **Containers** and verify all containers show "running" status
2. Check container logs for any errors:
   - `shared_redis` → Logs
   - `postgre_db` → Logs
   - `dawarich_app` → Logs
   - `immich_server` → Logs

**Via Portainer Console** (click container → Console → Connect):

For `dawarich_app` container:
```bash
# Test Redis connectivity
echo "PING" | nc shared_redis 6379

# Test PostgreSQL
pg_isready -h postgre_db -U postgres
```

For `postgre_db` container:
```bash
# Check database was created
psql -U postgres -l | grep dawarich
```

**Via CLI** (alternative):
```bash
# 1. Check all containers are running
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# 2. Verify Redis connectivity
docker exec dawarich_app sh -c 'echo "PING" | nc shared_redis 6379'
docker exec immich_server sh -c 'echo "PING" | nc shared_redis 6379'

# 3. Verify PostgreSQL
docker exec dawarich_app sh -c 'pg_isready -h postgre_db -U postgres'

# 4. Check database was created
docker exec postgre_db psql -U postgres -l | grep dawarich

# 5. Test Dawarich web interface
curl http://localhost:3000/api/v1/health
# Should return: {"status":"ok"}

# 6. Test Immich (if applicable)
curl http://localhost:2283/api/server-info/ping
```

## Rollback Plan

If something goes wrong:

### Rollback Database Stack

**Via Portainer**:
1. Go to **Stacks** → Select `db` stack
2. Click **Editor**
3. Change `build: ./postgresql` to `image: pgvector/pgvector:pg17` in the PostgreSQL service
4. Click **Update the stack**

**Via CLI**:
```bash
cd docker-compose/db

# 1. Stop new stack
docker-compose down

# 2. Restore old PostgreSQL image in docker-compose.yaml
# Change: build: ./postgresql
# To: image: pgvector/pgvector:pg17

# 3. Restart
docker-compose up -d
```

### Rollback Immich

**Via Portainer**:
1. Go to **Stacks** → Select `photos` stack
2. Click **Editor**
3. Restore the backup configuration (re-add redis service, update environment)
4. Click **Update the stack**

**Via CLI**:
```bash
cd docker-compose/photos

# 1. Stop Immich
docker-compose down

# 2. Restore backup of docker-compose.yaml
cp docker-compose.yaml.backup docker-compose.yaml

# 3. Restart with old Redis
docker-compose up -d
```

### Restore Database Data

```bash
# If you need to restore from backup
cat postgres_backup_YYYYMMDD.sql | docker exec -i postgre_db psql -U postgres
```

## Post-Migration

### Update Other Services

Now that you have shared infrastructure, update other services to use:

**Shared Redis**: `redis://shared_redis:6379/X` (use different database numbers for each service)
- Database 0: Default (or Immich)
- Database 1: Dawarich
- Database 2-15: Available for other services

**Shared PostgreSQL**: Create separate databases for each service
```bash
docker exec postgre_db psql -U postgres -c "CREATE DATABASE service_name;"
```

### Monitor Resources

```bash
# Check resource usage
docker stats shared_redis postgre_db

# Check PostgreSQL database sizes
docker exec postgre_db psql -U postgres -c "
  SELECT datname, pg_size_pretty(pg_database_size(datname))
  FROM pg_database
  ORDER BY pg_database_size(datname) DESC;
"

# Check Redis memory usage
docker exec shared_redis redis-cli INFO memory
```

### Regular Maintenance

1. **Backup regularly**
   ```bash
   # Weekly PostgreSQL backup
   docker exec postgre_db pg_dumpall -U postgres | gzip > backup_$(date +%Y%m%d).sql.gz

   # Weekly Redis backup
   docker exec shared_redis redis-cli BGSAVE
   ```

2. **Monitor logs**
   ```bash
   docker logs --tail 100 shared_redis
   docker logs --tail 100 postgre_db
   ```

3. **Vacuum PostgreSQL** (monthly)
   ```bash
   docker exec postgre_db vacuumdb -U postgres -a -v
   ```

## Troubleshooting

### Issue: Can't connect to shared_redis

```bash
# Check if containers are on the same network
docker inspect dawarich_app | grep -A 10 Networks
docker inspect shared_redis | grep -A 10 Networks

# Connect manually if needed
docker network connect <network_name> shared_redis
```

### Issue: PostGIS extension not found

```bash
# Verify extensions are installed
docker exec postgre_db psql -U postgres -d dawarich -c "\dx"

# If missing, enable manually
docker exec postgre_db psql -U postgres -d dawarich -c "CREATE EXTENSION postgis;"
```

### Issue: Build fails for custom PostgreSQL

```bash
# Check build logs
docker-compose build --no-cache postgre

# If pgvector fails, check git tag version in Dockerfile
# Verify Alpine packages are available
docker run --rm postgis/postgis:17-3.5-alpine apk search build-base
```

### Issue: Permission denied errors

```bash
# Check volume permissions
docker exec postgre_db ls -la /var/lib/postgresql/data

# Fix permissions if needed
docker exec -u root postgre_db chown -R postgres:postgres /var/lib/postgresql/data
```

## Advanced: Managing Stacks via Git in Portainer

For automated deployments and version control, you can configure Portainer to pull stack definitions directly from Git:

### Initial Setup

1. **Go to Portainer** → **Stacks** → **Add stack**
2. **Stack name**: e.g., `db`, `photos`, `dawarich`
3. **Build method**: Select **Repository**
4. Configure repository settings:
   - **Repository URL**: `https://github.com/yourusername/archivum-infra` (or your git URL)
   - **Repository reference**: `refs/heads/main`
   - **Compose path**: Path to your compose file, e.g.:
     - `docker-compose/db/docker-compose.yaml`
     - `docker-compose/photos/docker-compose.yaml`
     - `docker-compose/dawarich/docker-compose.yaml`
5. **Authentication**: If private repo, add credentials
6. Add **Environment variables** (from your `.env` files)
7. Click **Deploy the stack**

### Enable Auto-updates

1. Go to your stack in **Portainer** → **Stacks** → Select stack
2. Click **Edit** or scroll to **Automatic updates**
3. Enable **GitOps updates** or **Webhook**
4. Configure polling interval or webhook URL
5. Portainer will automatically redeploy when changes are pushed to git

### Benefits of Git-based Deployment

- **Version control**: All changes tracked in git
- **Rollback capability**: Easily revert to previous commits
- **CI/CD ready**: Automatic deployments on git push
- **Team collaboration**: Multiple people can manage infrastructure
- **Disaster recovery**: Complete infrastructure as code

### Handling Environment Variables

Since `.env` files shouldn't be committed to git, you have two options:

**Option 1: Manual entry in Portainer**
- Add environment variables manually in Portainer UI (one-time setup)
- These persist across git updates

**Option 2: Use Portainer Environment Variable Sets**
1. Go to **Environments** → Select your environment
2. Create **Variable Sets** for different stacks
3. Reference these in your stack deployments

## Need Help?

- Check application logs in **Portainer** → **Containers** → **Logs**
- Check Portainer console for container status
- Verify network connectivity: Container → **Console** → `ping <target>`
- Review this guide's verification steps
