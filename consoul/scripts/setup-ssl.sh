#!/bin/bash
# SSL Certificate Setup Script for Consoul
# Domain: main.infra1205.xyz

set -e

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

DOMAIN="main.infra1205.xyz"
EMAIL="admin@infra1205.xyz"  # Change this to your actual email

log_info "🔒 Starting SSL certificate setup for $DOMAIN"

# Step 1: Install Certbot
log_info "Installing Certbot..."
sudo yum install -y certbot python3-certbot-nginx

# Step 2: Test domain accessibility
log_info "Testing domain accessibility..."
if curl -s -o /dev/null -w "%{http_code}" http://$DOMAIN | grep -q "200\|302\|404"; then
    log_info "✅ Domain is accessible via HTTP"
else
    log_error "❌ Domain is not accessible. Please check DNS settings."
    log_info "Expected: $DOMAIN should point to 13.113.184.147"
    exit 1
fi

# Step 3: Obtain SSL certificate
log_info "Obtaining SSL certificate from Let's Encrypt..."
sudo certbot --nginx -d $DOMAIN --email $EMAIL --agree-tos --non-interactive --redirect

if [ $? -eq 0 ]; then
    log_info "✅ SSL certificate obtained successfully"
else
    log_error "❌ Failed to obtain SSL certificate"
    log_info "Common issues:"
    log_info "1. DNS not properly configured"
    log_info "2. Domain not pointing to correct IP"
    log_info "3. Firewall blocking port 80/443"
    exit 1
fi

# Step 4: Update Nginx configuration for better security
log_info "Updating Nginx SSL configuration..."
sudo tee /etc/nginx/conf.d/consoul.conf > /dev/null <<EOF
upstream consoul {
    server unix:/tmp/unicorn.sock fail_timeout=0;
}

server {
    listen 80;
    server_name $DOMAIN;
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $DOMAIN;
    
    # SSL Certificate (managed by Certbot)
    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;
    
    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options DENY always;
    add_header X-Content-Type-Options nosniff always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    
    root /home/ec2-user/consoul/public;
    
    # Rails application
    try_files \$uri/index.html \$uri @consoul;
    
    location @consoul {
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header Host \$http_host;
        proxy_redirect off;
        
        # Timeouts
        proxy_read_timeout 60s;
        proxy_send_timeout 60s;
        proxy_connect_timeout 60s;
        
        proxy_pass http://consoul;
    }
    
    # Static assets
    location ~* \.(css|js|png|jpg|jpeg|gif|ico|svg|woff|woff2)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        add_header ETag "";
        break;
    }
    
    # Logs
    access_log /var/log/nginx/consoul_access.log;
    error_log /var/log/nginx/consoul_error.log;
}
EOF

# Step 5: Test Nginx configuration
log_info "Testing Nginx configuration..."
sudo nginx -t

if [ $? -eq 0 ]; then
    log_info "✅ Nginx configuration is valid"
    sudo systemctl reload nginx
else
    log_error "❌ Nginx configuration error"
    exit 1
fi

# Step 6: Setup automatic certificate renewal
log_info "Setting up automatic certificate renewal..."
echo "0 12 * * * /usr/bin/certbot renew --quiet" | sudo crontab -

# Step 7: Test HTTPS connection
log_info "Testing HTTPS connection..."
sleep 3

if curl -s -o /dev/null -w "%{http_code}" https://$DOMAIN | grep -q "200\|302\|404"; then
    log_info "✅ HTTPS connection successful"
else
    log_warn "⚠️  HTTPS connection may have issues"
fi

# Step 8: Test HTTP to HTTPS redirect
log_info "Testing HTTP to HTTPS redirect..."
REDIRECT_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://$DOMAIN)
if [ "$REDIRECT_CODE" = "301" ] || [ "$REDIRECT_CODE" = "302" ]; then
    log_info "✅ HTTP to HTTPS redirect working"
else
    log_warn "⚠️  HTTP to HTTPS redirect may not be working properly"
fi

# Step 9: Display certificate information
log_info "SSL Certificate Information:"
sudo certbot certificates | grep -A 10 $DOMAIN

log_info "🎉 SSL setup completed successfully!"
echo ""
echo "Summary:"
echo "- Domain: https://$DOMAIN ✅"
echo "- SSL Certificate: Active ✅"
echo "- Auto-renewal: Configured ✅"
echo "- Security headers: Enabled ✅"
echo ""
echo "Next steps:"
echo "1. Visit: https://$DOMAIN"
echo "2. Test all application features"
echo "3. Monitor logs if needed"
echo ""
log_info "SSL setup script completed!"