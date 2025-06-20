class Room < ApplicationRecord
  # =====================================
  # アソシエーション
  # =====================================
  belongs_to :user1, class_name: 'User'
  belongs_to :user2, class_name: 'User'

  # =====================================
  # バリデーション
  # =====================================
  validates :title, presence: true, length: { maximum: 100 }
  validates :status, inclusion: { in: %w[waiting active paused completed] }
  validates :timer_seconds, numericality: { greater_than_or_equal_to: 0 }
  validates :heart_count, numericality: { greater_than_or_equal_to: 0 }
  validate :users_must_be_different
  validate :users_must_be_paired

  # =====================================
  # スコープ
  # =====================================
  scope :active, -> { where(status: 'active') }
  scope :for_user, ->(user) { where('user1_id = ? OR user2_id = ?', user.id, user.id) }
  scope :recent, -> { order(created_at: :desc) }
  scope :stale, -> { 
    where(status: 'active')
    .where('last_activity_at < ?', 3.minutes.ago) 
  }

  # =====================================
  # パブリックメソッド
  # =====================================

  # ルームの参加者を取得
  def participants
    [user1, user2]
  end

  # 指定されたユーザーがこのルームの参加者かどうか
  def participant?(user)
    user1 == user || user2 == user
  end

  # 相手のユーザーを取得
  def partner_for(user)
    return user2 if user1 == user
    return user1 if user2 == user
    nil
  end

  # ルームを開始
  def start!
    return false unless status == 'waiting'
    
    update!(
      status: 'active',
      started_at: Time.current,
      last_activity_at: Time.current
    )
  end

  # ルームを完了
  def complete!
    return false unless %w[active paused].include?(status)
    
    # タイマーが動いている場合は停止
    pause_timer! if timer_running?
    
    update!(
      status: 'completed',
      ended_at: Time.current
    )
  end

  # 現在の経過時間を取得（秒）
  def current_elapsed_seconds
    return timer_seconds unless timer_running?
    return timer_seconds unless timer_started_at
    
    timer_seconds + (Time.current - timer_started_at).to_i
  end

  # タイマーを開始
  def start_timer!
    return false if timer_running?
    
    update!(
      timer_running: true,
      timer_started_at: Time.current,
      last_activity_at: Time.current
    )
  end

  # タイマーを一時停止
  def pause_timer!
    return false unless timer_running?
    
    transaction do
      current_time = Time.current
      elapsed = timer_seconds + (current_time - timer_started_at).to_i
      
      update!(
        timer_seconds: elapsed,
        timer_running: false,
        timer_started_at: nil,
        last_activity_at: current_time
      )
    end
  end

  # ハートを追加
  def add_hearts(count = 1)
    increment!(:heart_count, count)
    touch(:last_activity_at)
  end

  # ルームの経過時間を文字列で取得
  def elapsed_time_formatted
    seconds = current_elapsed_seconds
    minutes = seconds / 60
    remaining_seconds = seconds % 60
    format('%02d:%02d', minutes, remaining_seconds)
  end

  # ルームがアクティブかどうか
  def active?
    status == 'active'
  end

  # ルームが完了しているかどうか
  def completed?
    status == 'completed'
  end

  # ユーザーアクティビティを記録
  def update_activity!
    touch(:last_activity_at)
  end

  # ルームが非アクティブ（3分間活動なし）かどうか
  def stale?
    return false unless last_activity_at
    last_activity_at < 3.minutes.ago
  end

  # 非アクティブなルームを自動完了
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

  private

  # user1とuser2が異なることを確認
  def users_must_be_different
    if user1_id.present? && user2_id.present? && user1_id == user2_id
      errors.add(:user2, "同じユーザーを指定することはできません")
    end
  end

  # user1とuser2がペアになっていることを確認
  def users_must_be_paired
    return unless user1&.persisted? && user2&.persisted?
    
    unless user1.partner == user2
      errors.add(:base, "ルームを作成できるのはペアになっているユーザーのみです")
    end
  end
end
