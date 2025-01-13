# frozen_string_literal: true

require "class_composer"

module ApiEngineBase
  module Configuration
    module Authorization
      class Config
        include ClassComposer::Generator

        add_composer :rbac_default_groups,
          desc: "The default Group Roles defined by this engine.",
          allowed: [TrueClass, FalseClass],
          default: true

        add_composer :rbac_group_path,
          desc: "If defined, this config points to the users YAML file defining RBAC group roles.",
          allowed: String,
          dynamic_default: ->(_) { Rails.root.join("config","rbac_groups.yml").to_s }
      end
    end
  end
end
