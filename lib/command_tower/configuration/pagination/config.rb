# frozen_string_literal: true

module CommandTower
  module Configuration
    module Pagination
      class Config < ::CommandTower::Configuration::Base
        include ClassComposer::Generator

        add_composer :limit,
          desc: "Default Limit for pagination return when not present on service or query/body. Negative values are treated like no limit",
          allowed: Integer,
          default: 10
      end
    end
  end
end
