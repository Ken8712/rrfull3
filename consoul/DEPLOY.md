# Consoul デプロイガイド

## 概要

ConsoulアプリケーションをAWS EC2 t2.microインスタンスにデプロイするための完全ガイド。

## 前提条件

- **AWS EC2**: t2.micro (Amazon Linux 2)
- **RAM**: 1GB (厳しい制約)
- **CPU**: 1vCPU (バースト可能)
- **推奨同時接続**: 10-20ルーム

## システム構成

```
[Nginx] -> [Unicorn] -> [Rails App]
                    \-> [MariaDB]
                    \-> [Redis]
```

## 1. サーバー環境準備

### 1.1 基本パッケージインストール

```bash
# システム更新
sudo yum update -y

# 開発ツール
sudo yum groupinstall -y "Development Tools"
sudo yum install -y git curl wget

# Ruby依存関係
sudo yum install -y openssl-devel readline-devel zlib-devel
```

### 1.2 Ruby環境構築

```bash
# rbenv インストール
git clone https://github.com/rbenv/rbenv.git ~/.rbenv
echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
echo 'eval "$(rbenv init -)"' >> ~/.bashrc
source ~/.bashrc

# ruby-build インストール
git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build

# Ruby 3.2.0 インストール
rbenv install 3.2.0
rbenv global 3.2.0
rbenv rehash

# Bundler インストール
gem install bundler
```

### 1.3 MariaDB セットアップ

```bash
# MariaDB インストール
sudo yum install -y mariadb-server mariadb-devel

# MariaDB 起動・自動起動設定
sudo systemctl start mariadb
sudo systemctl enable mariadb

# セキュリティ設定
sudo mysql_secure_installation
```

#### MariaDB 軽量設定 (t2.micro用)

`/etc/my.cnf.d/server.cnf` に追加:

```ini
[mysqld]
# t2.micro メモリ最適化
innodb_buffer_pool_size = 128M
innodb_log_file_size = 32M
innodb_log_buffer_size = 8M

# 接続制限
max_connections = 50
table_open_cache = 256

# クエリキャッシュ
query_cache_type = 1
query_cache_size = 32M

# その他の最適化
tmp_table_size = 32M
max_heap_table_size = 32M
```

#### データベース・ユーザー作成

```sql
-- MariaDB にログイン
mysql -u root -p

-- データベース作成
CREATE DATABASE consoul_production CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- ユーザー作成
CREATE USER 'consoul'@'localhost' IDENTIFIED BY 'your_secure_password';
GRANT ALL PRIVILEGES ON consoul_production.* TO 'consoul'@'localhost';
FLUSH PRIVILEGES;
EXIT;
```

### 1.4 Redis セットアップ

```bash
# Redis インストール
sudo yum install -y redis

# Redis 軽量設定
sudo vim /etc/redis.conf
```

Redis設定 (`/etc/redis.conf`):

```conf
# t2.micro メモリ制限
maxmemory 100mb
maxmemory-policy allkeys-lru

# 永続化無効化（メモリ重視）
save ""

# ログレベル
loglevel notice

# バックグラウンド実行
daemonize yes
```

```bash
# Redis 起動・自動起動設定
sudo systemctl start redis
sudo systemctl enable redis
```

### 1.5 Nginx セットアップ

```bash
# Nginx インストール
sudo amazon-linux-extras install -y nginx1

# Nginx 設定
sudo vim /etc/nginx/conf.d/consoul.conf
```

Nginx設定 (`/etc/nginx/conf.d/consoul.conf`):

```nginx
upstream consoul {
    server unix:/tmp/unicorn.sock fail_timeout=0;
}

server {
    listen 80;
    server_name your-domain.com;  # 実際のドメインに変更
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name your-domain.com;  # 実際のドメインに変更
    
    # SSL証明書 (Let's Encrypt等で取得)
    ssl_certificate /path/to/certificate.crt;
    ssl_certificate_key /path/to/private.key;
    
    # SSL設定
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    
    root /home/ec2-user/consoul/public;
    
    # Unicorn upstream
    try_files $uri/index.html $uri @consoul;
    
    location @consoul {
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Host $http_host;
        proxy_redirect off;
        
        # タイムアウト設定
        proxy_read_timeout 60s;
        proxy_send_timeout 60s;
        
        proxy_pass http://consoul;
    }
    
    # 静的ファイル配信
    location ~* \.(css|js|png|jpg|jpeg|gif|ico|svg)$ {
        expires 1y;
        add_header Cache-Control public;
        add_header ETag "";
        break;
    }
    
    # アクセスログ
    access_log /var/log/nginx/consoul_access.log;
    error_log /var/log/nginx/consoul_error.log;
}
```

