# frozen_string_literal: true

# `load`, not `require`: after a dev code reload `require` is a no-op, so `class User` below would
# reopen a fresh constant with no superclass (NoMethodError: undefined method 'where' for class User).
load CommandTower::Engine.root.join("app/models/user.rb").to_s

class User
  def am_i_a_user?
    true
  end
end
