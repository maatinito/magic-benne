# frozen_string_literal: true

Rails.application.routes.draw do
  devise_for :users
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
  # devise_for :users

  root 'demarches#main'

  get 'demarches/main'
  get 'demarches/export'
  get 'demarches/export_all'
  get 'demarches/with_discarded'

  get 'task_executions/:id/discard', to: 'task_executions#discard', as: 'discard'
  get 'task_executions/:id/undiscard', to: 'task_executions#undiscard', as: 'undiscard'

  # view jobs
  match '/delayed_job' => DelayedJobWeb, :anchor => false, :via => %i[get post]

  # letter opener
  mount LetterOpenerWeb::Engine, at: '/letter_opener' if Rails.env.development?
end
