Rails.application.routes.draw do
  # Authentication
  get 'login', to: 'sessions#new', as: :login
  post 'login', to: 'sessions#create'
  delete 'logout', to: 'sessions#destroy', as: :logout

  # Settings
  resource :settings, only: [:update] do
    post :test_connection, on: :collection
  end

  # Settings namespace for MCP and Skills
  namespace :settings do
    resource :mcp_server, only: [:show, :update] do
      post :test_connection, on: :collection
    end

    resources :mcp_clients, only: [:index, :new, :create, :edit, :update, :destroy] do
      member do
        post :connect
        post :disconnect
        post :refresh_capabilities
      end
    end

    resources :skills, only: [:index, :new, :create, :show, :edit, :update, :destroy] do
      collection do
        post :import
        get :export_all
      end
      member do
        get :export
        post :execute
      end
    end
  end

  # LLM Configurations
  resources :llm_configurations do
    member do
      post :test_connection
      post :set_default
    end
  end

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
        post :analyze
        post :infer_type
        get :suggestions
      end

      resources :ai_suggestions, only: [] do
        member do
          post :accept
          delete :dismiss
        end
      end

      resources :card_relationships, only: [:index, :create, :destroy] do
        collection do
          post :detect
        end
      end
    end

    resources :board_members, only: [:index, :create, :update, :destroy]
  end

  # Health check
  get 'up' => 'rails/health#show', as: :rails_health_check

  # Root
  root 'boards#index'
end
