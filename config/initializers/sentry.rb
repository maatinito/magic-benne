# frozen_string_literal: true

Sentry.init do |config|
  config.dsn = 'https://0f3598d0d22045e9ace1353972bcfda0@o256076.ingest.sentry.io/6298460'
  config.breadcrumbs_logger = %i[active_support_logger http_logger]

  # Set tracesSampleRate to 1.0 to capture 100%
  # of transactions for performance monitoring.
  # We recommend adjusting this value in production
  config.traces_sample_rate = 1.0
  # or
  # config.traces_sampler = lambda do |context|
  #   true
  # end
end
