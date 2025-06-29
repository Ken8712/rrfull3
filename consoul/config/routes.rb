Rails.application.routes.draw do
  devise_for :users

  # ダッシュボードをルートに設定
  root "dashboards#index"

  # ルーム関連
  resources :rooms do
    member do
      patch :start
      patch :pause_timer
      patch :resume_timer
      patch :complete
      patch :add_heart
      patch :update_activity
      patch :set_emotion
      get :status
    end
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/*
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
end
