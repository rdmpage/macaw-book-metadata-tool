#!/bin/bash
set -e

# Ensure writable directories exist with correct ownership
mkdir -p /var/www/html/books \
         /var/www/html/incoming \
         /var/www/html/system/application/logs \
         /var/www/html/system/application/logs/books

chown -R www-data:www-data \
    /var/www/html/books \
    /var/www/html/incoming \
    /var/www/html/system/application/logs \
    /var/www/html/system/application/config

# Wait for MySQL to be ready (if DB_HOST is set)
if [ -n "$DB_HOST" ]; then
    echo "Waiting for MySQL at $DB_HOST:${DB_PORT:-3306}..."
    timeout=60
    while ! mysqladmin ping -h "$DB_HOST" -P "${DB_PORT:-3306}" --silent 2>/dev/null; do
        timeout=$((timeout - 1))
        if [ $timeout -le 0 ]; then
            echo "Timed out waiting for MySQL"
            break
        fi
        sleep 1
    done
    echo "MySQL is ready."
fi

# If config files don't exist yet, create them from defaults so install.php can work
for f in config database macaw; do
    src="/var/www/html/system/application/config/${f}.default.php"
    dst="/var/www/html/system/application/config/${f}.php"
    if [ ! -f "$dst" ] && [ -f "$src" ]; then
        cp "$src" "$dst"
        chown www-data:www-data "$dst"
    fi
done

# ---------- Database configuration ----------
if [ -n "$DB_HOST" ] && [ -n "$DB_NAME" ] && [ -n "$DB_USER" ]; then
    DB_FILE="/var/www/html/system/application/config/database.php"
    sed -i "s|\$db\['default'\]\['hostname'\] = \".*\"|\$db['default']['hostname'] = \"$DB_HOST\"|" "$DB_FILE"
    sed -i "s|\$db\['default'\]\['username'\] = \".*\"|\$db['default']['username'] = \"$DB_USER\"|" "$DB_FILE"
    sed -i "s|\$db\['default'\]\['password'\] = \".*\"|\$db['default']['password'] = \"${DB_PASS:-}\"|" "$DB_FILE"
    sed -i "s|\$db\['default'\]\['database'\] = \".*\"|\$db['default']['database'] = \"$DB_NAME\"|" "$DB_FILE"
    sed -i "s|\$db\['default'\]\['dbdriver'\] = \".*\"|\$db['default']['dbdriver'] = \"mysqli\"|" "$DB_FILE"
    sed -i "s|\$db\['default'\]\['port'\] = \".*\"|\$db['default']['port'] = \"${DB_PORT:-3306}\"|" "$DB_FILE"
fi

# ---------- Macaw configuration ----------
MACAW_FILE="/var/www/html/system/application/config/macaw.php"

# Set base directory for Docker
if grep -q '/path/to/webroot/htdocs' "$MACAW_FILE" 2>/dev/null; then
    sed -i 's|/path/to/webroot/htdocs|/var/www/html|' "$MACAW_FILE"
fi

# Set incoming directory if empty
if grep -q "incoming_directory'] = '';" "$MACAW_FILE" 2>/dev/null; then
    sed -i "s|incoming_directory'\] = '';|incoming_directory'] = '/var/www/html/incoming';|" "$MACAW_FILE"
fi

# Helper: set a simple string config value from an environment variable.
# Usage: set_macaw_config ENV_VAR_NAME config_key
set_macaw_config() {
    local env_val="${!1}"
    local key="$2"
    [ -z "$env_val" ] && return 0
    # If the key already exists (commented or not), replace it; otherwise append it.
    if grep -qE "^\s*(//\s*)?\\\$config\['macaw'\]\['${key}'\]" "$MACAW_FILE"; then
        sed -i "s|^.*\\\$config\['macaw'\]\['${key}'\].*|\$config['macaw']['${key}'] = \"${env_val}\";|" "$MACAW_FILE"
    else
        echo "\$config['macaw']['${key}'] = \"${env_val}\";" >> "$MACAW_FILE"
    fi
}

# Organisation / admin
set_macaw_config MACAW_ADMIN_EMAIL     admin_email
set_macaw_config MACAW_ORG_NAME        organization_name

# SMTP
set_macaw_config MACAW_SMTP_HOST       email_smtp_host
set_macaw_config MACAW_SMTP_PORT       email_smtp_port
set_macaw_config MACAW_SMTP_USER       email_smtp_user
set_macaw_config MACAW_SMTP_PASS       email_smtp_pass

# BHL
set_macaw_config MACAW_BHL_API_KEY     bhl_api_key

# Internet Archive
set_macaw_config MACAW_IA_ACCESS_KEY   internet_archive_access_key
set_macaw_config MACAW_IA_SECRET       internet_archive_secret
set_macaw_config MACAW_IA_EMAIL        internet_archive_email
set_macaw_config MACAW_IA_PASSWORD     internet_archive_password

# Export modules (comma-separated → PHP array)
if [ -n "$MACAW_EXPORT_MODULES" ]; then
    # Turn "Internet_Archive,SIL_DAMS" into "'Internet_Archive','SIL_DAMS'"
    php_array=$(echo "$MACAW_EXPORT_MODULES" | sed "s/[[:space:]]*,[[:space:]]*/','/g")
    php_array="'${php_array}'"
    sed -i "s|^\$config\['macaw'\]\['export_modules'\].*|\$config['macaw']['export_modules'] = array(${php_array});|" "$MACAW_FILE"
fi

exec "$@"
