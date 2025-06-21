# Consoul実装まとめ

## プロジェクト概要

Consoulは、ペアになった2人のユーザーがリアルタイムで感情や活動を共有できるRails + Stimulusアプリケーションです。WebSocketを使わず、シンプルなAjaxポーリングで実現しているため、学習しやすく、軽量な実装となっています。

## 技術スタック

- **バックエンド**: Ruby on Rails 7.2.2
- **フロントエンド**: Stimulus.js（Rails標準）
- **スタイリング**: Tailwind CSS（CDN版）
- **データベース**: MySQL/MariaDB
- **認証**: Devise

## 主要機能

### 1. ユーザーペアリングシステム

#### 概要
- ユーザー同士が1対1のペア関係を作成
- ペアになったユーザーのみがルームを作成可能

#### 実装詳細
```ruby
# app/models/user.rb
class User < ApplicationRecord
  belongs_to :pair_user, class_name: 'User', optional: true
  has_one :paired_with, class_name: 'User', foreign_key: :pair_user_id
  
  # 相互ペアを作成
  def create_mutual_pair_with(other_user)
    return false if other_user.nil? || other_user == self
    return false if paired? || other_user.paired?

    transaction do
      update!(pair_user: other_user)
      other_user.update!(pair_user: self)
    end
    true
  end
end
```

### 2. Roomシステム

#### 概要
ペアユーザー専用の共有空間で、以下の機能を提供：
- タイマー機能（開始・一時停止・再開）
- ハートカウンター
- 感情表示（5種類）
- 自動タイムアウト（3分間）

#### データベース設計
```ruby
# db/migrate/20250620075635_create_rooms.rb
create_table :rooms do |t|
  t.string :title, null: false
  t.string :status, null: false, default: 'waiting'  # waiting, active, paused, completed
  t.references :user1, null: false, foreign_key: { to_table: :users }
  t.references :user2, null: false, foreign_key: { to_table: :users }
  t.integer :timer_seconds, null: false, default: 0
  t.boolean :timer_running, null: false, default: false
  t.datetime :timer_started_at
  t.integer :heart_count, null: false, default: 0
  t.datetime :started_at
  t.datetime :ended_at
  t.datetime :last_activity_at
  t.string :user1_emotion
  t.string :user2_emotion
  t.timestamps
end
```

### 3. リアルタイム同期機能（詳細解説）

#### 同期の仕組み

リアルタイム同期は、以下の3つの要素で実現されています：

##### 1. Ajaxポーリング（0.5秒間隔）

```javascript
// app/javascript/controllers/room_controller.js
export default class extends Controller {
  static values = { 
    roomId: Number,
    pollingInterval: { type: Number, default: 500 }  // 500ms = 0.5秒
  }

  connect() {
    this.startPolling()
  }

  startPolling() {
    this.pollingTimer = setInterval(() => {
      this.fetchRoomStatus()  // 0.5秒ごとにサーバーに問い合わせ
    }, this.pollingIntervalValue)
  }
}
```

##### 2. サーバー側のステータス管理

```ruby
# app/controllers/rooms_controller.rb
def status
  render json: { room: room_status_data }
end

private

def room_status_data
  {
    id: @room.id,
    status: @room.status,
    timer_running: @room.timer_running?,
    elapsed_seconds: @room.current_elapsed_seconds,  # サーバー側で計算
    heart_count: @room.heart_count,
    user1_emotion: @room.user1_emotion,
    user2_emotion: @room.user2_emotion,
    # ... その他のデータ
  }
end
```

##### 3. クライアント側のリアルタイム更新

```javascript
// タイマーの同期処理
updateUI(roomData) {
  if (this.hasTimerTarget) {
    if (roomData.timer_running) {
      // タイマーが動いている場合、クライアント側で補間
      this.startClientTimer(roomData.elapsed_seconds)
    } else {
      // タイマーが停止している場合、サーバーの値をそのまま表示
      this.stopClientTimer()
      this.timerTarget.textContent = roomData.elapsed_time
    }
  }
}
```

#### タイマー同期の詳細

##### 問題と解決策

**問題**: 0.5秒間隔のポーリングでは、タイマーがカクカクして見える

**解決策**: クライアント側補間（Client-side Interpolation）

```javascript
startClientTimer(initialSeconds) {
  this.stopClientTimer()  // 既存のタイマーを停止
  
  this.clientStartTime = Date.now()
  this.serverElapsedSeconds = initialSeconds
  
  // 100ms間隔で更新（滑らかな表示）
  this.clientTimer = setInterval(() => {
    const clientElapsed = Math.floor((Date.now() - this.clientStartTime) / 1000)
    const totalSeconds = this.serverElapsedSeconds + clientElapsed
    const formatted = this.formatTime(totalSeconds)
    
    if (this.hasTimerTarget) {
      this.timerTarget.textContent = formatted
    }
  }, 100)
}
```

