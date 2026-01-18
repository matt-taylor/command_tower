# frozen_string_literal: true

module CommandTower
  module Schema
    module User
      module Show
        class Request < JsonSchematize::Generator
          # GET endpoint - no request body validation needed
        end
      end
    end
  end
end
