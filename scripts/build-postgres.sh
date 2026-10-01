#!/bin/bash

# Script to set up PostgreSQL with PostGIS + pgvector
# Uses pre-built image from Docker Hub
# Usage: ./scripts/build-postgres.sh [local|production]

set -e

echo "=========================================="
echo "Setting up PostgreSQL with PostGIS + pgvector"
echo "=========================================="

ENVIRONMENT=${1:-local}

echo ""
echo "Environment: $ENVIRONMENT"
echo "Using pre-built image: garapadev/postgres-postgis-pgvector:13"
echo ""

# Determine which compose file to use
if [ "$ENVIRONMENT" = "production" ]; then
    COMPOSE_FILE="docker-compose.yml"
    DB_NAME="forem_production"
    DB_USER="forem"
else
    COMPOSE_FILE="docker-compose.local.yml"
    DB_NAME="forem_development"
    DB_USER="forem"
fi

echo "Using compose file: $COMPOSE_FILE"
echo ""

# Clean up any existing containers
if [ "$ENVIRONMENT" = "local" ]; then
    echo "Stopping existing containers..."
    docker-compose -f $COMPOSE_FILE down 2>/dev/null || true
else
    echo "Stopping existing containers..."
    docker-compose down 2>/dev/null || true
fi

# Pull the pre-built PostgreSQL image
echo ""
echo "Pulling PostgreSQL image with PostGIS + pgvector..."
if [ "$ENVIRONMENT" = "local" ]; then
    docker-compose -f $COMPOSE_FILE pull postgres
else
    docker-compose pull postgres
fi

echo ""
echo "✓ PostgreSQL image pulled successfully"
echo ""

# Start the services
echo "Starting services..."
if [ "$ENVIRONMENT" = "local" ]; then
    docker-compose -f $COMPOSE_FILE up -d
else
    docker-compose up -d
fi

echo ""
echo "✓ Services started"
echo ""

# Wait for PostgreSQL to be ready
echo "Waiting for PostgreSQL to be ready..."
if [ "$ENVIRONMENT" = "local" ]; then
    docker-compose -f $COMPOSE_FILE exec -T postgres bash -c "
      until pg_isready -U $DB_USER -d $DB_NAME; do
        echo 'Waiting for PostgreSQL...'
        sleep 2
      done
    " 2>&1 | grep -v "Waiting for PostgreSQL" || true
else
    docker-compose exec -T postgres bash -c "
      until pg_isready -U $DB_USER -d $DB_NAME; do
        echo 'Waiting for PostgreSQL...'
        sleep 2
      done
    " 2>&1 | grep -v "Waiting for PostgreSQL" || true
fi

sleep 5

echo ""
echo "✓ PostgreSQL is ready"
echo ""

# Verify extensions
echo "Verifying PostgreSQL extensions..."
if [ "$ENVIRONMENT" = "local" ]; then
    EXTENSIONS=$(docker-compose -f $COMPOSE_FILE exec postgres psql -U $DB_USER -d $DB_NAME -t -c "
      SELECT string_agg(extname, ', ') FROM pg_extension WHERE extname IN ('postgis', 'vector');
    " 2>/dev/null | tr -d '[:space:]')
else
    EXTENSIONS=$(docker-compose exec postgres psql -U $DB_USER -d $DB_NAME -t -c "
      SELECT string_agg(extname, ', ') FROM pg_extension WHERE extname IN ('postgis', 'vector');
    " 2>/dev/null | tr -d '[:space:]')
fi

if [ "$EXTENSIONS" = "postgis,vector" ] || [ "$EXTENSIONS" = "vector,postgis" ]; then
    echo "✓ Both extensions are enabled: $EXTENSIONS"
else
    echo "⚠ Extensions found: $EXTENSIONS"
    echo "  This might be OK if the database hasn't been initialized yet."
    echo "  The migrations will enable both extensions."
fi

echo ""
echo "=========================================="
echo "Setup complete!"
echo "=========================================="
echo ""
echo "The PostgreSQL image already has both PostGIS and pgvector extensions."
echo "The database migrations will enable them automatically."
echo ""
echo "To run database migrations:"
echo ""
if [ "$ENVIRONMENT" = "local" ]; then
    echo "  docker-compose -f $COMPOSE_FILE run --rm setup"
    echo ""
    echo "  (The setup service already runs 'bundle install && yarn install && rails db:prepare')"
else
    echo "  docker-compose run migrate"
fi
echo ""
echo "To test the geosearch functionality:"
echo ""
echo "  # Connect to database:"
if [ "$ENVIRONMENT" = "local" ]; then
    echo "  docker-compose -f $COMPOSE_FILE exec postgres psql -U $DB_USER -d $DB_NAME"
else
    echo "  docker-compose exec postgres psql -U $DB_USER -d $DB_NAME"
fi
echo ""
echo "  # In psql, verify extensions:"
echo "  SELECT * FROM pg_extension WHERE extname IN ('postgis', 'vector');"
echo ""
echo "  # Check the article_geodata table:"
echo "  \d article_geodata"
echo ""
