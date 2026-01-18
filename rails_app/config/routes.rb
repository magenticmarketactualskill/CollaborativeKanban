Rails.application.routes.draw do
  # Authentication
  get 'login', to: 'sessions#new', as: :login
  post 'login', to: 'sessions#create'
  delete 'logout', to: 'sessions#destroy', as: :logout

  # Boards
  resources :boards do
    resources :columns, only: [:create, :update, :destroy] do
      post :reorder, on: :collection
    end

    resources :cards, only: [:show, :new, :create, :edit, :update, :destroy] do
      member do
        patch :move
        post :assign
        delete :unassign
      end
    end

    resources :board_members, only: [:index, :create, :update, :destroy]
  end

  # Health check
  get 'up' => 'rails/health#show', as: :rails_health_check

  # Root
  root 'boards#index'
end
