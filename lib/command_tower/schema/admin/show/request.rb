# frozen_string_literal: true

module CommandTower
  module Schema
    module Admin
      module Show
        class Request < JsonSchematize::Generator
          # GET endpoint - no request body validation needed
        end
      end
    end
  end
end
