# Consoul デプロイメントガイド

## 概要

AWS EC2 (Amazon Linux 2) へのConsoulアプリケーションのデプロイ手順です。

## 前提条件

- AWS EC2インスタンス (t2.micro以上推奨)
- Amazon Linux 2 AMI
- セキュリティグループで以下のポートを開放
  - SSH (22)
  - HTTP (80)
  - HTTPS (443)

## デプロイ手順

### 1. EC2インスタンスへSSH接続

```bash
ssh -i your-key.pem ec2-user@your-ec2-ip
```

### 2. EC2環境セットアップ

```bash
# セットアップスクリプトをダウンロードして実行
curl -sSL https://raw.githubusercontent.com/your-username/consoul/main/scripts/ec2-setup.sh -o ec2-setup.sh
chmod +x ec2-setup.sh
./ec2-setup.sh
```

このスクリプトは以下をインストール・設定します：
- Ruby 3.2.0 (rbenv経由)
- MariaDB
- Redis 6
- Nginx
- Node.js

### 3. アプリケーションのクローン

```bash
cd /var/www
git clone https://github.com/your-username/consoul.git
cd consoul
```

### 4. 環境変数の設定

```bash
cp .env.example .env
nano .env  # または vim .env
```

以下の環境変数を設定してください：

| 環境変数 | 説明 | 例 |
|---------|------|-----|
| `RAILS_ENV` | Rails環境 | `production` |
| `SECRET_KEY_BASE` | Rails秘密鍵 | `rails secret`で生成 |
| `DATABASE_HOST` | データベースホスト | `localhost` |
| `DATABASE_PORT` | データベースポート | `3306` |
| `DATABASE_NAME` | データベース名 | `consoul_production` |
| `DATABASE_USERNAME` | データベースユーザー | `consoul` |
| `CONSOUL_DATABASE_PASSWORD` | データベースパスワード | 安全なパスワード |
| `DATABASE_SOCKET` | MySQLソケットパス | `/var/lib/mysql/mysql.sock` |
| `REDIS_URL` | Redis接続URL | `redis://localhost:6379/0` |
| `FORCE_SSL` | SSL強制 | `true` |

SECRET_KEY_BASEの生成：
```bash
cd /var/www/consoul
export PATH="$HOME/.rbenv/bin:$PATH"
eval "$(rbenv init -)"
bundle exec rails secret
```

### 5. アプリケーションセットアップ

```bash
./scripts/app-setup.sh
```

このスクリプトは以下を実行します：
- Ruby依存関係のインストール
- データベースの作成とマイグレーション
- アセットのプリコンパイル
- Unicornサービスの設定
- Nginxの設定

### 6. SSL証明書の設定（オプション）

ドメインを設定している場合：

```bash
sudo yum install -y certbot python3-certbot-nginx
sudo certbot --nginx -d yourdomain.com
```

## 管理コマンド

### アプリケーション管理

```bash
# 状態確認
sudo systemctl status consoul

# 起動
sudo systemctl start consoul

# 停止
sudo systemctl stop consoul

# 再起動
sudo systemctl restart consoul

# ログ確認
sudo journalctl -u consoul -f
```

### データベース操作

```bash
cd /var/www/consoul
source .env
bundle exec rails console  # Railsコンソール
bundle exec rails db:migrate  # マイグレーション実行
```

### デプロイ（更新）

```bash
cd /var/www/consoul
git pull origin main
bundle install
bundle exec rails db:migrate
bundle exec rails assets:precompile
sudo systemctl restart consoul
```

## トラブルシューティング

### Unicornが起動しない

```bash
# ログを確認
tail -f /var/www/consoul/log/unicorn.stderr.log
sudo journalctl -u consoul -n 100

# 手動で起動してエラーを確認
cd /var/www/consoul
source .env
bundle exec unicorn -c config/unicorn.rb
```

### データベース接続エラー

```bash
# MariaDBの状態確認
sudo systemctl status mariadb

# 接続テスト
mysql -u consoul -p$CONSOUL_DATABASE_PASSWORD consoul_production -e "SELECT 1;"
```

### アセットが表示されない

```bash
# アセットの再コンパイル
cd /var/www/consoul
bundle exec rails assets:clobber
bundle exec rails assets:precompile
sudo systemctl restart consoul
```

## セキュリティ注意事項

1. `.env`ファイルは絶対にGitにコミットしない
2. データベースパスワードは強固なものを使用
3. SECRET_KEY_BASEは必ず再生成する
4. 本番環境では必ずSSLを有効化する
5. 定期的にシステムをアップデートする

```bash
sudo yum update -y
```