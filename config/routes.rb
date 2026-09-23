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
    resources :decompositions, only: :create, shallow: true
    scope module: :components do
      resources :ingredient_lines, only: %i[ new create edit update destroy ], shallow: true
      resources :steps, only: %i[ new create edit update destroy ], shallow: true
      resources :parts, only: %i[ new create edit update destroy ], shallow: true
    end
  end
  resources :decompositions, only: :show
  resources :ingredients, except: :show
  resources :ingredient_families, except: :show
  resources :receipts, only: %i[ index new create show destroy ] do
    resource :confirmation, only: :create, module: :receipts
  end
  resources :stock_items, except: :show, path: "stock"
  resources :schedule_entries, except: :show, path: "schedule" do
    collection { post :plan }
    member do
      post :serve
      post :skip
      post :ease
    end
  end
  resources :household_members, except: :show, path: "household" do
    resources :food_needs, only: %i[ create edit update destroy ], shallow: true, module: :household_members
  end

  root "components#index"
end
