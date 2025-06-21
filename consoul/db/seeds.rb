# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# 開発・テスト用のユーザーペア作成
if Rails.env.development? || Rails.env.test?
  # m@m.com ユーザー
  user_m = User.find_or_create_by!(email: 'm@m.com') do |user|
    user.name = 'M'
    user.password = 'aaaaa1'
    user.password_confirmation = 'aaaaa1'
  end

  # w@w.com ユーザー
  user_w = User.find_or_create_by!(email: 'w@w.com') do |user|
    user.name = 'W'
    user.password = 'aaaaa1'
    user.password_confirmation = 'aaaaa1'
  end

  # ペア関係を作成（双方向）
  unless user_m.paired?
    user_m.create_mutual_pair_with(user_w)
    puts "テスト用ペア作成完了: #{user_m.email} ⇔ #{user_w.email}"
  else
    puts "テスト用ペアは既に存在します"
  end
end
