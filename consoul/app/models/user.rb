class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable
  
  # ペアシステムの関連
  belongs_to :pair_user, class_name: 'User', optional: true
  has_one :paired_with, class_name: 'User', foreign_key: :pair_user_id
  
  # ペアになっているか確認
  def paired?
    pair_user.present? || paired_with.present?
  end
  
  # パートナーを取得
  def partner
    pair_user || paired_with
  end
end
