# frozen_string_literal: true

Rails.application.routes.draw do
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html

  root 'demarches#main'

  get 'demarches/main'
  get 'demarches/export'
  get 'demarches/export_all'

  # view jobs
  match '/delayed_job' => DelayedJobWeb, :anchor => false, :via => %i[get post]

  # letter opener
  mount LetterOpenerWeb::Engine, at: '/letter_opener' if Rails.env.development?
end
