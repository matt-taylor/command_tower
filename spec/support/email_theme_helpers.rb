# frozen_string_literal: true

require "tmpdir"

# Helpers for specs of the email theme (palette and token file). Included by `:email_theme`.
module EmailThemeHelper
  # Sets `CommandTower.config.email_theme` values for the block, restoring them afterwards.
  def with_email_theme(**values)
    theme = CommandTower.config.email_theme
    previous = values.keys.index_with { |key| theme.public_send(key) }
    values.each { |key, value| theme.public_send(:"#{key}=", value) }
    yield
  ensure
    previous.each { |key, value| theme.public_send(:"#{key}=", value) }
  end

  # The directory created by the `:tmpdir` around hook.
  def tmpdir
    @tmpdir
  end

  # Writes `content` to a ui_tokens.json inside `dir` and returns its path.
  def write_tokens(dir, content)
    path = File.join(dir, "ui_tokens.json")
    File.write(path, content)
    path
  end
end

RSpec.configure do |config|
  config.include EmailThemeHelper, :email_theme

  config.around(:each, :tmpdir) do |example|
    Dir.mktmpdir do |dir|
      @tmpdir = dir
      example.run
    end
  end
end
