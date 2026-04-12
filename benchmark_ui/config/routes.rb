require 'sidekiq/web'

Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  resources :tasks, only: [:index, :new, :create, :show] do
    post :enqueue_ruby_runs, on: :member
    post :enqueue_go_runs, on: :member
    post :enqueue_python_runs, on: :member
    post :enqueue_node_runs, on: :member
    post :recalculate_statistics, on: :member
    get  :durations_csv, on: :member
    get  :memory_csv,    on: :member
    patch :selected, to: 'tasks#update_selected', on: :member, as: :selected
  end
  
  get '/durations', to: 'durations#index', as: :durations
  get '/durations/selected_csv', to: 'durations#selected_csv', as: :durations_selected_csv
  get '/memory', to: 'memory#index', as: :memory
  get '/memory/selected_csv', to: 'memory#selected_csv', as: :memory_selected_csv
  root "tasks#index"

  mount Sidekiq::Web => "/sidekiq" # access it at http://localhost:3000/sidekiq
end
