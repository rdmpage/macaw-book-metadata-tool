#!/bin/bash
#
# Create the Macaw MySQL database and user.
# Reads credentials from .env if present, otherwise uses defaults.
#
# Usage:
#   sudo ./setup-database.sh            # uses .env or defaults
#   sudo ./setup-database.sh .env       # explicit path to env file
#
# Requires mysql client and root (or a privileged MySQL user).

set -e

# Load .env file if available
ENV_FILE="${1:-.env}"
if [ -f "$ENV_FILE" ]; then
    echo "Reading settings from $ENV_FILE"
    # Source only the variables we need (handles comments and blank lines)
    eval "$(grep -E '^(DB_NAME|DB_USER|DB_PASS)=' "$ENV_FILE")"
fi

# Defaults
DB_NAME="${DB_NAME:-macaw}"
DB_USER="${DB_USER:-macaw}"
DB_PASS="${DB_PASS:-macaw}"

echo "Database: $DB_NAME"
echo "User:     $DB_USER"
echo ""

mysql -u root -p <<EOF
CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` CHARACTER SET utf8 COLLATE utf8_general_ci;
CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
GRANT ALL ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
EOF

echo ""
echo "Done. Database '$DB_NAME' and user '$DB_USER' are ready."
