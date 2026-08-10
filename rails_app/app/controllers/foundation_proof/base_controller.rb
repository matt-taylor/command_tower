# frozen_string_literal: true

module FoundationProof
  class BaseController < ActionController::API
    include CommandTower::Api::ApplicationResponseRenderer
  end
end
