Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "dashboards#show"

  resource :search, only: :show
  resources :classrooms
  resource :student_import, only: %i[new create] do
    get :template
    post :confirm
  end
  resources :students
  resources :subjects, except: :show

  resources :exams do
    resource :answer_key, only: %i[edit update]
    resource :report, only: :show
    resources :answer_sheets, only: %i[new create show update destroy] do
      post :reprocess, on: :member
    end
  end
end
