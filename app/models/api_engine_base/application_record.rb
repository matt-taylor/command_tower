# frozen_string_literal: true

module ApiEngineBase
  class ApplicationRecord < ActiveRecord::Base
    self.abstract_class = true
  end
end
