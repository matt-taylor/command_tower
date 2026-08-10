# frozen_string_literal: true

module CommandTower
  class Current < ActiveSupport::CurrentAttributes
    attribute :request_id
  end
end
