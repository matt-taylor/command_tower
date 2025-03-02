# frozen_string_literal: true

require "command_tower/authorization"
require "command_tower/schema"
require "logger"

module CommandTower
  class Engine < ::Rails::Engine
    isolate_namespace CommandTower

    # Run after Rails loads the initializes and environment files
    # Ensures User has already set their desired config before we lock this down
    config.after_initialize do
      db_rake_task = defined?(Rake) && (Rake.application.top_level_tasks.any? { |task| task =~ /db:/ } rescue nil)
      if db_rake_task
        # Because we call the Database during configuration setup,
        # We want to skip calling the DB during a DB migration
      else
        # ensure defaults are instantiated and all variables are assigned
        CommandTower.config.class_composer_assign_defaults!(children: true)

        unless Rails.env.test?
          # Now that we can confirm all variables are defined, freeze all objects an their children
          CommandTower.config.class_composer_freeze_objects!(behavior: :raise, children: true)
        end
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
      CommandTower::Authorization::Role.roles_reset!
      CommandTower::Authorization::Entity.entities_reset!
      CommandTower::Authorization.mapped_controllers_reset!

      CommandTower::Authorization.default_defined!
    end
  end
end
