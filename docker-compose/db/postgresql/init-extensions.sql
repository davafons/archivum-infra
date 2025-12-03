-- Initialization script for PostgreSQL extensions
-- This script runs on container first startup and enables extensions in the default database

-- Enable PostGIS (spatial and geographic objects)
-- Required for: Dawarich and any location-based services
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS postgis_topology;

-- Enable pgvector (vector similarity search for AI/ML)
-- Required for: Vector databases, embeddings, similarity search
CREATE EXTENSION IF NOT EXISTS vector;

-- Enable uuid-ossp (UUID generation)
-- Commonly used for primary keys in modern applications
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Enable pg_trgm (trigram matching for fuzzy search)
-- Useful for: Full-text search, autocomplete, typo tolerance
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Enable btree_gist (additional index types)
-- Useful for: Complex queries with multiple data types
CREATE EXTENSION IF NOT EXISTS btree_gist;

-- Enable btree_gin (GIN index support for btree types)
-- Useful for: Multi-column indexes, composite queries
CREATE EXTENSION IF NOT EXISTS btree_gin;

-- Enable pgcrypto (cryptographic functions)
-- Useful for: Password hashing, encryption, secure random generation
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Enable pg_stat_statements (query performance tracking)
-- Useful for: Performance monitoring, slow query identification
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- Enable hstore (key-value store within PostgreSQL)
-- Useful for: Flexible schemas, dynamic attributes
CREATE EXTENSION IF NOT EXISTS hstore;

-- Enable citext (case-insensitive text type)
-- Useful for: Email addresses, usernames, case-insensitive searches
CREATE EXTENSION IF NOT EXISTS citext;

-- Enable unaccent (remove accents from text)
-- Useful for: International text search, normalization
CREATE EXTENSION IF NOT EXISTS unaccent;

-- Enable fuzzystrmatch (fuzzy string matching)
-- Useful for: Soundex, Levenshtein distance, typo-tolerant search
CREATE EXTENSION IF NOT EXISTS fuzzystrmatch;

-- Log which extensions were enabled
DO $$
BEGIN
    RAISE NOTICE 'Custom extensions initialized successfully:';
    RAISE NOTICE '  - postgis (spatial data)';
    RAISE NOTICE '  - postgis_topology (topology support)';
    RAISE NOTICE '  - vector (pgvector for AI/ML)';
    RAISE NOTICE '  - uuid-ossp (UUID generation)';
    RAISE NOTICE '  - pg_trgm (fuzzy text search)';
    RAISE NOTICE '  - btree_gist (advanced indexing)';
    RAISE NOTICE '  - btree_gin (GIN indexing)';
    RAISE NOTICE '  - pgcrypto (encryption functions)';
    RAISE NOTICE '  - pg_stat_statements (performance monitoring)';
    RAISE NOTICE '  - hstore (key-value store)';
    RAISE NOTICE '  - citext (case-insensitive text)';
    RAISE NOTICE '  - unaccent (accent removal)';
    RAISE NOTICE '  - fuzzystrmatch (fuzzy matching)';
END $$;
