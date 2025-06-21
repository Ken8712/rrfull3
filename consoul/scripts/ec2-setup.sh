#!/bin/bash
# EC2 Setup Script for Consoul Application
# This script sets up a fresh Amazon Linux 2 EC2 instance for Rails deployment

set -e

echo "🚀 Starting Consoul EC2 setup..."

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as ec2-user
if [ "$USER" != "ec2-user" ]; then
    log_error "This script should be run as ec2-user"
    exit 1
fi

log_info "Step 1: System update and basic tools"
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

log_info "Step 3: MariaDB installation"
sudo yum install -y mariadb-server mariadb-devel
sudo systemctl start mariadb
sudo systemctl enable mariadb

# MariaDB configuration for t2.micro
sudo tee /etc/my.cnf.d/consoul.cnf > /dev/null <<'EOF'
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

log_info "Step 4: Redis 6 installation"
sudo amazon-linux-extras install -y redis6

# Redis configuration for t2.micro
sudo tee /etc/redis.conf > /dev/null <<'EOF'
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

log_info "Step 5: Nginx installation"
sudo amazon-linux-extras install -y nginx1
sudo systemctl start nginx
sudo systemctl enable nginx

log_info "Step 6: Node.js installation (for Rails assets)"
curl -sL https://rpm.nodesource.com/setup_18.x | sudo bash -
sudo yum install -y nodejs

log_info "Step 7: Creating application directory"
sudo mkdir -p /var/www
sudo chown ec2-user:ec2-user /var/www

log_info "Step 8: Setting up environment"
# Add Rails environment to bashrc
echo 'export RAILS_ENV=production' >> ~/.bashrc
source ~/.bashrc

log_info "✅ EC2 setup completed!"
echo ""
echo "Next steps:"
echo "1. Clone your application: cd /var/www && git clone https://github.com/your-username/consoul.git"
echo "2. Set up environment variables in /var/www/consoul/.env"
echo "3. Run the application setup: cd /var/www/consoul && ./scripts/app-setup.sh"
echo ""
echo "System information:"
ruby --version
node --version
mysql --version
redis-server --version
nginx -v