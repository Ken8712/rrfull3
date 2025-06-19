class Session < ApplicationRecord
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

  # =====================================
  # パブリックメソッド
  # =====================================

  # セッションの参加者を取得
  # @return [Array<User>] セッションの参加者
  def participants
    [user1, user2]
  end

  # 指定されたユーザーがこのセッションの参加者かどうか
  # @param [User] user チェックするユーザー
  # @return [Boolean] 参加者の場合はtrue
  def participant?(user)
    user1 == user || user2 == user
  end

  # 相手のユーザーを取得
  # @param [User] user 自分のユーザー
  # @return [User, nil] 相手のユーザー、見つからない場合はnil
  def partner_for(user)
    return user2 if user1 == user
    return user1 if user2 == user
    nil
  end

  # セッションを開始
  def start!
    return false unless status == 'waiting'
    
    update!(
      status: 'active',
      started_at: Time.current
    )
  end

  # セッションを完了
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
  # @return [Integer] 経過時間（秒）
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
      timer_started_at: Time.current
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
        timer_started_at: nil
      )
    end
  end

  # タイマーを再開（start_timer!のエイリアス）
  def resume_timer!
    start_timer!
  end

  # タイマーを停止（一時停止と同じ処理）
  def stop_timer!
    pause_timer!
  end

  # ハートを追加
  # @param [Integer] count 追加するハート数
  def add_hearts(count = 1)
    increment!(:heart_count, count)
  end

  # セッションの経過時間を文字列で取得
  # @return [String] MM:SS形式の時間
  def elapsed_time_formatted
    seconds = current_elapsed_seconds
    minutes = seconds / 60
    remaining_seconds = seconds % 60
    format('%02d:%02d', minutes, remaining_seconds)
  end

  # セッションがアクティブかどうか
  # @return [Boolean] アクティブな場合はtrue
  def active?
    status == 'active'
  end

  # セッションが完了しているかどうか
  # @return [Boolean] 完了している場合はtrue
  def completed?
    status == 'completed'
  end

  private

  # =====================================
  # プライベートメソッド
  # =====================================

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
      errors.add(:base, "セッションを作成できるのはペアになっているユーザーのみです")
    end
  end
end