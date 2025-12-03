# Custom PostgreSQL Image

This directory contains a custom PostgreSQL image with pre-installed extensions commonly needed for modern applications.

## Included Extensions

- **PostGIS 3.5** - Spatial and geographic objects for location-based services
- **pgvector 0.8.0** - Vector similarity search for AI/ML embeddings
- **uuid-ossp** - UUID generation for primary keys
- **pg_trgm** - Trigram matching for fuzzy text search
- **btree_gist** - Additional index types for complex queries

## Building the Image

```bash
cd docker-compose/db/postgresql
docker build -t archivum-postgre:17 .
```

## Adding New Extensions

### Method 1: Rebuild the image (Recommended for compiled extensions)

1. Edit `Dockerfile` to add your extension installation steps
2. Rebuild the image
3. Update docker-compose.yaml to use the new image

### Method 2: SQL installation (For pure SQL extensions)

1. Add the extension to `init-extensions.sql`
2. Rebuild and restart the container with fresh data
3. Or manually run `CREATE EXTENSION` in existing databases

### Method 3: Runtime installation (For existing databases)

Connect to the database and run:
```sql
CREATE EXTENSION IF NOT EXISTS extension_name;
```

## Version Management

- Base: PostgreSQL 17
- PostGIS: 3.5
- pgvector: 0.8.0 (pinned for stability)

To upgrade versions:
1. Update version numbers in `Dockerfile`
2. Test in development environment
3. Backup production data
4. Rebuild and redeploy

## Useful PostgreSQL Extensions to Consider

Depending on your future needs, you might want to add:

- **pg_stat_statements** - Query performance monitoring
- **timescaledb** - Time-series data optimization
- **pg_cron** - Job scheduling within PostgreSQL
- **plpython3u** - Python procedural language
- **hstore** - Key-value store data type
- **pgcrypto** - Cryptographic functions
- **postgres_fdw** - Foreign data wrapper for connecting to other PostgreSQL servers

## Resources

- [PostGIS Documentation](https://postgis.net/documentation/)
- [pgvector GitHub](https://github.com/pgvector/pgvector)
- [PostgreSQL Extensions](https://www.postgresql.org/docs/current/contrib.html)
