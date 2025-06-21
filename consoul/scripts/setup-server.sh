#!/bin/bash
# Consoul Server Setup Script for AWS EC2 t2.micro
# Domain: main.infra1205.xyz
# IP: 13.113.184.147

set -e  # Exit on any error

echo "🚀 Starting Consoul server setup..."

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Variables
DOMAIN="main.infra1205.xyz"
APP_USER="ec2-user"
APP_DIR="/home/ec2-user/consoul"
EMAIL="admin@infra1205.xyz"  # Change this to your email

log_info "Step 1: System update and basic tools installation"
sudo yum update -y
sudo yum groupinstall -y "Development Tools"
sudo yum install -y git curl wget openssl-devel readline-devel zlib-devel libyaml-devel libffi-devel

log_info "Step 2: Installing rbenv and Ruby 3.2.0"
if [ ! -d ~/.rbenv ]; then
    git clone https://github.com/rbenv/rbenv.git ~/.rbenv
    git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build
    
    echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
    echo 'eval "$(rbenv init -)"' >> ~/.bashrc
    export PATH="$HOME/.rbenv/bin:$PATH"
    eval "$(rbenv init -)"
    
    log_info "Installing Ruby 3.2.0 (this may take 10-15 minutes)..."
    rbenv install 3.2.0
    rbenv global 3.2.0
    rbenv rehash
    
    gem install bundler
    rbenv rehash
else
    log_warn "rbenv already installed"
fi

log_info "Step 3: MariaDB installation and setup"
sudo yum install -y mariadb-server mariadb-devel
sudo systemctl start mariadb
sudo systemctl enable mariadb

# MariaDB configuration for t2.micro
sudo tee /etc/my.cnf.d/consoul.cnf > /dev/null <<EOF
[mysqld]
# t2.micro optimization
innodb_buffer_pool_size = 128M
innodb_log_file_size = 32M
innodb_log_buffer_size = 8M
max_connections = 50
table_open_cache = 256
query_cache_type = 1
query_cache_size = 32M
tmp_table_size = 32M
max_heap_table_size = 32M
EOF

sudo systemctl restart mariadb

# Create database and user
DB_PASSWORD=$(openssl rand -base64 32)
echo "Database password: $DB_PASSWORD" > ~/db_credentials.txt
chmod 600 ~/db_credentials.txt

mysql -u root -e "
CREATE DATABASE IF NOT EXISTS consoul_production CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'consoul'@'localhost' IDENTIFIED BY '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON consoul_production.* TO 'consoul'@'localhost';
FLUSH PRIVILEGES;
"

log_info "Step 4: Redis installation and setup"
sudo yum install -y redis
sudo tee /etc/redis.conf > /dev/null <<EOF
bind 127.0.0.1
port 6379
daemonize yes
pidfile /var/run/redis.pid
logfile /var/log/redis.log
loglevel notice
databases 16
save ""
maxmemory 100mb
maxmemory-policy allkeys-lru
EOF

sudo systemctl start redis
sudo systemctl enable redis

log_info "Step 5: Nginx installation and basic setup"
sudo amazon-linux-extras install -y nginx1
sudo systemctl start nginx
sudo systemctl enable nginx

log_info "Step 6: Application deployment"
if [ ! -d "$APP_DIR" ]; then
    cd /home/ec2-user
    git clone https://github.com/your-username/consoul.git || {
        log_error "Failed to clone repository. Please make sure the repository is accessible."
        log_info "Manual alternative: Upload your code to EC2 using scp"
        exit 1
    }
else
    log_warn "Application directory already exists"
fi

cd $APP_DIR

# Create environment file
SECRET_KEY=$(openssl rand -hex 64)
tee .env.production > /dev/null <<EOF
RAILS_ENV=production
SECRET_KEY_BASE=$SECRET_KEY
CONSOUL_DATABASE_PASSWORD=$DB_PASSWORD
REDIS_URL=redis://localhost:6379/0
EOF

chmod 600 .env.production

# Install gems
export PATH="$HOME/.rbenv/bin:$PATH"
eval "$(rbenv init -)"
bundle config set --local deployment 'true'
bundle config set --local without 'development test'
bundle install

# Database setup
source .env.production
bundle exec rails db:migrate

# Assets compilation
bundle exec rails assets:precompile

# Create log directory
mkdir -p log
touch log/production.log log/unicorn.stderr.log log/unicorn.stdout.log

log_info "Step 7: Nginx configuration for domain"
sudo tee /etc/nginx/conf.d/consoul.conf > /dev/null <<EOF
upstream consoul {
    server unix:/tmp/unicorn.sock fail_timeout=0;
}

server {
    listen 80;
    server_name $DOMAIN;
    
    root $APP_DIR/public;
    
    # Temporary response before SSL setup
    location / {
        try_files \$uri/index.html \$uri @consoul;
    }
    
    location @consoul {
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header Host \$http_host;
        proxy_redirect off;
        proxy_read_timeout 60s;
        proxy_send_timeout 60s;
        proxy_pass http://consoul;
    }
    
    location ~* \.(css|js|png|jpg|jpeg|gif|ico|svg)$ {
        expires 1y;
        add_header Cache-Control public;
        add_header ETag "";
        break;
    }
    
    access_log /var/log/nginx/consoul_access.log;
    error_log /var/log/nginx/consoul_error.log;
}
EOF

sudo nginx -t
sudo systemctl reload nginx

log_info "Step 8: Unicorn service setup"
sudo tee /etc/systemd/system/consoul.service > /dev/null <<EOF
[Unit]
Description=Consoul Unicorn Server
After=network.target

[Service]
Type=forking
User=$APP_USER
WorkingDirectory=$APP_DIR
Environment=RAILS_ENV=production
EnvironmentFile=$APP_DIR/.env.production
ExecStart=/home/$APP_USER/.rbenv/shims/bundle exec unicorn -c config/unicorn.rb -E production -D
ExecReload=/bin/kill -USR2 \$MAINPID
KillMode=mixed
TimeoutStopSec=5
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable consoul
sudo systemctl start consoul

# Wait for unicorn to start
sleep 5

if systemctl is-active --quiet consoul; then
    log_info "✅ Unicorn service started successfully"
else
    log_error "❌ Unicorn service failed to start"
    log_info "Checking logs..."
    sudo systemctl status consoul
    tail -n 20 log/unicorn.stderr.log
fi

log_info "Step 9: Basic security setup"
# Firewall setup (if firewalld is available)
if command -v firewall-cmd &> /dev/null; then
    sudo firewall-cmd --permanent --add-service=http
    sudo firewall-cmd --permanent --add-service=https
    sudo firewall-cmd --reload
fi

log_info "Step 10: Testing basic connectivity"
sleep 2
if curl -s -o /dev/null -w "%{http_code}" http://localhost | grep -q "200\|302\|404"; then
    log_info "✅ Local HTTP server responding"
else
    log_warn "⚠️  Local HTTP server not responding properly"
fi

log_info "🎉 Basic server setup completed!"
echo ""
echo "Summary:"
echo "- Domain: $DOMAIN"
echo "- IP: 13.113.184.147"
echo "- Database credentials: ~/db_credentials.txt"
echo "- Application directory: $APP_DIR"
echo "- Environment file: $APP_DIR/.env.production"
echo ""
echo "Next steps:"
echo "1. Test HTTP access: curl -I http://$DOMAIN"
echo "2. Run SSL setup script"
echo "3. Final testing"
echo ""
log_info "Setup script completed successfully!"