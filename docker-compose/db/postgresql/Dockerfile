# Custom PostgreSQL image with commonly needed extensions
# Based on PostgreSQL 17 with PostGIS support
FROM postgis/postgis:17-3.5-alpine

LABEL maintainer="archivum-infra"
LABEL description="PostgreSQL 17 with PostGIS, pgvector, and other useful extensions"

# Install build dependencies and pgvector
RUN apk add --no-cache --virtual .build-deps \
    git \
    build-base \
    clang15 \
    llvm15-dev \
    && cd /tmp \
    # Install pgvector
    && git clone --branch v0.8.0 https://github.com/pgvector/pgvector.git \
    && cd pgvector \
    && make \
    && make install \
    && cd / \
    && rm -rf /tmp/pgvector \
    # Cleanup build dependencies but keep runtime dependencies
    && apk del .build-deps \
    && rm -rf /var/cache/apk/*

# Create initialization script to enable extensions
COPY init-extensions.sql /docker-entrypoint-initdb.d/

# Copy custom PostgreSQL configuration
COPY postgresql.conf /usr/local/share/postgresql/postgresql.conf.sample

# Set default environment variables
ENV POSTGRES_INITDB_ARGS="--data-checksums"

# Use custom configuration
CMD ["postgres", "-c", "config_file=/usr/local/share/postgresql/postgresql.conf.sample"]

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD pg_isready -U ${POSTGRES_USER:-postgres} || exit 1

# Use postgres user
USER postgres
