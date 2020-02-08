#!/bin/bash
# Non interactive env
export DEBIAN_FRONTEND=noninteractive

# Update
sudo apt-get update
sudo apt-get upgrade -y

# Language
sudo apt-get install -y language-pack-tr

# Locale
sudo locale-gen en_US.UTF-8
export LANG=en_US.UTF-8

# Tools
sudo apt-get install -y python zip git composer

# Nginx
sudo apt-get install -y nginx
sudo service nginx stop
sudo sed 's/www-data/ubuntu/' -i /etc/nginx/nginx.conf

# PHP 7.2
sudo apt-get install -y php7.2 \
php7.2-cli \
php7.2-common \
php7.2-fpm \
php7.2-mysql \
php7.2-curl \
php7.2-gd \
php7.2-json \
php7.2-tidy \
php7.2-mbstring \
php7.2-xml \
php7.2-dom \
php7.2-soap \
php7.2-zip \
php-redis \
php-imagick
sudo service php7.2-fpm stop
sudo sed 's/www-data/ubuntu/' -i /etc/php/7.2/fpm/pool.d/www.conf

sudo -u ubuntu -H sh -c "git clone https://sahinhanay@bitbucket.org/mobillium/sim4crew-web.git /home/ubuntu/sim4crew-web"
sudo -u ubuntu -H sh -c "composer install --no-dev --no-interaction --optimize-autoloader -d /home/ubuntu/sim4crew-web"

sudo cat > /home/ubuntu/sim4crew-web/.env <<'EOTB'

EOTB

chown ubuntu:ubuntu /home/ubuntu/sim4crew-web/.env

# Optimize
sudo -u ubuntu -H sh -c "php /home/ubuntu/sim4crew-web/artisan route:cache"
sudo -u ubuntu -H sh -c "php /home/ubuntu/si-web/artisan config:cache"

# Nginx Config

cat > /etc/nginx/nginx.conf <<'EOTB'
user ubuntu;
worker_processes auto;
pid /run/nginx.pid;

events {
    worker_connections 1024;
    # multi_accept on;
}

http {

    ##
    # Basic Settings
    ##

    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    # server_tokens off;

    # server_names_hash_bucket_size 64;
    # server_name_in_redirect off;

    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    ##
    # SSL Settings
    ##

    ssl_protocols TLSv1 TLSv1.1 TLSv1.2; # Dropping SSLv3, ref: POODLE
    ssl_prefer_server_ciphers on;

    ##
    # Logging Settings
    ##

    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;

    ##
    # Gzip Settings
    ##

    gzip on;
    gzip_disable "msie6";

    # gzip_vary on;
    # gzip_proxied any;
    # gzip_comp_level 6;
    # gzip_buffers 16 8k;
    # gzip_http_version 1.1;
    # gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;

    ##
    # Virtual Host Configs
    ##

    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
}
EOTB

cat > /etc/nginx/sites-available/www.sim4crew.co <<'EOTB'
server {
	 listen 80;
	 server_name www.sim4crew.co;
	 return 301 https://sim4crew.co$request_uri;
}
EOTB

cat > /etc/nginx/sites-available/sim4crew.co <<'EOTB'
server {
    listen 80 default_server;
    server_name sim4crew.co;
    root "/home/ubuntu/sim4crew-web/public";

    index index.html index.htm index.php;

    charset utf-8;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location = /favicon.ico { access_log off; log_not_found off; }
    location = /robots.txt  { access_log off; log_not_found off; }

    access_log /home/ubuntu/sim4crew-web/access.log ;
    error_log  /home/ubuntu/sim4crew-web/error.log error;

    sendfile off;

    client_max_body_size 100m;

    location ~ \.php$ { 
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass 127.0.0.1:9000;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_intercept_errors off;
        fastcgi_buffer_size 16k;
        fastcgi_buffers 4 16k;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOTB

ln -s /etc/nginx/sites-available/sim4crew.co /etc/nginx/sites-enabled/
rm /etc/nginx/sites-enabled/default

# Php Config
cat > /etc/php/7.2/fpm/pool.d/www.conf <<'EOTB'
[www]
user = ubuntu 
group = ubuntu

listen = 127.0.0.1:9000
listen.owner = ubuntu
listen.group = ubuntu
listen.allowed_clients = 127.0.0.1

pm = static
pm.max_children = 5
EOTB

cat > /etc/php/7.2/mods-available/mobillium.ini <<'EOTB'
upload_max_filesize = 100M
post_max_size = 100M
memory_limit = 100M
EOTB
ln -s /etc/php/7.2/mods-available/mobillium.ini /etc/php/7.2/fpm/conf.d/30-mobillium.ini

# Start
service nginx restart
service php7.2-fpm restart