##### 同期フロー

1. **サーバーから初期値取得**（0.5秒ごと）
   - `elapsed_seconds: 125`（例：2分5秒）

2. **クライアント側で補間開始**
   - 現在時刻を記録
   - 100ms間隔でローカル計算

3. **次のポーリングで補正**
   - サーバーから新しい値を取得
   - クライアント側の計算をリセット
   - 新しい基準値から再計算

#### ハートカウンターのアニメーション同期

```javascript
// ハートカウント更新（アニメーション付き）
if (this.hasHeartCountTarget) {
  const currentCount = parseInt(this.heartCountTarget.textContent) || 0
  const newCount = roomData.heart_count
  
  if (newCount > currentCount) {
    // 増加時のみアニメーション
    this.animateHeartCount(currentCount, newCount)
  } else {
    this.heartCountTarget.textContent = newCount
  }
}

// イージング関数を使った滑らかなカウントアップ
animateHeartCount(from, to) {
  const duration = 500  // 0.5秒
  const startTime = Date.now()
  
  const animate = () => {
    const elapsed = Date.now() - startTime
    const progress = Math.min(elapsed / duration, 1)
    
    // ease-out効果（最初は速く、最後はゆっくり）
    const easeOut = 1 - Math.pow(1 - progress, 3)
    const currentValue = Math.round(from + (to - from) * easeOut)
    
    this.heartCountTarget.textContent = currentValue
    
    if (progress < 1) {
      requestAnimationFrame(animate)
    }
  }
  
  requestAnimationFrame(animate)
}
```

#### 感情表示の同期

```javascript
// 感情設定時の処理
async setEmotion(event) {
  const emotion = event.target.dataset.emotion
  
  // サーバーに送信
  const response = await fetch(`/rooms/${this.roomIdValue}/set_emotion`, {
    method: "PATCH",
    headers: {
      "Content-Type": "application/json",
      "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
    },
    body: JSON.stringify({ emotion: emotion })
  })
  
  const data = await response.json()
  
  if (data.success) {
    // UIを即座に更新（レスポンシブ）
    this.updateUI(data.room)
    // ボタンアニメーション
    this.animateEmotionButton(event.target)
  }
}
```

### 4. タイムアウト機能

#### 実装
```ruby
# app/models/room.rb
scope :stale, -> { 
  where(status: 'active')
  .where('last_activity_at < ?', 3.minutes.ago) 
}

def stale?
  return false unless last_activity_at
  last_activity_at < 3.minutes.ago
end

def auto_complete_if_stale!
  if status == 'active' && stale?
    update!(
      status: 'completed',
      ended_at: Time.current
    )
    true
  else
    false
  end
end
```

#### 自動チェック（バックグラウンドジョブで実装可能）
```ruby
# 定期的に実行されるジョブ（例）
Room.stale.find_each do |room|
  room.auto_complete_if_stale!
end
```

## セキュリティ実装

### 認証と認可

```ruby
# app/controllers/rooms_controller.rb
class RoomsController < ApplicationController
  before_action :authenticate_user!  # Devise認証
  before_action :ensure_participant  # ルーム参加者チェック

  private

  def ensure_participant
    unless @room.participant?(current_user)
      redirect_to root_path, alert: "このルームにアクセスする権限がありません。"
    end
  end
end
```

### CSRF対策

```javascript
// Ajax通信時のCSRFトークン送信
headers: {
  "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
}
```

## パフォーマンス最適化

### 1. データベースインデックス

```ruby
add_index :rooms, :status
add_index :rooms, [:user1_id, :user2_id]
add_index :rooms, :last_activity_at
```

### 2. クエリ最適化

```ruby
# N+1問題を避ける
scope :for_user, ->(user) { 
  where('user1_id = ? OR user2_id = ?', user.id, user.id) 
}
```

### 3. クライアント側の最適化

- 100ms間隔のタイマー更新（視覚的な滑らかさ）
- 0.5秒間隔のサーバーポーリング（負荷軽減）
- 差分更新のみ実行（不要なDOM更新を避ける）

## 今後の拡張可能性

1. **WebSocket対応**
   - Action Cableを使用したリアルタイム通信への移行

2. **プッシュ通知**
   - パートナーの活動をリアルタイムで通知

3. **データ分析**
   - 感情履歴の記録と可視化

4. **モバイルアプリ**
   - React NativeやFlutterでのネイティブアプリ開発

## まとめ

Consoulは、シンプルながら実用的なリアルタイム共有アプリケーションです。WebSocketを使わずにAjaxポーリングで実装することで、初学者にも理解しやすく、デプロイも簡単な設計となっています。

クライアント側の補間技術により、0.5秒間隔のポーリングでも滑らかなユーザー体験を実現しています。これは、リアルタイムアプリケーション開発の基本的なパターンを学ぶ良い例となるでしょう。