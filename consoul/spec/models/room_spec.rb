require 'rails_helper'

RSpec.describe Room, type: :model do
  # テストデータの準備
  let(:user1) { User.create!(email: 'user1@example.com', name: 'User1', password: 'password123') }
  let(:user2) { User.create!(email: 'user2@example.com', name: 'User2', password: 'password123') }
  let(:user3) { User.create!(email: 'user3@example.com', name: 'User3', password: 'password123') }
  
  before do
    # user1とuser2をペアにする
    user1.create_mutual_pair_with(user2)
  end

  describe 'アソシエーション' do
    it 'user1に属すること' do
      association = described_class.reflect_on_association(:user1)
      expect(association.macro).to eq(:belongs_to)
      expect(association.options[:class_name]).to eq('User')
    end

    it 'user2に属すること' do
      association = described_class.reflect_on_association(:user2)
      expect(association.macro).to eq(:belongs_to)
      expect(association.options[:class_name]).to eq('User')
    end
  end

  describe 'バリデーション' do
    it '有効な情報で作成できること' do
      room = Room.new(
        title: 'テストルーム',
        user1: user1,
        user2: user2
      )
      expect(room).to be_valid
    end

    it 'titleが必須であること' do
      room = Room.new(user1: user1, user2: user2)
      expect(room).not_to be_valid
      expect(room.errors[:title]).to include("can't be blank")
    end

    it 'titleが100文字以下であること' do
      room = Room.new(
        title: 'a' * 101,
        user1: user1,
        user2: user2
      )
      expect(room).not_to be_valid
      expect(room.errors[:title]).to include("is too long (maximum is 100 characters)")
    end

    it 'statusが有効な値であること' do
      room = Room.new(title: 'Test', user1: user1, user2: user2, status: 'invalid')
      expect(room).not_to be_valid
      expect(room.errors[:status]).to include("is not included in the list")
    end

    it '同じユーザーを指定できないこと' do
      room = Room.new(title: 'Test', user1: user1, user2: user1)
      expect(room).not_to be_valid
      expect(room.errors[:user2]).to include("同じユーザーを指定することはできません")
    end

    it 'ペアになっていないユーザーでルームを作成できないこと' do
      room = Room.new(title: 'Test', user1: user1, user2: user3)
      expect(room).not_to be_valid
      expect(room.errors[:base]).to include("ルームを作成できるのはペアになっているユーザーのみです")
    end
  end

  describe 'スコープ' do
    let!(:waiting_room) { Room.create!(title: '待機中', user1: user1, user2: user2, status: 'waiting') }
    let!(:active_room) { Room.create!(title: 'アクティブ', user1: user1, user2: user2, status: 'active') }
    let!(:completed_room) { Room.create!(title: '完了', user1: user1, user2: user2, status: 'completed') }

    describe '.active' do
      it 'アクティブなルームのみを返すこと' do
        expect(Room.active).to contain_exactly(active_room)
      end
    end

    describe '.for_user' do
      it '指定したユーザーのルームを返すこと' do
        rooms = Room.for_user(user1)
        expect(rooms).to include(waiting_room, active_room, completed_room)
      end
    end

    describe '.recent' do
      it '作成日時の降順で返すこと' do
        expect(Room.recent.first).to eq(completed_room)
        expect(Room.recent.last).to eq(waiting_room)
      end
    end
  end

  describe '#participants' do
    let(:room) { Room.create!(title: 'Test', user1: user1, user2: user2) }

    it '参加者の配列を返すこと' do
      expect(room.participants).to contain_exactly(user1, user2)
    end
  end

  describe '#participant?' do
    let(:room) { Room.create!(title: 'Test', user1: user1, user2: user2) }

    it 'user1が参加者の場合はtrueを返すこと' do
      expect(room.participant?(user1)).to be true
    end

    it 'user2が参加者の場合はtrueを返すこと' do
      expect(room.participant?(user2)).to be true
    end

    it '参加者でない場合はfalseを返すこと' do
      expect(room.participant?(user3)).to be false
    end
  end

  describe '#partner_for' do
    let(:room) { Room.create!(title: 'Test', user1: user1, user2: user2) }

    it 'user1に対してuser2を返すこと' do
      expect(room.partner_for(user1)).to eq(user2)
    end

    it 'user2に対してuser1を返すこと' do
      expect(room.partner_for(user2)).to eq(user1)
    end

    it '参加者でない場合はnilを返すこと' do
      expect(room.partner_for(user3)).to be_nil
    end
  end

  describe 'ルーム状態管理' do
    let(:room) { Room.create!(title: 'Test', user1: user1, user2: user2) }

    describe '#start!' do
      it 'waitingからactiveに変更できること' do
        expect(room.start!).to be true
        room.reload
        expect(room.status).to eq('active')
        expect(room.started_at).not_to be_nil
        expect(room.last_activity_at).not_to be_nil
      end

      it 'waiting以外の状態では失敗すること' do
        room.update!(status: 'active')
        expect(room.start!).to be false
      end
    end

    describe '#complete!' do
      it 'activeからcompletedに変更できること' do
        room.update!(status: 'active')
        expect(room.complete!).to be true
        room.reload
        expect(room.status).to eq('completed')
        expect(room.ended_at).not_to be_nil
      end

      it 'pausedからcompletedに変更できること' do
        room.update!(status: 'paused')
        expect(room.complete!).to be true
        room.reload
        expect(room.status).to eq('completed')
      end

      it 'waitingからは変更できないこと' do
        expect(room.complete!).to be false
      end
    end

    describe '#active?' do
      it 'statusがactiveの場合はtrueを返すこと' do
        room.update!(status: 'active')
        expect(room.active?).to be true
      end

      it 'statusがactive以外の場合はfalseを返すこと' do
        expect(room.active?).to be false
      end
    end

    describe '#completed?' do
      it 'statusがcompletedの場合はtrueを返すこと' do
        room.update!(status: 'completed')
        expect(room.completed?).to be true
      end

      it 'statusがcompleted以外の場合はfalseを返すこと' do
        expect(room.completed?).to be false
      end
    end
  end

  describe 'タイマー機能' do
    let(:room) { Room.create!(title: 'Test', user1: user1, user2: user2) }

    describe '#start_timer!' do
      it 'タイマーを開始できること' do
        expect(room.start_timer!).to be true
        room.reload
        expect(room.timer_running).to be true
        expect(room.timer_started_at).not_to be_nil
        expect(room.last_activity_at).not_to be_nil
      end

      it '既に動いている場合は失敗すること' do
        room.start_timer!
        expect(room.start_timer!).to be false
      end
    end

    describe '#pause_timer!' do
      before do
        room.start_timer!
        sleep(1)
      end

      it 'タイマーを一時停止できること' do
        expect(room.pause_timer!).to be true
        room.reload
        expect(room.timer_running).to be false
        expect(room.timer_started_at).to be_nil
        expect(room.timer_seconds).to be > 0
        expect(room.last_activity_at).not_to be_nil
      end

      it '停止している場合は失敗すること' do
        room.pause_timer!
        expect(room.pause_timer!).to be false
      end
    end

    describe '#current_elapsed_seconds' do
      it 'タイマーが停止している場合はtimer_secondsを返すこと' do
        room.update!(timer_seconds: 120)
        expect(room.current_elapsed_seconds).to eq(120)
      end

      it 'タイマーが動いている場合は現在の経過時間を返すこと' do
        room.update!(timer_seconds: 60)
        room.start_timer!
        sleep(1)
        expect(room.current_elapsed_seconds).to be > 60
      end
    end

    describe '#elapsed_time_formatted' do
      it 'MM:SS形式で時間を返すこと' do
        room.update!(timer_seconds: 125)
        expect(room.elapsed_time_formatted).to eq('02:05')
      end

      it '0秒の場合は00:00を返すこと' do
        expect(room.elapsed_time_formatted).to eq('00:00')
      end
    end
  end

  describe 'ハート機能' do
    let(:room) { Room.create!(title: 'Test', user1: user1, user2: user2) }

    describe '#add_hearts' do
      it 'ハートを追加できること' do
        room.add_hearts(5)
        expect(room.heart_count).to eq(5)
      end

      it 'デフォルトで1つ追加されること' do
        room.add_hearts
        expect(room.heart_count).to eq(1)
      end

      it '累積でハートが追加されること' do
        room.add_hearts(3)
        room.add_hearts(2)
        expect(room.heart_count).to eq(5)
      end

      it 'last_activity_atが更新されること' do
        room.update!(last_activity_at: 1.minute.ago)
        old_time = room.last_activity_at
        room.add_hearts
        room.reload
        expect(room.last_activity_at).to be > old_time
      end
    end
  end

  describe 'タイムアウト機能' do
    let(:room) { Room.create!(title: 'Test', user1: user1, user2: user2, status: 'active') }

    describe '#update_activity!' do
      it 'last_activity_atを現在時刻に更新すること' do
        room.update!(last_activity_at: 1.minute.ago)
        old_time = room.last_activity_at
        sleep(0.1)
        room.update_activity!
        expect(room.last_activity_at).to be > old_time
      end
    end

    describe '#stale?' do
      it 'last_activity_atがnilの場合はfalseを返すこと' do
        room.update_column(:last_activity_at, nil)
        expect(room.stale?).to be false
      end

      it '3分以内の場合はfalseを返すこと' do
        room.update!(last_activity_at: 2.minutes.ago)
        expect(room.stale?).to be false
      end

      it '3分以上前の場合はtrueを返すこと' do
        room.update!(last_activity_at: 4.minutes.ago)
        expect(room.stale?).to be true
      end
    end

    describe '#auto_complete_if_stale!' do
      it '非アクティブなactiveルームを完了にすること' do
        room.update!(last_activity_at: 4.minutes.ago)
        expect(room.auto_complete_if_stale!).to be true
        room.reload
        expect(room.status).to eq('completed')
        expect(room.ended_at).not_to be_nil
      end

      it 'アクティブなルームは変更しないこと' do
        room.update!(last_activity_at: 1.minute.ago)
        expect(room.auto_complete_if_stale!).to be false
        expect(room.status).to eq('active')
      end

      it 'completed状態のルームは変更しないこと' do
        room.update!(status: 'completed', last_activity_at: 4.minutes.ago)
        expect(room.auto_complete_if_stale!).to be false
        expect(room.status).to eq('completed')
      end
    end

    describe '.stale scope' do
      let!(:fresh_room) { Room.create!(title: 'Fresh', user1: user1, user2: user2, status: 'active', last_activity_at: 1.minute.ago) }
      let!(:stale_room) { Room.create!(title: 'Stale', user1: user1, user2: user2, status: 'active', last_activity_at: 4.minutes.ago) }

      it '古いactiveルームのみを返すこと' do
        expect(Room.stale).to contain_exactly(stale_room)
      end
    end
  end
end
