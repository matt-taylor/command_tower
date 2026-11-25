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

    # Groups by the normalized form so the result does not depend on the column collation.
    # Blank emails (default "") count as one group like any other value. Read-only; prints ids, not addresses.
    email_duplicate_groups = lambda do
      normalized = "LOWER(TRIM(email))"
      ::User.group(Arel.sql(normalized)).having("COUNT(*) > 1").pluck(Arel.sql(normalized)).index_with do |key|
        ::User.where("#{normalized} = ?", key).order(:id).pluck(:id)
      end
    end

    desc "Report users sharing an email (collation-aware, includes blank emails). Read-only."
    task email_duplicates: :environment do
      groups = email_duplicate_groups.call
      if groups.empty?
        puts "No duplicate emails found."
      else
        groups.each do |email, ids|
          label = email.empty? ? "(blank)" : "email##{ids.first}"
          puts "#{label}: #{ids.size} users, ids=#{ids.join(',')}"
        end
        puts "#{groups.size} duplicate email group(s) found."
      end
    end

    desc "Add a unique index on users.email; skips with a warning and a metric event when duplicates exist"
    task add_email_unique_index: :environment do
      connection = ::ActiveRecord::Base.connection
      if connection.index_exists?(:users, :email, unique: true)
        puts "Unique index on users.email already exists."
      else
        groups = email_duplicate_groups.call
        if groups.empty?
          connection.add_index(:users, :email, unique: true)
          puts "Added unique index on users.email."
        else
          warn "WARNING: skipped unique index on users.email; #{groups.size} duplicate email group(s) exist. " \
               "Run command_tower:users:email_duplicates and resolve them first."
          CommandTower::Events.publish(
            category: :auth,
            name: "email_unique_index_skipped",
            payload: { duplicate_groups: groups.size }
          )
        end
      end
    end

    desc "Normalize stored emails (strip + downcase); skips and reports collisions. DRY_RUN=1 to only report."
    task normalize_emails: :environment do
      dry_run = ENV["DRY_RUN"].present?
      taken = ::User.pluck(:id, :email).each_with_object(Hash.new { |h, k| h[k] = [] }) do |(id, email), memo|
        memo[email.to_s.strip.downcase] << id
      end
      changed = 0
      skipped = 0

      ::User.find_each(batch_size: 1_000) do |user|
        normalized = user.email.to_s.strip.downcase
        next if normalized == user.email

        if taken[normalized] != [user.id]
          puts "Skipped user #{user.id}: normalized email collides with another user."
          skipped += 1
          next
        end

        user.update_columns(email: normalized) unless dry_run # rubocop:disable Rails/SkipsModelValidations
        changed += 1
      end

      puts "#{dry_run ? 'Would normalize' : 'Normalized'} #{changed} email(s); skipped #{skipped} collision(s)."
    end
  end
end
