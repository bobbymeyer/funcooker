Rails.application.routes.draw do
  if Rails.env.development?
    mount ItsSwiss::Engine => "/its-swiss"
  end

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  resources :recipe_imports, only: %i[ index new create show destroy ]
  resources :components do
    collection { post :estimate_shelf_lives }
    member { post :estimate_shelf_life }
    resources :decompositions, only: :create, shallow: true
    scope module: :components do
      resources :ingredient_lines, only: %i[ new create edit update destroy ], shallow: true
      resources :steps, only: %i[ new create edit update destroy ], shallow: true
      resources :parts, only: %i[ new create edit update destroy ], shallow: true
    end
  end
  resources :decompositions, only: :show do
    member do
      post :confirm
      post :dismiss
    end
  end
  resources :ingredients, except: :show
  resources :ingredient_families, except: :show
  resources :receipts, only: %i[ index new create show destroy ] do
    resource :confirmation, only: :create, module: :receipts
  end
  resources :stock_items, except: :show, path: "stock" do
    scope module: :stock_items do
      resource :freezing, only: :create
      resource :thawing, only: :create
    end
  end
  resource :freezer, only: :show do
    post :remind
  end
  resource :shopping_list, only: :show, path: "shopping" do
    post :remind
  end
  resources :schedule_entries, except: :show, path: "schedule" do
    collection { post :plan }
    member do
      post :serve
      post :skip
      post :ease
      post :cook
    end
  end
  resources :cooking_sessions, only: %i[ index new create show destroy ], path: "cook" do
    member do
      post :recipe_order
      post :finish
    end
  end
  resources :cooking_tasks, only: [], path: "cook/steps" do
    member do
      post :start
      post :complete
      post :reopen
    end
  end
  resource :household, only: :update, path: "household/settings"
  resources :household_members, except: :show, path: "household" do
    resources :food_needs, only: %i[ create edit update destroy ], shallow: true, module: :household_members
  end

  root "components#index"
end
