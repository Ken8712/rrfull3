require 'rails_helper'

RSpec.describe "基本フロー", type: :system do
  before do
    # テストデータの準備
    @user = User.create!(email: 'test@example.com', name: 'テストユーザー', password: 'password123')
    @partner = User.create!(email: 'partner@example.com', name: 'パートナー', password: 'password123')
    @user.create_mutual_pair_with(@partner)
  end
  
  describe "ログインからダッシュボード表示" do
    it "ログイン → ダッシュボード表示ができること" do
      # ログインページにアクセス
      visit new_user_session_path
      
      # ログインフォームの確認
      expect(page).to have_content("Log in")
      
      # ログイン情報を入力
      within("form") do
        find('input[name="user[email]"]').set(@user.email)
        find('input[name="user[password]"]').set("password123")
        find('input[type="submit"]').click
      end
      
      # ダッシュボードにリダイレクトされることを確認
      expect(current_path).to eq(root_path)
      expect(page).to have_content("ダッシュボード")
      expect(page).to have_content("ようこそ、#{@user.name}さん")
      expect(page).to have_content("Room機能は今後実装予定です")
    end
  end
  
  describe "未認証ユーザーのアクセス制限" do
    it "ログインしていない場合はログインページにリダイレクトされること" do
      # ダッシュボードに直接アクセス
      visit root_path
      
      # ログインページにリダイレクトされることを確認
      expect(current_path).to eq(new_user_session_path)
    end
  end
end