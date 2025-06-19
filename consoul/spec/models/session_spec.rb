require 'rails_helper'

RSpec.describe Session, type: :model do
  let(:user1) { User.create!(email: 'user1@example.com', password: 'password123') }
  let(:user2) { User.create!(email: 'user2@example.com', password: 'password123') }
  let(:user3) { User.create!(email: 'user3@example.com', password: 'password123') }

  before do
    # user1とuser2をペアにする
    user1.create_mutual_pair_with(user2)
  end

  describe 'アソシエーション' do
    it 'user1に属すること' do
      session = Session.new
      expect(session).to respond_to(:user1)
      expect(session.class.reflect_on_association(:user1).macro).to eq :belongs_to
    end

    it 'user2に属すること' do
      session = Session.new
      expect(session).to respond_to(:user2)
      expect(session.class.reflect_on_association(:user2).macro).to eq :belongs_to
    end
  end

  describe 'バリデーション' do
    let(:valid_session) do
      Session.new(
        title: 'テストセッション',
        user1: user1,
        user2: user2
      )
    end

    it '有効な情報で作成できること' do
      expect(valid_session).to be_valid
    end

    it 'titleが必須であること' do
      valid_session.title = nil
      expect(valid_session).not_to be_valid
      expect(valid_session.errors[:title]).to include("can't be blank")
    end

    it 'titleが100文字以下であること' do
      valid_session.title = 'a' * 101
      expect(valid_session).not_to be_valid
      expect(valid_session.errors[:title]).to include('is too long (maximum is 100 characters)')
    end

    it 'statusが有効な値であること' do
      valid_statuses = %w[waiting active paused completed]
      valid_statuses.each do |status|
        valid_session.status = status
        expect(valid_session).to be_valid
      end

      valid_session.status = 'invalid'
      expect(valid_session).not_to be_valid
    end

    it '同じユーザーを指定できないこと' do
      session = Session.new(
        title: 'テストセッション',
        user1: user1,
        user2: user1
      )
      expect(session).not_to be_valid
      expect(session.errors[:user2]).to include("同じユーザーを指定することはできません")
    end

    it 'ペアになっていないユーザーでセッションを作成できないこと' do
      session = Session.new(
        title: 'テストセッション',
        user1: user1,
        user2: user3
      )
      expect(session).not_to be_valid
      expect(session.errors[:base]).to include("セッションを作成できるのはペアになっているユーザーのみです")
    end
  end

  describe 'スコープ' do
    let!(:active_session) do
      Session.create!(
        title: 'アクティブセッション',
        status: 'active',
        user1: user1,
        user2: user2
      )
    end

    let!(:waiting_session) do
      Session.create!(
        title: '待機セッション',
        status: 'waiting',
        user1: user1,
        user2: user2
      )
    end

    describe '.active' do
      it 'アクティブなセッションのみを返すこと' do
        expect(Session.active).to include(active_session)
        expect(Session.active).not_to include(waiting_session)
      end
    end

    describe '.for_user' do
      it '指定したユーザーのセッションを返すこと' do
        sessions = Session.for_user(user1)
        expect(sessions).to include(active_session, waiting_session)
      end
    end

    describe '.recent' do
      it '作成日時の降順で返すこと' do
        sessions = Session.recent
        expect(sessions.first.created_at).to be >= sessions.last.created_at
      end
    end
  end

  describe '#participants' do
    let(:session) do
      Session.create!(
        title: 'テストセッション',
        user1: user1,
        user2: user2
      )
    end

    it '参加者の配列を返すこと' do
      expect(session.participants).to eq [user1, user2]
    end
  end

  describe '#participant?' do
    let(:session) do
      Session.create!(
        title: 'テストセッション',
        user1: user1,
        user2: user2
      )
    end

    it 'user1が参加者の場合はtrueを返すこと' do
      expect(session.participant?(user1)).to be true
    end

    it 'user2が参加者の場合はtrueを返すこと' do
      expect(session.participant?(user2)).to be true
    end

    it '参加者でない場合はfalseを返すこと' do
      expect(session.participant?(user3)).to be false
    end
  end

  describe '#partner_for' do
    let(:session) do
      Session.create!(
        title: 'テストセッション',
        user1: user1,
        user2: user2
      )
    end

    it 'user1に対してuser2を返すこと' do
      expect(session.partner_for(user1)).to eq user2
    end

    it 'user2に対してuser1を返すこと' do
      expect(session.partner_for(user2)).to eq user1
    end

    it '参加者でない場合はnilを返すこと' do
      expect(session.partner_for(user3)).to be_nil
    end
  end

  describe 'セッション状態管理' do
    let(:session) do
      Session.create!(
        title: 'テストセッション',
        user1: user1,
        user2: user2
      )
    end

    describe '#start!' do
      it 'waitingからactiveに変更できること' do
        expect(session.start!).to be true
        expect(session.reload.status).to eq 'active'
        expect(session.started_at).to be_present
      end

      it 'waiting以外の状態では失敗すること' do
        session.update!(status: 'active')
        expect(session.start!).to be false
      end
    end

    describe '#complete!' do
      it 'activeからcompletedに変更できること' do
        session.update!(status: 'active')
        expect(session.complete!).to be true
        expect(session.reload.status).to eq 'completed'
        expect(session.ended_at).to be_present
      end

      it 'pausedからcompletedに変更できること' do
        session.update!(status: 'paused')
        expect(session.complete!).to be true
        expect(session.reload.status).to eq 'completed'
      end

      it 'waitingからは変更できないこと' do
        expect(session.complete!).to be false
      end
    end

    describe '#active?' do
      it 'statusがactiveの場合はtrueを返すこと' do
        session.update!(status: 'active')
        expect(session.active?).to be true
      end

      it 'statusがactive以外の場合はfalseを返すこと' do
        session.update!(status: 'waiting')
        expect(session.active?).to be false
      end
    end

    describe '#completed?' do
      it 'statusがcompletedの場合はtrueを返すこと' do
        session.update!(status: 'completed')
        expect(session.completed?).to be true
      end

      it 'statusがcompleted以外の場合はfalseを返すこと' do
        session.update!(status: 'active')
        expect(session.completed?).to be false
      end
    end
  end

  describe 'タイマー機能' do
    let(:session) do
      Session.create!(
        title: 'テストセッション',
        user1: user1,
        user2: user2
      )
    end

    describe '#start_timer!' do
      it 'タイマーを開始できること' do
        expect(session.start_timer!).to be true
        expect(session.reload.timer_running).to be true
        expect(session.timer_started_at).to be_present
      end

      it '既に動いている場合は失敗すること' do
        session.start_timer!
        expect(session.start_timer!).to be false
      end
    end

    describe '#pause_timer!' do
      before { session.start_timer! }

      it 'タイマーを一時停止できること' do
        sleep(1) # 1秒待つ
        expect(session.pause_timer!).to be true
        session.reload
        expect(session.timer_running).to be false
        expect(session.timer_seconds).to be >= 1
        expect(session.timer_started_at).to be_nil
      end

      it '停止している場合は失敗すること' do
        session.pause_timer!
        expect(session.pause_timer!).to be false
      end
    end

    describe '#current_elapsed_seconds' do
      it 'タイマーが停止している場合はtimer_secondsを返すこと' do
        session.update!(timer_seconds: 30)
        expect(session.current_elapsed_seconds).to eq 30
      end

      it 'タイマーが動いている場合は現在の経過時間を返すこと' do
        session.start_timer!
        sleep(1)
        expect(session.current_elapsed_seconds).to be >= 1
      end
    end

    describe '#elapsed_time_formatted' do
      it 'MM:SS形式で時間を返すこと' do
        session.update!(timer_seconds: 125) # 2分5秒
        expect(session.elapsed_time_formatted).to eq '02:05'
      end

      it '0秒の場合は00:00を返すこと' do
        expect(session.elapsed_time_formatted).to eq '00:00'
      end
    end
  end

  describe 'ハート機能' do
    let(:session) do
      Session.create!(
        title: 'テストセッション',
        user1: user1,
        user2: user2
      )
    end

    describe '#add_hearts' do
      it 'ハートを追加できること' do
        session.add_hearts(3)
        expect(session.reload.heart_count).to eq 3
      end

      it 'デフォルトで1つ追加されること' do
        session.add_hearts
        expect(session.reload.heart_count).to eq 1
      end

      it '累積でハートが追加されること' do
        session.add_hearts(2)
        session.add_hearts(3)
        expect(session.reload.heart_count).to eq 5
      end
    end
  end
end