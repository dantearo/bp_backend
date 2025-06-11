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
    end
  end

  # Defines the root path route ("/")
  # root "posts#index"
end
