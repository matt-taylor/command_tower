Rails.application.routes.draw do
  append_to_ass = "command_tower"

  constraints(->(_req) { CommandTower.config.username.realtime_username_check? }) do
    scope "username" do
      get "/available/:username", to: "command_tower/username#username_availability", as: :"#{append_to_ass}_username_availability_get"
    end
  end

  scope "auth" do
    constraints(->(_req) { CommandTower.config.login.plain_text.enable? }) do
      post "/login", to: "command_tower/auth/plain_text#login_post", as: :"#{append_to_ass}_auth_login_post"
      post "/create", to: "command_tower/auth/plain_text#create_post", as: :"#{append_to_ass}_auth_create_post"

      constraints(->(_req) { CommandTower.config.login.plain_text.email_verify? }) do
        scope "email" do
          post "/verify", to: "command_tower/auth/plain_text#email_verify_post", as: :"#{append_to_ass}_auth_email_verification"
          post "/send", to: "command_tower/auth/plain_text#email_verify_resend_post", as: :"#{append_to_ass}_auth_email_verification_send"
        end
      end
    end
  end

  scope "user" do
    get "/", to: "command_tower/user#show", as: :"#{append_to_ass}_user_show_get"
    post "/modify", to: "command_tower/user#modify", as: :"#{append_to_ass}_user_modify_post"
  end

  scope "inbox" do
    scope "messages" do
      get "/", to: "command_tower/inbox/message#metadata", as: :"#{append_to_ass}_inbox_metadata"

      get "/:id", to: "command_tower/inbox/message#message", as: :"#{append_to_ass}_inbox_message"
      delete "/:id", to: "command_tower/inbox/message#delete", as: :"#{append_to_ass}_inbox_message_del"

      post "/ack", to: "command_tower/inbox/message#ack", as: :"#{append_to_ass}_inbox_ack"
      post "/delete", to: "command_tower/inbox/message#delete", as: :"#{append_to_ass}_inbox_delete"
    end

    scope "blast" do
      get "/", to: "command_tower/inbox/message_blast#metadata", as: :"#{append_to_ass}_blast_metadata"
      post "/", to: "command_tower/inbox/message_blast#create", as: :"#{append_to_ass}_blast_create"

      get "/:id", to: "command_tower/inbox/message_blast#blast", as: :"#{append_to_ass}_blast_blast"
      patch "/:id", to: "command_tower/inbox/message_blast#modify", as: :"#{append_to_ass}_blast_modify"
      delete "/:id", to: "command_tower/inbox/message_blast#delete", as: :"#{append_to_ass}_blast_delete"
    end
  end

  scope "admin" do
    get "/", to: "command_tower/admin#show", as: :"#{append_to_ass}_admin_show_get"
    post "/modify", to: "command_tower/admin#modify", as: :"#{append_to_ass}_admin_modify_post"
    post "/modify/role", to: "command_tower/admin#modify_role", as: :"#{append_to_ass}_admin_modify_role_post"
  end
end
