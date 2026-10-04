Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "dashboards#show"

  resource :search, only: :show
  resources :classrooms
  resources :students
  resources :subjects, except: :show

  resources :exams do
    resource :answer_key, only: %i[edit update]
  end
end
