# frozen_string_literal: true

# Modern platform HTTP only — intended for host mount (e.g. DFM `/api`).
CommandTower::Engine.routes.draw do
  # Test-only auth harness for ApplicationController cookie/CSRF specs.
  if Rails.env.test?
    get "show", to: "protected_fixture#show"
    post "modify", to: "protected_fixture#modify"
  end

  namespace :auth do
    post "logout", to: "logout#create"
    get "session", to: "session#show"

    constraints(->(_req) { CommandTower.config.login.plain_text.enable? }) do
      scope path: "plain-text", module: "plain_text" do
        post "login", to: "login#create"
      end
    end

    post "register", to: "register#create"
    post "signup-session", to: "signup_session/create#create"
    get "identity-policy", to: "identity_policy#show"

    constraints(->(_req) { CommandTower.config.signup_session.email_availability? }) do
      namespace :email do
        get "availability", to: "availability#show"
      end
    end

    # Parity with legacy SchemaHelper GET /username/available/:username gate.
    constraints(->(_req) { CommandTower.config.username.realtime_username_check? }) do
      namespace :username do
        get "availability", to: "availability#show"
      end
    end

    constraints(->(_req) { CommandTower.config.login.plain_text.email_verify? }) do
      namespace :email_verification, path: "email-verification", module: "email_verification" do
        post "send", to: "send#create"
        post "verify", to: "verify#create"
      end
    end

    post "password-recovery-session", to: "password_recovery_session/create#create"

    constraints(->(_req) { CommandTower.config.login.plain_text.password_reset? }) do
      namespace :password_reset, path: "password-reset", module: "password_reset" do
        post "send", to: "send#create"
        post "validate", to: "validate#create"
        post "reset", to: "reset#create"
      end
    end
  end

  get "me", to: "me#show"
  get "profile", to: "profile#show"
  namespace :me do
    patch "name", to: "name#update"
    patch "password", to: "password#update"

    resources :inbox, only: [:index, :show, :destroy], controller: "inbox" do
      collection do
        get :unread_count, path: "unread-count"
        post "bulk/read", action: :bulk_read
        post "bulk/unread", action: :bulk_unread
        post "bulk/archive", action: :bulk_archive
        post "bulk/restore", action: :bulk_restore
        post "bulk/delete", action: :bulk_delete
      end
      member do
        post :open
        patch :archive
      end
    end

    resource :preferences, only: [:show], controller: "preferences"
    patch "preferences/:notification_type_key", to: "preferences#update"

    # Phone lifecycle always drawn (no SMS/Pushover route constraints).
    # Product SMS readiness is workflow-gated as 503 sms_capability_unavailable.
    patch "phone", to: "phone#update"
    delete "phone", to: "phone#destroy"
    post "phone/verification", to: "phone_verification/verifications#create"
    post "phone/verification/verify", to: "phone_verification/verify#create"

    # Pushover lifecycle always drawn (no route constraints).
    # Product readiness is workflow-gated as 503 pushover_capability_unavailable.
    # Explicit put + patch both → #update (frontend uses PUT for replace).
    get "pushover", to: "pushover#show"
    post "pushover", to: "pushover#create"
    patch "pushover", to: "pushover#update"
    put "pushover", to: "pushover#update"
    delete "pushover", to: "pushover#destroy"
    post "pushover/verification", to: "pushover/verifications#create"
  end

  namespace :admin do
    namespace :messaging do
      post "announcements", to: "announcements#create"
    end
  end
end
