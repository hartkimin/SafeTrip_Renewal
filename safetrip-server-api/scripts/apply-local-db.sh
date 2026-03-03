#!/bin/bash
# ============================================================================
# SafeTrip Local DB Schema Initializer (For Docker Compose)
# ============================================================================

cd "$(dirname "$0")/.." || exit 1

CONTAINER_NAME="safetrip-postgres-local"
DB_USER="safetrip"
DB_NAME="safetrip_local"

echo "============================================================"
echo "🐬 Applying SQL Schemas to local PostgreSQL ($CONTAINER_NAME)"
echo "============================================================"

# Check if container is running
if ! docker ps -f name=$CONTAINER_NAME | grep -q $CONTAINER_NAME; then
    echo "❌ Error: Container '$CONTAINER_NAME' is not running."
    echo "Start it first with: docker compose up -d"
    exit 1
fi

apply_sql() {
    local file="sql/$1"
    if [ ! -f "$file" ]; then
        echo "⚠️  File not found: $file (Skipping)"
        return
    fi
    echo "🔄 Applying: $file"
    docker exec -i $CONTAINER_NAME psql -U $DB_USER -d $DB_NAME -v ON_ERROR_STOP=1 < "$file"
    local status=$?
    if [ $status -ne 0 ]; then
        echo "❌ Error applying $file (Exit code: $status)"
        exit 1
    fi
    echo "✅ Success: $file"
}

# Apply schemas in chronological order
apply_sql "00-extensions-and-types.sql"
apply_sql "01-schema-user-group-trip.sql"
apply_sql "02-schema-guardian.sql"
apply_sql "03-schema-schedule-geofence.sql"
apply_sql "04-schema-location-movement.sql"
apply_sql "05-schema-safety-sos.sql"
apply_sql "06-schema-chat.sql"
apply_sql "07-schema-notification.sql"
apply_sql "08-schema-legal-privacy.sql"
apply_sql "09-schema-ops-log.sql"
apply_sql "10-schema-payment-b2b.sql"
apply_sql "99-deferred-fk.sql"

echo "============================================================"
echo "🎉 DB Schema Initialization Complete!"
echo "============================================================"