```bash
# Nginx 起動・自動起動設定
sudo systemctl start nginx
sudo systemctl enable nginx
```

## 2. アプリケーションデプロイ

### 2.1 コード取得

```bash
# アプリケーションディレクトリ作成
cd /home/ec2-user
git clone https://github.com/your-username/consoul.git
cd consoul
```

### 2.2 環境変数設定

```bash
# 環境変数ファイル作成
vim .env.production
```

`.env.production` の内容:

```bash
RAILS_ENV=production
SECRET_KEY_BASE=your_secret_key_base_here
CONSOUL_DATABASE_PASSWORD=your_database_password_here
REDIS_URL=redis://localhost:6379/0
```

SECRET_KEY_BASE生成:

```bash
cd /home/ec2-user/consoul
bundle exec rails secret
```

### 2.3 依存関係インストール

```bash
# Gemインストール
bundle config set --local deployment 'true'
bundle config set --local without 'development test'
bundle install
```

### 2.4 データベース準備

```bash
# データベースマイグレーション
RAILS_ENV=production bundle exec rails db:migrate

# 初期データ投入（必要に応じて）
RAILS_ENV=production bundle exec rails db:seed
```

### 2.5 アセットプリコンパイル

```bash
# アセット生成
RAILS_ENV=production bundle exec rails assets:precompile
```

### 2.6 ログディレクトリ作成

```bash
# ログディレクトリ準備
mkdir -p log
touch log/production.log
touch log/unicorn.stderr.log
touch log/unicorn.stdout.log
```

## 3. Unicorn設定

Unicorn設定ファイル (`config/unicorn.rb`) - 既に作成済み:

```ruby
# Unicorn configuration for AWS t2.micro (1GB RAM)

# Single worker process to minimize memory usage
worker_processes 1

# Timeout settings
timeout 60

# Application root
APP_ROOT = File.expand_path('..', __dir__)
working_directory APP_ROOT

# Socket for Nginx communication
listen "/tmp/unicorn.sock", backlog: 64

# Process IDs
pid "/tmp/unicorn.pid"

# Stderr and stdout logs
stderr_path "#{APP_ROOT}/log/unicorn.stderr.log"
stdout_path "#{APP_ROOT}/log/unicorn.stdout.log"

# Preload application for memory efficiency
preload_app true

# GC settings for t2.micro
GC.respond_to?(:copy_on_write_friendly=) && GC.copy_on_write_friendly = true

# Restart worker if memory usage exceeds 200MB
check_client_connection false

before_fork do |server, worker|
  # Disconnect from database before forking
  defined?(ActiveRecord::Base) && ActiveRecord::Base.connection.disconnect!

  # Kill old master if exists
  old_pid = "#{server.config[:pid]}.oldbin"
  if old_pid != server.pid
    begin
      sig = (worker.nr + 1) >= server.worker_processes ? :QUIT : :TTOU
      Process.kill(sig, File.read(old_pid).to_i)
    rescue Errno::ENOENT, Errno::ESRCH
    end
  end
end

after_fork do |server, worker|
  # Reconnect to database after forking
  defined?(ActiveRecord::Base) && ActiveRecord::Base.establish_connection
end
```

## 4. 本番環境起動

### 4.1 Unicorn起動

```bash
# 本番環境でUnicorn起動
cd /home/ec2-user/consoul
source .env.production
bundle exec unicorn -c config/unicorn.rb -E production -D
```

### 4.2 起動確認

```bash
# プロセス確認
ps aux | grep unicorn

# ソケットファイル確認
ls -la /tmp/unicorn.sock

# ログ確認
tail -f log/unicorn.stderr.log
tail -f log/production.log
```

### 4.3 Nginx再起動

```bash
# Nginx設定テスト
sudo nginx -t

# Nginx再起動
sudo systemctl restart nginx
```

## 5. システム管理

### 5.1 Systemdサービス作成

`/etc/systemd/system/consoul.service`:

```ini
[Unit]
Description=Consoul Unicorn Server
After=network.target

[Service]
Type=forking
User=ec2-user
WorkingDirectory=/home/ec2-user/consoul
Environment=RAILS_ENV=production
EnvironmentFile=/home/ec2-user/consoul/.env.production
ExecStart=/home/ec2-user/.rbenv/shims/bundle exec unicorn -c config/unicorn.rb -E production -D
ExecReload=/bin/kill -USR2 $MAINPID
KillMode=mixed
TimeoutStopSec=5
PrivateTmp=true

[Install]
WantedBy=multi-user.target
```

サービス有効化:

```bash
sudo systemctl daemon-reload
sudo systemctl enable consoul
sudo systemctl start consoul
```

