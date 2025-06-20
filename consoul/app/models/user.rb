class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  # =====================================
  # アソシエーション
  # =====================================
  belongs_to :pair_user, class_name: 'User', optional: true
  has_one :paired_with, class_name: 'User', foreign_key: :pair_user_id

  # =====================================
  # バリデーション
  # =====================================
  validates :name, presence: true, length: { maximum: 50 }
  validate :cannot_pair_with_self

  # =====================================
  # パブリックメソッド
  # =====================================

  # ペアになっているか確認
  # @return [Boolean] ペアが存在する場合はtrue
  def paired?
    pair_user.present? || paired_with.present?
  end

  # パートナーを取得
  # @return [User, nil] パートナーのUserオブジェクト、存在しない場合はnil
  def partner
    pair_user || paired_with
  end

  # ペア関係を解消
  def unpair!
    if pair_user.present?
      pair_user.update!(pair_user: nil)
      update!(pair_user: nil)
    elsif paired_with.present?
      paired_with.update!(pair_user: nil)
    end
  end

  # 相互ペアを作成
  # @param [User] other_user ペアになる相手のユーザー
  # @return [Boolean] ペア作成の成否
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

  # =====================================
  # プライベートメソッド
  # =====================================

  # 自分自身をペアに設定できないようにするバリデーション
  def cannot_pair_with_self
    if pair_user_id.present? && pair_user_id == id
      errors.add(:pair_user, "自分自身をペアに設定することはできません")
    end
  end
end