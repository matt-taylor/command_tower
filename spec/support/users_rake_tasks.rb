# frozen_string_literal: true

module UsersRakeTasksSpecHelpers
  def run_task(name)
    task = Rake::Task["command_tower:users:#{name}"]
    task.reenable
    task.invoke
  end

  # Writes the stored value verbatim; User#email normalizes on assignment, even via update_columns.
  def seed_raw_email(user, value)
    User.where(id: user.id).update_all(["email = ?", value]) # rubocop:disable Rails/SkipsModelValidations
  end
end

RSpec.configure do |config|
  config.include UsersRakeTasksSpecHelpers, type: :task
end
