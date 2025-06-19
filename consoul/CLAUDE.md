# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## プロジェクト概要

Consoulは、ペアとなった2人のユーザーがスマホで感情や活動をリアルタイムで共有できるシンプルなRails + Stimulusアプリです。複雑なWebSocketは使わず、0.5秒間隔のAjaxポーリングで実現します。

**設計思想**: 学習しやすさを重視。複雑な仕組みより、読みやすいコードを優先する。

## 技術スタック

### 開発環境
- **Rails 7.2.2** - フルスタック構成
- **Ruby 3.2.0** - rbenv管理
- **MySQL** - 開発用データベース
- **Puma** - Rails標準アプリサーバー
- **Redis** - セッション・キャッシュ
- **Stimulus.js** - シンプルなJavaScript
- **Tailwind CSS** - CDN経由（ビルド不要）

### 本番環境（AWS EC2 t2.micro）
- **MariaDB 10.5+** - 軽量設定
- **Unicorn** - 1ワーカープロセス（メモリ効率重視）
- **Nginx** - リバースプロキシ
- **Redis 7.0** - メモリ制限あり
- **Amazon Linux 2** - t2.micro EC2

## AWS t2.micro制約

### リソース制限
- **メモリ**: 1GB RAM（厳しい制約）
- **CPU**: 1vCPU（バースト可能）
- **同時接続**: 10-20セッション推奨
- **Unicorn**: 1ワーカーのみ

### 最適化設定
```ruby
# config/unicorn.rb
worker_processes 1
timeout 60
preload_app true
listen "/tmp/unicorn.sock"
```

```bash
# MariaDB軽量設定
innodb_buffer_pool_size = 128M
max_connections = 50

# Redis軽量設定
maxmemory 100mb
maxmemory-policy allkeys-lru
```

## 開発コマンド

```bash
# セットアップ
bundle install
rails db:create db:migrate db:seed
redis-server &  # バックグラウンド実行

# 開発サーバー
rails s

# テスト実行
bundle exec rspec

# コード品質チェック
bundle exec rubocop -A
```

## ペアシステムの仕組み

### ペア作成（最もシンプルな方法）
1. **ユーザー登録時**: 相手のメールアドレスを入力
2. **ペア成立**: お互いが相手のメールを入力すると自動でペア成立
3. **セッション作成**: ペアになった2人だけがセッションを作成可能

### 実装済みのUserモデル機能
```ruby
# ペア関係の確認
user.paired?  # => true/false

# パートナーの取得
user.partner  # => User or nil

# 相互ペアの作成
user.create_mutual_pair_with(other_user)  # => true/false

# ペア関係の解消
user.unpair!
```

### バリデーション
- 自分自身をペアに設定できない
- メールアドレス・パスワード必須（Devise標準）

## 主要機能（今後実装予定）

### リアルタイム機能
1. **タイマー** - 2人で開始・停止を同期
2. **感情表示** - 5種類の絵文字、お互いの選択が見える
3. **ハートカウンター** - タップしてハートを追加
4. **接続状態** - パートナーがオンラインかわかる

### 画面フロー
1. **ログイン後** → セッション一覧ページ
2. **セッション一覧** → タイトル付きセッションリスト + 新規作成
3. **セッション作成** → タイトル入力のみ
4. **セッション参加** → 一覧からクリックで参加

## 現在のファイル構成

```
app/
├── models/
│   └── user.rb                 # Deviseユーザー + ペア機能（実装済み）
├── controllers/
│   └── application_controller.rb
└── views/
    └── layouts/
        └── application.html.erb

spec/
├── models/
│   └── user_spec.rb            # Userモデルのテスト（20個、全て成功）
├── spec_helper.rb
└── rails_helper.rb

db/
└── migrate/
    ├── *_devise_create_users.rb
    └── *_add_pair_user_to_users.rb
```

## テスト実行

```bash
# 全テスト実行
bundle exec rspec

# Userモデルのテストのみ
bundle exec rspec spec/models/user_spec.rb
```

現在、20個のテストケースが全て成功しています。

## 次の実装予定

1. **Sessionモデル**
   - ペア専用のセッション管理
   - タイトル付きセッション
   - 状態管理（waiting, active, completed）

2. **画面実装**
   - Devise認証画面のカスタマイズ
   - セッション一覧画面
   - セッション詳細画面

3. **Stimulusコントローラー**
   - ポーリング機能
   - タイマー同期
   - 感情状態の共有

## コーディング指針

### Railsコード
- わかりやすいメソッド名を使う
- ビューに複雑なロジックを書かない
- コントローラーは薄く、ロジックはモデルに
- テストを書いてから実装する

### テスト
- RSpecでモデル・コントローラーをテスト
- 日本語でdescribeを書いて読みやすく
- 境界値のテストを含める
- エッジケースも考慮する

## デプロイ準備（今後）

### 本番環境用設定
```ruby
# config/environments/production.rb
config.force_ssl = true
config.cache_classes = true
config.eager_load = true

# config/unicorn.rb（作成予定）
worker_processes 1
timeout 60
preload_app true
```

### 環境変数
```bash
RAILS_ENV=production
SECRET_KEY_BASE=xxx
DATABASE_PASSWORD=xxx
REDIS_URL=redis://localhost:6379
```