Rails.application.routes.draw do
  devise_for :users
  
  # ダッシュボードをルートに設定
  root 'dashboard#index'
  get 'dashboard', to: 'dashboard#index'
  
  # セッション機能
  resources :sessions, only: [:index, :show, :new, :create] do
    member do
      # API エンドポイント（リアルタイム機能用）
      get :status
      post :start_timer
      post :pause_timer  
      post :add_hearts
      post :start_session
      post :complete
    end
  end

  # システム関連
  get "up" => "rails/health#show", as: :rails_health_check
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
end