### 5.2 デプロイスクリプト

`scripts/deploy.sh`:

```bash
#!/bin/bash
set -e

echo "Starting deployment..."

# アプリケーションディレクトリに移動
cd /home/ec2-user/consoul

# 最新コードを取得
git pull origin main

# 依存関係更新
bundle install --deployment --without development test

# データベースマイグレーション
RAILS_ENV=production bundle exec rails db:migrate

# アセットプリコンパイル
RAILS_ENV=production bundle exec rails assets:precompile

# Unicorn再起動（ゼロダウンタイム）
if [ -f /tmp/unicorn.pid ]; then
    kill -USR2 $(cat /tmp/unicorn.pid)
    sleep 5
    kill -QUIT $(cat /tmp/unicorn.pid.oldbin)
else
    sudo systemctl restart consoul
fi

echo "Deployment completed successfully!"
```

### 5.3 監視・メンテナンス

#### ログローテーション

`/etc/logrotate.d/consoul`:

```
/home/ec2-user/consoul/log/*.log {
    daily
    missingok
    rotate 52
    compress
    delaycompress
    notifempty
    create 644 ec2-user ec2-user
    postrotate
        kill -USR1 $(cat /tmp/unicorn.pid) 2>/dev/null || true
    endscript
}
```

#### メモリ監視

```bash
# メモリ使用量確認
free -h
ps aux --sort=-%mem | head -10

# Unicornプロセス確認
ps aux | grep unicorn
```

## 6. SSL証明書設定 (Let's Encrypt)

```bash
# Certbot インストール
sudo yum install -y certbot python3-certbot-nginx

# SSL証明書取得
sudo certbot --nginx -d your-domain.com

# 自動更新設定
sudo crontab -e
# 以下を追加
0 12 * * * /usr/bin/certbot renew --quiet
```

## 7. トラブルシューティング

### 7.1 よくある問題

#### メモリ不足

```bash
# スワップ作成（緊急時のみ）
sudo fallocate -l 1G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

#### Unicorn起動失敗

```bash
# ログ確認
tail -n 50 log/unicorn.stderr.log
tail -n 50 log/production.log

# ソケットファイル削除
rm -f /tmp/unicorn.sock /tmp/unicorn.pid

# 手動起動
RAILS_ENV=production bundle exec unicorn -c config/unicorn.rb
```

#### データベース接続エラー

```bash
# MariaDB サービス確認
sudo systemctl status mariadb

# 接続テスト
mysql -u consoul -p consoul_production
```

### 7.2 パフォーマンス監視

```bash
# CPU・メモリ使用率
top
htop

# ディスク容量
df -h

# ネットワーク接続
netstat -tuln

# Nginxステータス
curl http://localhost/nginx_status
```

## 8. セキュリティ対策

### 8.1 ファイアウォール設定

```bash
# ポート開放
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --reload
```

### 8.2 定期バックアップ

```bash
# データベースバックアップスクリプト
#!/bin/bash
BACKUP_DIR="/home/ec2-user/backups"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

# データベースバックアップ
mysqldump -u consoul -p consoul_production > $BACKUP_DIR/consoul_$DATE.sql

# 古いバックアップ削除（7日以上前）
find $BACKUP_DIR -name "*.sql" -mtime +7 -delete
```

## 9. デプロイチェックリスト

- [ ] Ruby 3.2.0 インストール済み
- [ ] MariaDB セットアップ完了
- [ ] Redis セットアップ完了
- [ ] Nginx セットアップ完了
- [ ] SSL証明書設定完了
- [ ] 環境変数設定完了
- [ ] データベースマイグレーション完了
- [ ] アセットプリコンパイル完了
- [ ] Unicorn起動確認
- [ ] Systemdサービス登録完了
- [ ] ログローテーション設定完了
- [ ] 監視設定完了
- [ ] バックアップ設定完了

## 10. 運用コマンド一覧

```bash
# アプリケーション操作
sudo systemctl start consoul      # 起動
sudo systemctl stop consoul       # 停止
sudo systemctl restart consoul    # 再起動
sudo systemctl status consoul     # ステータス確認

# ログ確認
tail -f log/production.log         # アプリログ
tail -f log/unicorn.stderr.log    # Unicornエラーログ
sudo tail -f /var/log/nginx/consoul_access.log  # Nginxアクセスログ

# デプロイ
./scripts/deploy.sh               # デプロイ実行

# メンテナンス
RAILS_ENV=production bundle exec rails console  # Railsコンソール
RAILS_ENV=production bundle exec rails db:migrate  # マイグレーション
```

---

このガイドに従って、AWS EC2 t2.microでのConsoulアプリケーションデプロイを実行してください。