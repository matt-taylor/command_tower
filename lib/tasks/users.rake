# frozen_string_literal: true

namespace :command_tower do
  namespace :users do
    desc "Create a new user with username, email, password, and optional roles"
    task create: :environment do
      # Initialize authorization to load available roles
      begin
        CommandTower::Authorization.default_defined! if CommandTower::Authorization.respond_to?(:default_defined!)
      rescue StandardError => e
        puts "Warning: Could not initialize authorization roles: #{e.message}"
        puts "Continuing without role selection..."
      end

      puts "\n=== CommandTower User Creation ==="
      puts

      # Get basic user information
      print "Username: "
      username = $stdin.gets.chomp
      raise "Username cannot be blank" if username.blank?

      print "Email: "
      email = $stdin.gets.chomp
      raise "Email cannot be blank" if email.blank?

      print "Password: "
      password = $stdin.noecho(&:gets).chomp
      puts
      raise "Password cannot be blank" if password.blank?

      print "First Name: "
      first_name = $stdin.gets.chomp
      raise "First name cannot be blank" if first_name.blank?

      print "Last Name: "
      last_name = $stdin.gets.chomp
      raise "Last name cannot be blank" if last_name.blank?

      # Check if user should be admin
      print "Is this an admin user? (y/n): "
      is_admin = $stdin.gets.chomp.downcase == "y"

      # Get available roles
      roles_to_assign = []
      available_roles = []

      begin
        available_roles = CommandTower::Authorization::Role.roles.keys.sort
      rescue StandardError => e
        puts "Warning: Could not load available roles: #{e.message}"
      end

      if is_admin
        if available_roles.include?("admin")
          roles_to_assign << "admin"
        else
          puts "Warning: 'admin' role is not available in the RBAC configuration."
        end
      end

      # Allow selection of additional roles if any are available
      if available_roles.any?
        puts "\nAvailable RBAC Roles:"
        available_roles.each_with_index do |role, index|
          begin
            role_obj = CommandTower::Authorization::Role.roles[role]
            description = role_obj&.description || "No description"
            puts "  #{index + 1}. #{role} - #{description}"
          rescue StandardError
            puts "  #{index + 1}. #{role}"
          end
        end

        puts "\nSelect additional roles (enter numbers separated by commas, or press Enter to skip):"
        print "Roles: "
        role_selection = $stdin.gets.chomp

        unless role_selection.blank?
          selected_indices = role_selection.split(",").map(&:strip).map(&:to_i)
          selected_indices.each do |index|
            if index > 0 && index <= available_roles.length
              selected_role = available_roles[index - 1]
              roles_to_assign << selected_role unless roles_to_assign.include?(selected_role)
            end
          end
        end
      else
        puts "\nNo additional RBAC roles are configured."
      end

      # Create the user
      puts "\nCreating user..."
      user = ::User.new(
        username: username,
        email: email,
        password: password,
        first_name: first_name,
        last_name: last_name,
        roles: roles_to_assign.uniq
      )

      if user.save
        puts "\n✓ User created successfully!"
        puts "  Username: #{user.username}"
        puts "  Email: #{user.email}"
        puts "  Name: #{user.full_name}"
        puts "  Roles: #{user.roles.empty? ? 'none' : user.roles.join(', ')}"
        puts "  ID: #{user.id}"
      else
        puts "\n✗ Failed to create user:"
        user.errors.full_messages.each do |error|
          puts "  - #{error}"
        end
        raise "User creation failed"
      end
    end
  end
end
