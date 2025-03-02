# frozen_string_literal: true

module CommandTower::UserAttributes
  class Modify < CommandTower::ServiceBase
    on_argument_validation :fail_early
    DEFAULT = {
      verifier_token: [true, false]
    }
    validate :user, is_a: User, required: true
    validate :admin_user, is_a: User, required: false

    # Gets assigned during configuration phase via
    # lib/command_tower/configuration/user/config.rb
    def self.assign!
      attributes = CommandTower.config.user.default_attributes_for_change + CommandTower.config.user.additional_attributes_for_change
      one_of(:modify_attribute, required: true) do
        attributes.uniq.each do |attribute|
          if metadata = User.attribute_to_type_mapping[attribute]
            arguments = {}
            if default = DEFAULT[attribute.to_sym]
              arguments[:is_one] = default
            else
              if allowed_types = metadata[:allowed_types]
                arguments[:is_one] = allowed_types
              else
                arguments[:is_a] = metadata[:ruby_type]
              end
            end

            validate(attribute, **arguments)
          end
        end
      end
    end

    def call
      case modify_attribute_key
      when :email
        unless email =~ URI::MailTo::EMAIL_REGEXP
          inline_argument_failure!(errors: { email: "Invalid email address" })
        end
      when :username
        username_validity = CommandTower::Username::Available.(username:)
        unless username_validity.valid
          inline_argument_failure!(errors: { username: "Username is invalid. #{CommandTower.config.username.username_failure_message}" })
        end
      when :verifier_token
        if verifier_token
          verifier_token!
        else
          inline_argument_failure!(errors: { verifier_token: "verifier_token is invalid. Expected [true] when value present" })
        end

        return
      end

      update!
    end

    def verifier_token!
      user.reset_verifier_token!
    end

    def update!
      user.update!(modify_attribute_key => modify_attribute)
    end
  end
end
