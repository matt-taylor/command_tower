# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy.
# See the Securing Rails Applications Guide for more information:
# https://guides.rubyonrails.org/security.html#content-security-policy-header

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins '*'  # Replace '*' with frontend domain (e.g., 'http://localhost:19006' for Expo)
    resource '*',
      headers: :any,
      expose: ['Authorization'], # Exposes JWT token in responses if needed
      methods: [:get, :post, :put, :patch, :delete, :head]
  end
end

