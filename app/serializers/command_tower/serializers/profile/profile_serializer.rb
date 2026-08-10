# frozen_string_literal: true

module CommandTower
  module Serializers
    module Profile
      class ProfileSerializer
        def self.serialize(user)
          CommandTower::Serializers::Auth::UserSerializer.serialize(user)
        end
      end
    end
  end
end
