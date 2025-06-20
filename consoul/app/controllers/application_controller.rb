class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  
  # Devise認証
  before_action :authenticate_user!
  
  # ログイン後のリダイレクト先
  def after_sign_in_path_for(resource)
    root_path
  end
end
