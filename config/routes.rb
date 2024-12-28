Rails.application.routes.draw do
  append_to_ass = "api_engine_base"

  constraints(->(_req) { ApiEngineBase.config.username.realtime_username_check? }) do
    scope "username" do
      get "/available/:username", to: "api_engine_base/username#username_availability", as: :"#{append_to_ass}_username_availability_get"
    end
  end

  scope "auth" do
    constraints(->(_req) { ApiEngineBase.config.login.plain_text.enable? }) do
      post "/login", to: "api_engine_base/auth/plain_text#login_post", as: :"#{append_to_ass}_auth_login_post"
      post "/create", to: "api_engine_base/auth/plain_text#create_post", as: :"#{append_to_ass}_auth_create_post"

      constraints(->(_req) { ApiEngineBase.config.login.plain_text.email_verify? }) do
        scope "email" do
          post "/verify", to: "api_engine_base/auth/plain_text#email_verify_post", as: :"#{append_to_ass}_auth_email_verification"
          post "/send", to: "api_engine_base/auth/plain_text#email_verify_resend_post", as: :"#{append_to_ass}_auth_email_verification_send"
        end
      end
    end
  end
end
