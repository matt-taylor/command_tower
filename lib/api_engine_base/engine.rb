# frozen_string_literal: true

require "api_engine_base/authorization"
require "api_engine_base/schema"

module ApiEngineBase
  class Engine < ::Rails::Engine
    isolate_namespace ApiEngineBase

    # Run after Rails loads the initializes and environment files
    # Ensures User has already set their desired config before we lock this down
    config.after_initialize do
      # ensure defaults are instantiated and all variables are assigned
      ApiEngineBase.config.class_composer_assign_defaults!(children: true)

      unless Rails.env.test?
        # Now that we can confirm all variables are defined, freeze all objects an their children
        ApiEngineBase.config.class_composer_freeze_objects!(behavior: :raise, children: true)
      end
    end


    ####
    # Bug: @matt-taylor
    # RBAC code memoizes the controller object into a class variable
    # In development when code changes, all classes get reloaded
    # Inherently, this causes the `object_id` of the class to change
    # This means the memoized class is no longer equal to the newly reloaded class
    # NOTE: This is only a problem on reload! in development. Not an issue in Production
    # Once this is fixed, it can go into a regular initializer and does not need to get re-computed on each reload
    ###
    # Potential solution:
    # => Don't store the object as the comparison key
    # => Or...When doing comparisons, convert everything to a string for comparison
    #    Changes to names should be infrequent/should have a full app restart

    # Add all RBAC based role definitions prior to fork/loading
    # Load once use forever
    config.to_prepare do
      ApiEngineBase::Authorization::Role.roles_reset!
      ApiEngineBase::Authorization::Entity.entities_reset!
      ApiEngineBase::Authorization.mapped_controllers_reset!

      ApiEngineBase::Authorization.default_defined!
    end
  end
end
