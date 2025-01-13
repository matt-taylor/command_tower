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

  scope "user" do
    get "/", to: "api_engine_base/user#show", as: :"#{append_to_ass}_user_show_get"
    post "/modify", to: "api_engine_base/user#modify", as: :"#{append_to_ass}_user_modify_post"
  end

  scope "admin" do
    get "/", to: "api_engine_base/admin#show", as: :"#{append_to_ass}_admin_show_get"
    post "/modify", to: "api_engine_base/admin#modify", as: :"#{append_to_ass}_admin_modify_post"
    post "/modify/role", to: "api_engine_base/admin#modify_role", as: :"#{append_to_ass}_admin_modify_role_post"
  end
end
