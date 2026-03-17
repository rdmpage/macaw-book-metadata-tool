FROM php:8.2-apache-bookworm

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    imagemagick \
    libmagickwand-dev \
    libxslt1-dev \
    libzip-dev \
    libpng-dev \
    libjpeg62-turbo-dev \
    libfreetype6-dev \
    libopenjp2-7 \
    libonig-dev \
    ghostscript \
    curl \
    unzip \
    default-mysql-client \
    && rm -rf /var/lib/apt/lists/*

# Install PHP extensions
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
    pdo_mysql \
    mysqli \
    xsl \
    zip \
    gd \
    mbstring

# Install imagick via PECL
RUN pecl install imagick && docker-php-ext-enable imagick

# Install Archive_Tar via PEAR (use upgrade in case it's already bundled)
RUN pear upgrade Archive_Tar || true

# Enable Apache modules
RUN a2enmod rewrite headers

# Configure PHP for large file uploads
RUN { \
    echo 'upload_max_filesize = 256M'; \
    echo 'post_max_size = 256M'; \
    echo 'memory_limit = 256M'; \
    echo 'max_execution_time = 300'; \
    } > /usr/local/etc/php/conf.d/macaw.ini

# Configure Apache virtual host
RUN { \
    echo '<VirtualHost *:80>'; \
    echo '  DocumentRoot /var/www/html'; \
    echo '  <Directory /var/www/html>'; \
    echo '    Options +FollowSymLinks -Indexes'; \
    echo '    AllowOverride All'; \
    echo '    Require all granted'; \
    echo '  </Directory>'; \
    echo '  ErrorLog /dev/stderr'; \
    echo '  CustomLog /dev/stdout combined'; \
    echo '</VirtualHost>'; \
    } > /etc/apache2/sites-available/000-default.conf

# Set working directory
WORKDIR /var/www/html

# Copy application code
COPY . /var/www/html/

# Copy entrypoint script and make executable
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Fix plugin filename case issue
RUN if [ -f plugins/export/Internet_archive.php ] && [ ! -f plugins/export/Internet_Archive.php ]; then \
    cp plugins/export/Internet_archive.php plugins/export/Internet_Archive.php; \
    fi

# Create required directories and set permissions
RUN mkdir -p books incoming system/application/logs system/application/logs/books \
    && chown -R www-data:www-data /var/www/html \
    && chmod -R u+w books incoming system/application/logs system/application/config

EXPOSE 80

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["apache2-foreground"]
