# frozen_string_literal: true

module CommandTower::UserAttributes
  # Applies exactly one configuration-allowed account attribute change to a user.
  #
  # Used by modern Me profile services. Callers keep their own authorization
  # boundary; this object only enforces which attributes may change and what
  # values they accept.
  class Mutate
    # Attributes whose accepted values are not derivable from the column type.
    VALUE_OVERRIDES = {
      verifier_token: [true, false],
    }.freeze

    class Outcome
      attr_reader :user, :attribute, :msg, :invalid_argument_hash

      def self.success(user:, attribute:)
        new(success: true, user:, attribute:)
      end

      def self.invalid(user:, errors:)
        invalid_argument_hash = errors.transform_values { { msg: _1 } }
        msg = "Invalid arguments: #{errors.map { |key, message| "#{key}: #{message}" }.join(", ")}"

        new(success: false, user:, msg:, invalid_argument_hash:)
      end

      def initialize(success:, user:, attribute: nil, msg: nil, invalid_argument_hash: {})
        @success = success
        @user = user
        @attribute = attribute
        @msg = msg
        @invalid_argument_hash = invalid_argument_hash
      end

      def success? = @success

      def failure? = !@success

      def invalid_arguments = failure?

      def invalid_argument_keys = invalid_argument_hash.keys
    end

    class << self
      def call(user:, admin_user: nil, **attributes)
        new(user:, admin_user:, attributes:).call
      end

      # Invoked from lib/command_tower/configuration/user/config.rb whenever the
      # changeable attribute list is reconfigured.
      def assign!
        @change_rules = nil
      end

      def change_rules
        @change_rules ||= build_change_rules
      end

      private

      def build_change_rules
        configured = CommandTower.config.user.default_attributes_for_change +
          CommandTower.config.user.additional_attributes_for_change

        configured.uniq.each_with_object({}) do |attribute, rules|
          metadata = ::User.attribute_to_type_mapping[attribute]
          next if metadata.nil?

          key = attribute.to_sym
          allowed_values = VALUE_OVERRIDES[key] || metadata[:allowed_types]
          rules[key] = allowed_values ? { values: allowed_values } : { types: metadata[:ruby_type] }
        end
      end
    end

    def initialize(user:, attributes:, admin_user: nil)
      @user = user
      @admin_user = admin_user
      @attributes = attributes.symbolize_keys.compact
    end

    def call
      changes = attributes.slice(*change_rules.keys)
      return invalid(modify_attribute: composition_message(changes)) unless changes.size == 1

      attribute, value = changes.first

      type_message = type_message_for(attribute, value)
      return invalid(attribute => type_message) if type_message

      business_message = business_message_for(attribute, value)
      return invalid(attribute => business_message) if business_message

      if attribute == :verifier_token
        user.reset_verifier_token!
      else
        user.update!(attribute => value)
      end

      Outcome.success(user:, attribute:)
    end

    private

    attr_reader :user, :admin_user, :attributes

    def change_rules = self.class.change_rules

    def composition_message(changes)
      provided = changes.keys.presence || "none"

      "Exactly one attribute must be provided for change. " \
        "Provided: #{provided}. Available: #{change_rules.keys}"
    end

    def type_message_for(attribute, value)
      rule = change_rules.fetch(attribute)

      if (values = rule[:values])
        return nil if values.include?(value)

        "Parameter [#{attribute}] must be one of #{values}. Given #{value}"
      else
        types = rule[:types]
        return nil if Array(types).any? { _1 === value }

        "Parameter [#{attribute}] must be of type #{types}. Given #{value.class} [#{value}]"
      end
    end

    def business_message_for(attribute, value)
      case attribute
      when :email
        return nil if value =~ URI::MailTo::EMAIL_REGEXP

        "Invalid email address"
      when :username
        return nil if CommandTower::Username::Available.(username: value).valid?

        "Username is invalid. #{CommandTower.config.username.username_failure_message}"
      when :verifier_token
        return nil if value

        "verifier_token is invalid. Expected [true] when value present"
      end
    end

    def invalid(errors)
      Outcome.invalid(user:, errors:)
    end
  end
end
