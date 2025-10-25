-- Enable pgvector extension for vector similarity search
-- This must be run before the trajectory tables migration
-- Run with: psql $DATABASE_URL -f setup-pgvector.sql

CREATE EXTENSION IF NOT EXISTS vector;

-- Verify installation
SELECT * FROM pg_extension WHERE extname = 'vector';
