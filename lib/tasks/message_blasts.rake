# frozen_string_literal: true

namespace :command_tower do
  namespace :message_blasts do
    desc "Generate random message blasts"
    task generate: :environment do
      puts "\n=== CommandTower Message Blast Generator ==="
      puts

      # Get number of blasts to generate
      print "How many message blasts to generate? (default: 5): "
      count_input = $stdin.gets.chomp
      count = count_input.blank? ? 5 : count_input.to_i
      raise "Count must be a positive integer" if count <= 0

      # Get available users
      users = ::User.all
      if users.empty?
        puts "\n✗ No users found in the database. Please create at least one user first."
        raise "No users available"
      end

      puts "\nGenerating #{count} message blast(s)..."
      puts

      # Sample titles and texts for variety
      sample_titles = [
        "Welcome to our platform!",
        "Important Update",
        "New Features Available",
        "Maintenance Notice",
        "Special Offer",
        "System Upgrade",
        "Community News",
        "Product Launch",
        "Security Alert",
        "Thank You Message"
      ]

      sample_texts = [
        "We're excited to have you on board! Check out our latest features.",
        "This is an important update regarding our services. Please review carefully.",
        "We've added new features that you might find useful. Explore them now!",
        "Scheduled maintenance will occur this weekend. Services may be temporarily unavailable.",
        "Don't miss out on our special offer! Limited time only.",
        "We've upgraded our systems for better performance and reliability.",
        "Stay connected with our community and get the latest news.",
        "We're launching a new product that we think you'll love!",
        "This is a security alert. Please review your account settings.",
        "Thank you for being a valued member of our community!"
      ]

      success_count = 0
      error_count = 0

      count.times do |i|
        begin
          # Randomly select a user
          user = users.sample

          # Generate random title and text
          title = sample_titles.sample
          text = sample_texts.sample

          # Determine target audience
          # Logic:
          # - If both false: neither (invalid state, but we'll allow it for testing)
          # - If existing_users true: targets existing users
          # - If new_users true: targets new users
          # - If both true: targets all users

          # Randomly decide on target audience
          target_choice = rand(4) # 0-3 for 4 different combinations

          case target_choice
          when 0
            # All users (both true)
            existing_users = true
            new_users = true
            target_desc = "all users"
          when 1
            # Only existing users
            existing_users = true
            new_users = false
            target_desc = "existing users only"
          when 2
            # Only new users
            existing_users = false
            new_users = true
            target_desc = "new users only"
          when 3
            # Neither (edge case for testing)
            existing_users = false
            new_users = false
            target_desc = "no users (testing edge case)"
          end

          # Create the message blast using the service
          result = CommandTower::InboxService::Blast::Upsert.(
            user: user,
            title: title,
            text: text,
            existing_users: existing_users,
            new_users: new_users
          )

          if result.success?
            message_blast = result.message_blast
            success_count += 1
            puts "✓ [#{i + 1}/#{count}] Created message blast ##{message_blast.id}"
            puts "  Title: #{title}"
            puts "  Created by: #{user.username || user.email} (ID: #{user.id})"
            puts "  Target: #{target_desc}"
            puts "  Existing users: #{existing_users}, New users: #{new_users}"
            puts
          else
            error_count += 1
            puts "✗ [#{i + 1}/#{count}] Failed to create message blast:"
            puts "  Error: #{result.msg}"
            if result.respond_to?(:invalid_argument_hash) && result.invalid_argument_hash
              result.invalid_argument_hash.each do |field, errors|
                puts "  - #{field}: #{Array(errors).join(', ')}"
              end
            end
            puts
          end
        rescue StandardError => e
          error_count += 1
          puts "✗ [#{i + 1}/#{count}] Error creating message blast: #{e.message}"
          puts
        end
      end

      puts "=== Summary ==="
      puts "Successfully created: #{success_count}"
      puts "Errors: #{error_count}"
      puts "Total: #{count}"
    end
  end
end
