#!/bin/bash
# Code Deployment Script for Consoul
# Upload and deploy local code to EC2

set -e

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

EC2_IP="13.113.184.147"
EC2_USER="ec2-user"
APP_DIR="/home/ec2-user/consoul"
LOCAL_DIR="/home/kentaro/oriapp/claude/rrfull3/consoul"

log_info "🚀 Deploying Consoul code to EC2..."

# Check if SSH key is provided
if [ -z "$1" ]; then
    log_warn "Usage: $0 <path-to-ssh-key.pem>"
    log_warn "Example: $0 ~/.ssh/my-key.pem"
    exit 1
fi

SSH_KEY="$1"

# Verify SSH key exists
if [ ! -f "$SSH_KEY" ]; then
    log_warn "SSH key not found: $SSH_KEY"
    exit 1
fi

# Set proper permissions for SSH key
chmod 600 "$SSH_KEY"

log_info "Step 1: Creating application directory on EC2"
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$EC2_USER@$EC2_IP" "mkdir -p $APP_DIR"

log_info "Step 2: Uploading application code"
# Create a tarball of the application code, excluding unnecessary files
cd "$LOCAL_DIR"
tar --exclude='*.git*' \
    --exclude='tmp/*' \
    --exclude='log/*' \
    --exclude='node_modules' \
    --exclude='coverage' \
    --exclude='*.log' \
    -czf /tmp/consoul-app.tar.gz .

# Upload the tarball
scp -i "$SSH_KEY" -o StrictHostKeyChecking=no /tmp/consoul-app.tar.gz "$EC2_USER@$EC2_IP:/tmp/"

# Extract on the server
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$EC2_USER@$EC2_IP" "
    cd $APP_DIR && 
    tar -xzf /tmp/consoul-app.tar.gz &&
    rm -f /tmp/consoul-app.tar.gz &&
    mkdir -p log tmp/pids tmp/cache tmp/sockets
"

log_info "Step 3: Setting up Ruby environment and dependencies"
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$EC2_USER@$EC2_IP" "
    cd $APP_DIR &&
    export PATH=\"\$HOME/.rbenv/bin:\$PATH\" &&
    eval \"\$(rbenv init -)\" &&
    bundle config set --local deployment 'true' &&
    bundle config set --local without 'development test' &&
    bundle install
"

log_info "Step 4: Database setup"
# Generate database password if not exists
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$EC2_USER@$EC2_IP" "
    cd $APP_DIR &&
    if [ ! -f ~/db_credentials.txt ]; then
        DB_PASSWORD=\$(openssl rand -base64 32)
        echo \"Database password: \$DB_PASSWORD\" > ~/db_credentials.txt
        chmod 600 ~/db_credentials.txt
        
        mysql -u root -e \"
        CREATE DATABASE IF NOT EXISTS consoul_production CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
        CREATE USER IF NOT EXISTS 'consoul'@'localhost' IDENTIFIED BY '\$DB_PASSWORD';
        GRANT ALL PRIVILEGES ON consoul_production.* TO 'consoul'@'localhost';
        FLUSH PRIVILEGES;
        \"
    fi
"

log_info "Step 5: Environment configuration"
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$EC2_USER@$EC2_IP" "
    cd $APP_DIR &&
    if [ ! -f .env.production ]; then
        SECRET_KEY=\$(openssl rand -hex 64)
        DB_PASSWORD=\$(grep 'Database password:' ~/db_credentials.txt | cut -d' ' -f3)
        
        cat > .env.production << EOF
RAILS_ENV=production
SECRET_KEY_BASE=\$SECRET_KEY
CONSOUL_DATABASE_PASSWORD=\$DB_PASSWORD
REDIS_URL=redis://localhost:6379/0
EOF
        chmod 600 .env.production
    fi
"

log_info "Step 6: Database migration and assets compilation"
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$EC2_USER@$EC2_IP" "
    cd $APP_DIR &&
    export PATH=\"\$HOME/.rbenv/bin:\$PATH\" &&
    eval \"\$(rbenv init -)\" &&
    source .env.production &&
    bundle exec rails db:migrate &&
    bundle exec rails assets:precompile
"

log_info "Step 7: Restarting application services"
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$EC2_USER@$EC2_IP" "
    sudo systemctl restart consoul &&
    sleep 3 &&
    sudo systemctl status consoul
"

log_info "✅ Code deployment completed!"
echo ""
echo "Summary:"
echo "- Code uploaded to: $APP_DIR"
echo "- Environment: Production"
echo "- Database: Configured"
echo "- Assets: Compiled"
echo "- Service: Restarted"
echo ""
echo "Next steps:"
echo "1. Test the application: https://main.infra1205.xyz"
echo "2. Check logs if needed:"
echo "   - Application: tail -f $APP_DIR/log/production.log"
echo "   - Unicorn: tail -f $APP_DIR/log/unicorn.stderr.log"
echo "   - System: sudo journalctl -u consoul -f"

# Cleanup
rm -f /tmp/consoul-app.tar.gz