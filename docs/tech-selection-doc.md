# 技術選定書：RRFull (Rails + Stimulus版)

## 技術スタック概要

Rails 7のフルスタック構成を採用し、Stimulus.jsで動的な要素を実装します。WebSocketは使用せず、Ajaxポーリングによる準リアルタイム通信を実現します。

---

## フロントエンド

### コア技術
- **フレームワーク**: Ruby on Rails 7.0+ (ERB テンプレート)
- **JavaScript**: Stimulus.js 3.2+
- **CSS**: Tailwind CSS 3.0 (CDN版)
- **通信**: Fetch API (Ajaxポーリング)

### JavaScriptライブラリ
```javascript
// importmap設定
- stimulus: 3.2.2
- turbo: 7.3.0
- @hotwired/stimulus-loading: 2.0.0
```

### UI/UXライブラリ
- **アイコン**: Font Awesome 6 (CDN)
- **アニメーション**: CSS Transitions
- **日付処理**: なし（サーバーサイドで処理）

---

## バックエンド

### Ruby on Rails構成
- **バージョン**: Rails 7.0.8
- **Ruby**: 3.2.0
- **テンプレート**: ERB
- **APIモード**: 不使用（フルスタック）

### 主要Gem
```ruby
# Gemfile
gem 'rails', '~> 7.0.8'
gem 'pg', '~> 1.5'  # PostgreSQL
gem 'puma', '~> 6.0'
gem 'devise', '~> 4.9'  # 認証
gem 'stimulus-rails', '~> 1.3'
gem 'turbo-rails', '~> 1.5'
gem 'importmap-rails', '~> 1.2'
gem 'redis', '~> 5.0'  # セッション管理

# 開発環境
group :development do
  gem 'web-console'
  gem 'debug'
  gem 'spring'
end

# テスト
group :test do
  gem 'rspec-rails', '~> 6.0'
  gem 'factory_bot_rails'
  gem 'faker'
end
```

### セッション管理
- **ストア**: Redis (メモリ上でセッション状態を管理)
- **有効期限**: 60分
- **同時接続**: 2名/セッション

---

## インフラストラクチャ

### 開発環境
- **OS**: macOS / Windows WSL2 / Linux
- **Dockerオプション**: docker-compose.yml提供
- **必要なサービス**:
  - PostgreSQL 15
  - Redis 7.0

### 本番環境（推奨）
- **PaaS**: Heroku または Render.com
- **アプリサーバー**: Puma (Workers: 2, Threads: 5)
- **DB**: PostgreSQL (Heroku Postgres)
- **Redis**: Heroku Redis または Redis Cloud
- **SSL**: Let's Encrypt (自動)

### 代替インフラ（AWS）
- **EC2**: t3.small
- **RDS**: PostgreSQL
- **ElastiCache**: Redis
- **ALB**: HTTPS終端

---

## セキュリティ

### 認証・認可
- **認証**: Devise (セッション認証)
- **CSRF対策**: Rails標準
- **セッションストア**: Redis (HttpOnly Cookie)

### 通信セキュリティ
- **HTTPS**: 必須（本番環境）
- **CORS**: 不要（同一オリジン）
- **Rate Limiting**: Rack::Attack

### データ保護
- **暗号化**: Rails Credentials
- **パスワード**: bcrypt
- **個人情報**: 最小限の保持

---

## パフォーマンス最適化

### フロントエンド最適化
```javascript
// Stimulusコントローラーの最適化例
export default class extends Controller {
  static values = { 
    url: String,
    interval: { type: Number, default: 500 }
  }
  
  connect() {
    // デバウンス処理
    this.poll = debounce(this.fetchStatus.bind(this), 100)
    this.startPolling()
  }
  
  disconnect() {
    // メモリリーク対策
    if (this.timer) clearInterval(this.timer)
  }
}
```

### バックエンド最適化
- **クエリ最適化**: includes, eager_load
- **キャッシング**: Rails.cache (Redis)
- **インデックス**: 適切な設定

### 通信最適化
- **圧縮**: gzip/brotli
- **最小ペイロード**: 必要なデータのみ
- **条件付きGET**: ETag/Last-Modified

---

## 開発環境セットアップ

### 必要なツール
```bash
# バージョン管理
- Git 2.40+
- GitHub

# Ruby環境
- rbenv または rvm
- Ruby 3.2.0
- Bundler 2.4+

# Node.js (Stimulus用)
- Node.js 18+ (または fnm/nvm)
- Yarn 1.22+ (オプション)

# データベース
- PostgreSQL 15
- Redis 7.0
```

### 初期セットアップコマンド
```bash
# リポジトリクローン
git clone [repository]
cd rrfull

# Ruby依存関係
bundle install

# データベース作成
rails db:create db:migrate db:seed

# Redis起動
redis-server

# 開発サーバー起動
rails s
```

---

## テスト戦略

### テストの種類
- **単体テスト**: RSpec (Model, Controller)
- **統合テスト**: System Spec (Capybara)
- **JavaScript**: Stimulus Test

### カバレッジ目標
- **Model**: 90%以上
- **Controller**: 80%以上
- **System**: 主要フロー

### CI/CD
```yaml
# .github/workflows/ci.yml
- Rubocopによるコード品質チェック
- RSpecテスト実行
- SimpleCovでカバレッジ測定
```

---

## 監視・ログ

### アプリケーション監視
- **APM**: New Relic Free または Scout APM
- **エラー追跡**: Rollbar Free
- **ログ**: Rails Logger → CloudWatch

### パフォーマンス監視
- **レスポンスタイム**: < 300ms目標
- **ポーリング成功率**: 99%以上
- **同時接続数**: リアルタイム監視

---

## 技術選定の理由

### なぜStimulus.js？
1. **学習曲線が緩やか**: HTMLに近い記述
2. **Rails統合**: Turboとの相性が良い
3. **軽量**: 小規模アプリに最適
4. **段階的導入**: 部分的に高度な実装へ移行可能

### なぜポーリング？
1. **実装がシンプル**: WebSocketより簡単
2. **デバッグしやすい**: 通常のHTTPリクエスト
3. **スケーラブル**: ステートレス
4. **十分な性能**: 0.5秒遅延で要件を満たす

### 将来の拡張性
- Stimulusコントローラーの追加で機能拡張
- 必要に応じてReactへの部分移行
- Action Cableへのアップグレードパス確保