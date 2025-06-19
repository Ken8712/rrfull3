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

    it '有効なメールアドレスとパスワードで作成できること' do
      user = User.new(email: 'test@example.com', password: 'password123')
      expect(user).to be_valid
    end
  end

  describe '#paired?' do
    let(:user1) { User.create!(email: 'user1@example.com', password: 'password123') }
    let(:user2) { User.create!(email: 'user2@example.com', password: 'password123') }

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
    let(:user1) { User.create!(email: 'user1@example.com', password: 'password123') }
    let(:user2) { User.create!(email: 'user2@example.com', password: 'password123') }
    let(:user3) { User.create!(email: 'user3@example.com', password: 'password123') }

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
    let(:user1) { User.create!(email: 'user1@example.com', password: 'password123') }
    let(:user2) { User.create!(email: 'user2@example.com', password: 'password123') }

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
    let(:user1) { User.create!(email: 'user1@example.com', password: 'password123') }
    let(:user2) { User.create!(email: 'user2@example.com', password: 'password123') }
    let(:user3) { User.create!(email: 'user3@example.com', password: 'password123') }

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
    let(:user1) { User.create!(email: 'user1@example.com', password: 'password123') }
    let(:user2) { User.create!(email: 'user2@example.com', password: 'password123') }
    let(:user3) { User.create!(email: 'user3@example.com', password: 'password123') }

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

  describe 'セッション関連' do
    let(:user1) { User.create!(email: 'user1@example.com', password: 'password123') }
    let(:user2) { User.create!(email: 'user2@example.com', password: 'password123') }

    before do
      user1.create_mutual_pair_with(user2)
    end

    describe '#sessions' do
      let!(:session1) do
        Session.create!(
          title: 'セッション1',
          user1: user1,
          user2: user2
        )
      end

      let!(:session2) do
        Session.create!(
          title: 'セッション2',
          user1: user2,
          user2: user1
        )
      end

      it '自分が参加しているセッションを返すこと' do
        sessions = user1.sessions
        expect(sessions).to include(session1, session2)
      end
    end

    describe '#create_session_with_partner' do
      it 'パートナーとのセッションを作成できること' do
        session = user1.create_session_with_partner('新しいセッション')
        expect(session).to be_persisted
        expect(session.title).to eq '新しいセッション'
        expect(session.user1).to eq user1
        expect(session.user2).to eq user2
      end

      it 'ペアがいない場合はnilを返すこと' do
        user3 = User.create!(email: 'user3@example.com', password: 'password123')
        session = user3.create_session_with_partner('失敗セッション')
        expect(session).to be_nil
      end
    end

    describe 'アソシエーション' do
      it 'sessions_as_user1を持つこと' do
        expect(user1).to respond_to(:sessions_as_user1)
        expect(user1.class.reflect_on_association(:sessions_as_user1).macro).to eq :has_many
      end

      it 'sessions_as_user2を持つこと' do
        expect(user1).to respond_to(:sessions_as_user2)
        expect(user1.class.reflect_on_association(:sessions_as_user2).macro).to eq :has_many
      end
    end
  end
end