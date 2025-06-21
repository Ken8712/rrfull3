class ApplicationController < ActionController::Base
  # Devise認証
  before_action :authenticate_user!

  # ログイン後のリダイレクト先
  def after_sign_in_path_for(resource)
    root_path
  end
end
