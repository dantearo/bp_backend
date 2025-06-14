Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # API routes
  namespace :api do
    namespace :v1 do
      resources :flight_requests do
        member do
          put :status, to: "flight_requests#update_status"
          post :passenger_list, to: "flight_requests#upload_passenger_list"
          post :flight_brief, to: "flight_requests#upload_flight_brief"
        end

        resources :legs, controller: "flight_request_legs" do
          member do
            put :update
            delete :destroy
          end
        end
      end

      resources :vip_profiles do
        resources :sources, controller: "vip_sources"
      end

      # Operations endpoints
      namespace :operations do
        resources :requests, only: [] do
          member do
            put :receive
            put :review
            put :process, action: :start_process
            put :unable
            put :complete
            put :modify
          end
        end
        
        get :alerts
        get :completed_flights
        get :canceled_flights
      end

      # Airport endpoints
      resources :airports, only: [], param: :code do
        collection do
          get :search
        end
        member do
          get :operational_status
        end
      end
      get 'airports/:code', to: 'airports#show', constraints: { code: /[A-Z]{3,4}/ }

      # Integration endpoints
      namespace :integrations do
        post :check_availability
      end

      # Admin endpoints
      namespace :admin do
        resources :users do
          collection do
            post :create, to: "admin#create_user"
            get :index, to: "admin#list_users"
          end
          member do
            put :update, to: "admin#update_user"
            delete :destroy, to: "admin#delete_user"
          end
        end

        resources :vip_profiles do
          collection do
            post :create, to: "admin#create_vip_profile"
            get :index, to: "admin#list_vip_profiles"
          end
          member do
            put :update, to: "admin#update_vip_profile"
            delete :destroy, to: "admin#delete_vip_profile"
          end
        end

        resources :flight_requests, only: [] do
          member do
            delete :destroy, to: "admin#delete_flight_request"
            put :finalize, to: "admin#finalize_flight_request"
          end
        end
      end
    end
  end

  # Defines the root path route ("/")
  # root "posts#index"
end
