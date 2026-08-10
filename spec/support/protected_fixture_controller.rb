# frozen_string_literal: true

module CommandTower
  # Test-only protected controller for ApplicationController auth/cookie/CSRF specs.
  # Replaces legacy AdminController as a harness — not a public platform surface.
  class ProtectedFixtureController < ::CommandTower::ApplicationController
    before_action :authenticate_user!
    before_action :load_target_user!, only: [:modify]

    def show
      render(json: { ok: true }, status: :ok)
    end

    def modify
      result = CommandTower::UserAttributes::Mutate.(
        user: @target_user,
        admin_user: current_user,
        username: params[:username],
        email: params[:email],
        first_name: params[:first_name],
        last_name: params[:last_name],
        email_validated: safe_boolean(value: params[:email_validated]),
        verifier_token: safe_boolean(value: params[:verifier_token]),
      )
      if result.success?
        render(json: { ok: true }, status: :created)
      else
        render(json: { message: result.msg }, status: :bad_request)
      end
    end

    private

    def load_target_user!
      @target_user = User.where(id: params[:user_id]).first
      return true if @target_user

      render(json: { message: "Invalid user" }, status: :bad_request)
      false
    end
  end
end
