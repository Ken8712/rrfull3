# 01. 初期セットアップとペアシステム実装

## 概要

このドキュメントでは、Consoulアプリケーションの初期セットアップとペアシステムの実装について記録します。

## 実装日時
2025年1月19日

## 実装内容

### 1. Rails アプリケーションの作成

```bash
rails new consoul --database=mysql
```

- Rails 7.2.2を使用
- MySQLを開発用データベースとして設定
- Stimulusが自動的にセットアップされる

### 2. Gemfileの設定

#### 開発・テスト環境
```ruby
gem "redis", ">= 4.0.1"
gem "devise"

group :development, :test do
  gem "rspec-rails", "~> 6.0"
  gem "factory_bot_rails"
  gem "faker"
end
```

#### 本番環境（AWS EC2 t2.micro用）
```ruby
group :production do
  gem "unicorn"
end
```

### 3. Devise認証の設定

```bash
rails generate devise:install
rails generate devise User
```

標準的なDevise設定で、以下の機能を有効化：
- database_authenticatable
- registerable
- recoverable
- rememberable
- validatable

### 4. ペアシステムの実装

#### マイグレーション
```ruby
# add_pair_user_to_users.rb
class AddPairUserToUsers < ActiveRecord::Migration[7.2]
  def change
    add_reference :users, :pair_user, null: true, foreign_key: { to_table: :users }
  end
end
```

#### Userモデルの実装
```ruby
class User < ApplicationRecord
  # アソシエーション
  belongs_to :pair_user, class_name: 'User', optional: true
  has_one :paired_with, class_name: 'User', foreign_key: :pair_user_id
  
  # バリデーション
  validate :cannot_pair_with_self
  
  # ペア確認メソッド
  def paired?
    pair_user.present? || paired_with.present?
  end
  
  # パートナー取得
  def partner
    pair_user || paired_with
  end
  
  # ペア関係解消
  def unpair!
    if pair_user.present?
      pair_user.update!(pair_user: nil)
      update!(pair_user: nil)
    elsif paired_with.present?
      paired_with.update!(pair_user: nil)
    end
  end
  
  # 相互ペア作成
  def create_mutual_pair_with(other_user)
    return false if other_user.nil? || other_user == self
    return false if paired? || other_user.paired?
    
    transaction do
      update!(pair_user: other_user)
      other_user.update!(pair_user: self)
    end
    true
  rescue ActiveRecord::RecordInvalid
    false
  end
  
  private
  
  def cannot_pair_with_self
    if pair_user_id.present? && pair_user_id == id
      errors.add(:pair_user, "自分自身をペアに設定することはできません")
    end
  end
end
```

### 5. テストの実装

RSpecを使用して20個のテストケースを実装：

#### アソシエーションのテスト
- `belongs_to :pair_user` の確認
- `has_one :paired_with` の確認

#### Deviseバリデーションのテスト
- メールアドレス必須
- パスワード必須
- 有効な情報での作成

#### ペアシステムのテスト
- `paired?` メソッドの動作確認
- `partner` メソッドの動作確認
- `unpair!` メソッドの動作確認
- `create_mutual_pair_with` メソッドの動作確認
- 自己参照の防止

全てのテストが成功することを確認済み。

## 設計上の決定事項

### 1. シンプルなペア関係
- 各ユーザーは1人のペアのみ持てる
- `pair_user_id` を使った自己参照型の関連
- 相互参照も可能（A→B、B→A）

### 2. バリデーション
- 自分自身をペアに設定できない
- トランザクションで相互ペアの整合性を保証

### 3. 便利メソッド
- `paired?`: ペアの有無を確認
- `partner`: パートナーを取得（どちらの方向でも）
- `unpair!`: ペア関係を安全に解消
- `create_mutual_pair_with`: 相互ペアを一度に作成

## 今後の課題

1. **ペア登録フロー**
   - 登録時に相手のメールアドレスを入力
   - 相互確認でペア成立

2. **UI実装**
   - ペア状態の表示
   - ペア解消機能

3. **セッション管理**
   - ペア専用のセッション作成
   - セッション一覧の実装

## 学んだこと

1. **自己参照型アソシエーション**
   - `class_name` と `foreign_key` の指定方法
   - 双方向の関連の実装

2. **トランザクション処理**
   - 複数レコードの更新時の整合性確保
   - エラーハンドリング

3. **RSpecでのモデルテスト**
   - アソシエーションのテスト方法
   - 境界値テストの重要性

## 参考リンク

- [Rails Guides - Active Record Associations](https://guides.rubyonrails.org/association_basics.html)
- [Devise Documentation](https://github.com/heartcombo/devise)
- [RSpec Rails](https://github.com/rspec/rspec-rails)