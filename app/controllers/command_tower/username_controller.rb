module CommandTower
  class UsernameController < ::CommandTower::ApplicationController

    # GET /username/available/:username
    def username_availability
      result = CommandTower::Username::Available.(username: params[:username])

      if result.success?
        json_result = {
          username: {
            available: result.available,
            valid: result.valid,
            description: CommandTower.config.username.username_failure_message
          }
        }
        status = 200
      else
        json_result = { msg: result.msg }
        json_result[:invalid_arguments] = true if result.invalid_arguments
        status = 401
      end

      render json: json_result, status: status
    end
  end
end
