require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'アソシエーション' do
    it 'pair_userに属する（オプショナル）' do
      user = User.new
      expect(user).to respond_to(:pair_user)
      expect(user.class.reflect_on_association(:pair_user).macro).to eq :belongs_to
      expect(user.class.reflect_on_association(:pair_user).options[:optional]).to be true
    end

    it 'paired_withを持つ' do
      user = User.new
      expect(user).to respond_to(:paired_with)
      expect(user.class.reflect_on_association(:paired_with).macro).to eq :has_one
      expect(user.class.reflect_on_association(:paired_with).options[:foreign_key]).to eq :pair_user_id
    end
  end

  describe 'Deviseの検証' do
    it 'メールアドレスが必須であること' do
      user = User.new(password: 'password123')
      expect(user).not_to be_valid
      expect(user.errors[:email]).to include("can't be blank")
    end

    it 'パスワードが必須であること' do
      user = User.new(email: 'test@example.com')
      expect(user).not_to be_valid
      expect(user.errors[:password]).to include("can't be blank")
    end

    it '有効なメールアドレス、名前、パスワードで作成できること' do
      user = User.new(email: 'test@example.com', name: 'Test User', password: 'password123')
      expect(user).to be_valid
    end
  end

  describe '#paired?' do
    let(:user1) { User.create!(email: 'user1@example.com', name: 'User1', password: 'password123') }
    let(:user2) { User.create!(email: 'user2@example.com', name: 'User2', password: 'password123') }

    context 'ペアがいない場合' do
      it 'falseを返すこと' do
        expect(user1.paired?).to be false
      end
    end

    context 'pair_userが設定されている場合' do
      before { user1.update!(pair_user: user2) }

      it 'trueを返すこと' do
        expect(user1.paired?).to be true
      end
    end

    context 'paired_withを持っている場合' do
      before { user2.update!(pair_user: user1) }

      it 'trueを返すこと' do
        expect(user1.paired?).to be true
      end
    end
  end

  describe '#partner' do
    let(:user1) { User.create!(email: 'user1@example.com', name: 'User1', password: 'password123') }
    let(:user2) { User.create!(email: 'user2@example.com', name: 'User2', password: 'password123') }
    let(:user3) { User.create!(email: 'user3@example.com', name: 'User3', password: 'password123') }

    context 'ペアがいない場合' do
      it 'nilを返すこと' do
        expect(user1.partner).to be_nil
      end
    end

    context 'pair_userが設定されている場合' do
      before { user1.update!(pair_user: user2) }

      it 'pair_userを返すこと' do
        expect(user1.partner).to eq user2
      end
    end

    context 'paired_withを持っている場合' do
      before { user2.update!(pair_user: user1) }

      it 'paired_withを返すこと' do
        expect(user1.partner).to eq user2
      end
    end
  end

  describe '#unpair!' do
    let(:user1) { User.create!(email: 'user1@example.com', name: 'User1', password: 'password123') }
    let(:user2) { User.create!(email: 'user2@example.com', name: 'User2', password: 'password123') }

    context 'pair_userが設定されている場合' do
      before do
        user1.update!(pair_user: user2)
        user2.update!(pair_user: user1)
      end

      it '双方のペア関係を解消すること' do
        user1.unpair!
        expect(user1.reload.pair_user).to be_nil
        expect(user2.reload.pair_user).to be_nil
      end
    end

    context 'paired_withを持っている場合' do
      before { user2.update!(pair_user: user1) }

      it 'ペア関係を解消すること' do
        user1.unpair!
        expect(user2.reload.pair_user).to be_nil
      end
    end
  end

  describe '#create_mutual_pair_with' do
    let(:user1) { User.create!(email: 'user1@example.com', name: 'User1', password: 'password123') }
    let(:user2) { User.create!(email: 'user2@example.com', name: 'User2', password: 'password123') }
    let(:user3) { User.create!(email: 'user3@example.com', name: 'User3', password: 'password123') }

    it '相互ペアを作成できること' do
      result = user1.create_mutual_pair_with(user2)
      expect(result).to be true
      expect(user1.reload.partner).to eq user2
      expect(user2.reload.partner).to eq user1
    end

    it '自分自身とペアを作成できないこと' do
      result = user1.create_mutual_pair_with(user1)
      expect(result).to be false
    end

    it 'nilを渡した場合はfalseを返すこと' do
      result = user1.create_mutual_pair_with(nil)
      expect(result).to be false
    end

    it 'すでにペアがいる場合はfalseを返すこと' do
      user1.create_mutual_pair_with(user2)
      result = user1.create_mutual_pair_with(user3)
      expect(result).to be false
    end

    it '相手にすでにペアがいる場合はfalseを返すこと' do
      user2.create_mutual_pair_with(user3)
      result = user1.create_mutual_pair_with(user2)
      expect(result).to be false
    end
  end

  describe 'ペアシステムの整合性' do
    let(:user1) { User.create!(email: 'user1@example.com', name: 'User1', password: 'password123') }
    let(:user2) { User.create!(email: 'user2@example.com', name: 'User2', password: 'password123') }
    let(:user3) { User.create!(email: 'user3@example.com', name: 'User3', password: 'password123') }

    it '相互にペアを作成できること' do
      user1.update!(pair_user: user2)
      user2.update!(pair_user: user1)

      expect(user1.partner).to eq user2
      expect(user2.partner).to eq user1
    end

    it '自分自身をペアに設定できないこと' do
      user1.pair_user = user1
      expect(user1.save).to be false
      expect(user1.errors[:pair_user]).to include("自分自身をペアに設定することはできません")
    end
  end
end
