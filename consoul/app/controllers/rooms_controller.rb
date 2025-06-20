class RoomsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_room, only: [:show, :edit, :update, :destroy]
  before_action :ensure_paired, only: [:new, :create]
  before_action :ensure_participant, only: [:show, :edit, :update, :destroy]

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
      redirect_to @room, notice: 'ルームが作成されました。'
    else
      @room ||= Room.new
      flash.now[:alert] = 'ルームの作成に失敗しました。'
      render :new
    end
  end

  def edit
  end

  def update
    if @room.update(room_params)
      redirect_to @room, notice: 'ルームが更新されました。'
    else
      render :edit
    end
  end

  def destroy
    @room.destroy
    redirect_to rooms_path, notice: 'ルームが削除されました。'
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
      redirect_to root_path, alert: 'ルームを作成するにはペアが必要です。'
    end
  end

  def ensure_participant
    unless @room.participant?(current_user)
      redirect_to root_path, alert: 'このルームにアクセスする権限がありません。'
    end
  end
end
