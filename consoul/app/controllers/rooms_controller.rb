class RoomsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_room, only: [ :show, :edit, :update, :destroy ]
  before_action :ensure_paired, only: [ :new, :create ]
  before_action :ensure_participant, only: [ :show, :edit, :update, :destroy ]

  def index
    @rooms = current_user.rooms.recent
  end

  def show
    # リアルタイム更新用のデータを取得
    @partner = @room.partner_for(current_user)
  end

  def new
    @room = Room.new
  end

  def create
    @room = current_user.create_room_with_partner(room_params[:title])

    if @room&.persisted?
      redirect_to @room, notice: "ルームが作成されました。"
    else
      @room ||= Room.new
      flash.now[:alert] = "ルームの作成に失敗しました。"
      render :new
    end
  end

  def edit
  end

  def update
    if @room.update(room_params)
      redirect_to @room, notice: "ルームが更新されました。"
    else
      render :edit
    end
  end

  def destroy
    @room.destroy
    redirect_to rooms_path, notice: "ルームが削除されました。"
  end

  # Ajax API endpoints
  def start
    if @room.start!
      render json: { success: true, room: room_status_data }
    else
      render json: { success: false, error: "ルームを開始できませんでした" }
    end
  end

  def pause_timer
    if @room.pause_timer!
      render json: { success: true, room: room_status_data }
    else
      render json: { success: false, error: "タイマーを一時停止できませんでした" }
    end
  end

  def resume_timer
    if @room.start_timer!
      render json: { success: true, room: room_status_data }
    else
      render json: { success: false, error: "タイマーを再開できませんでした" }
    end
  end

  def complete
    if @room.complete!
      render json: { success: true, room: room_status_data }
    else
      render json: { success: false, error: "ルームを終了できませんでした" }
    end
  end

  def add_heart
    @room.add_hearts
    render json: { success: true, room: room_status_data }
  end

  def update_activity
    @room.update_activity!
    render json: { success: true, room: room_status_data }
  end

  def set_emotion
    emotion = params[:emotion]
    
    if @room.set_emotion_for_user(current_user, emotion)
      render json: { success: true, room: room_status_data }
    else
      render json: { success: false, error: "感情の設定に失敗しました" }
    end
  end

  def status
    render json: { room: room_status_data }
  end

  private

  def set_room
    @room = Room.find(params[:id])
  end

  def room_params
    params.require(:room).permit(:title)
  end

  def ensure_paired
    unless current_user.paired?
      redirect_to root_path, alert: "ルームを作成するにはペアが必要です。"
    end
  end

  def ensure_participant
    unless @room.participant?(current_user)
      redirect_to root_path, alert: "このルームにアクセスする権限がありません。"
    end
  end

  def room_status_data
    {
      id: @room.id,
      title: @room.title,
      status: @room.status,
      timer_running: @room.timer_running?,
      elapsed_time: @room.elapsed_time_formatted,
      elapsed_seconds: @room.current_elapsed_seconds,
      heart_count: @room.heart_count,
      last_activity_at: @room.last_activity_at&.strftime("%H:%M:%S"),
      started_at: @room.started_at&.strftime("%H:%M"),
      ended_at: @room.ended_at&.strftime("%Y/%m/%d %H:%M"),
      user1_emotion: @room.user1_emotion,
      user2_emotion: @room.user2_emotion,
      current_user_emotion: @room.emotion_for_user(current_user),
      partner_emotion: @room.emotion_for_user(@room.partner_for(current_user))
    }
  end
end
