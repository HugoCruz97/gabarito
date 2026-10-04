Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "dashboards#show"

  resource :search, only: :show
  resources :classrooms
  resources :students
  resources :subjects, except: :show

  resources :exams do
    resource :answer_key, only: %i[edit update]
    resources :answer_sheets, only: %i[new create show update destroy] do
      post :reprocess, on: :member
    end
  end
end
