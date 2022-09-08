# frozen_string_literal: true

source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby '3.1.2'

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
# gem 'odf-report'
# gem 'prawn' # PDF Generation
# gem 'prawn-qrcode' # to generate qrcode in pdfs
# gem 'prawn-rails' # PDF Generation
# gem 'prawn-svg'
# gem 'prawn-table'
gem 'rails', '~> 6.1.6'

# to write Excelx
gem 'caxlsx'
# Use sqlite3 as the database for Active Record
gem 'sqlite3', '~> 1.4'
# Use Puma as the app server
gem 'puma', '>= 3.12.6'
# Use SCSS for stylesheets
gem 'sass-rails', '~> 5.0'
# Use Uglifier as compressor for JavaScript assets
gem 'uglifier', '>= 1.3.0'
# Transpile app-like JavaScript. Read more: https://github.com/rails/webpacker
gem 'webpacker'
# See https://github.com/rails/execjs#readme for more supported runtimes
# gem 'mini_racer', platforms: :ruby

# Use CoffeeScript for .coffee assets and views
gem 'coffee-rails', '~> 5.0'
# Turbolinks makes navigating your web application faster. Read more: https://github.com/turbolinks/turbolinks
gem 'turbolinks', '~> 5'
# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem 'jbuilder', '~> 2.5'
# Use Redis adapter to run Action Cable in production
# gem 'redis', '~> 4.0'
# Use Active Model has_secure_password
# gem 'bcrypt', '~> 3.1.7'

# Use Active Storage variant
# gem 'image_processing', '~> 1.2'

# Reduces boot times through caching; required in config/boot.rb
# Reduces boot times through caching; required in config/boot.rb
gem 'bootsnap', require: false
gem 'bootstrap', '~> 4.6.0'
gem 'delayed_cron_job' # Cron jobs
gem 'delayed_job_active_record'
gem 'delayed_job_web'
gem 'devise'
gem 'devise-i18n'
gem 'discard'
gem 'fugit'
gem 'haml-rails'
gem 'jquery-rails'
gem 'mailjet'
gem 'net-ftp'
gem 'net-smtp'
gem 'pg'
gem 'premailer-rails'
gem 'roo-xls'
gem 'rubyzip'
gem 'sassc-rails' # Use SCSS for stylesheets
gem 'sentry-delayed_job'
gem 'sentry-rails'
gem 'sentry-ruby'
gem 'typhoeus'

group :development, :test do
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'byebug', platforms: %i[mri mingw x64_mingw]
  gem 'dotenv-rails'
  gem 'factory_bot_rails'
  gem 'spring'
  gem 'spring-commands-rspec'
  gem 'spring-watcher-listen', '~> 2.0.0'
  gem 'testftpd', require: false, github: 'christian-schulze/testftpd'
  gem 'vcr', '~> 5.1.0'
  gem 'webmock', '~> 3.8.0'
end

group :development do
  gem 'annotate'
  # Access an interactive console on exception pages or by calling 'console' anywhere in the code.
  gem 'listen', '>= 3.0.5', '< 3.2'
  gem 'web-console', '>= 3.3.0'
  # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  gem 'haml-lint'
  gem 'letter_opener_web'
  gem 'mry'
  gem 'rspec-rails'
  gem 'rubocop', require: false
  gem 'rubocop-rails_config'
  gem 'rubocop-rspec'
  gem 'scss_lint', require: false
end

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem 'tzinfo-data', platforms: %i[mingw mswin x64_mingw jruby]

gem 'graphql-client', '~> 0.16.0'
