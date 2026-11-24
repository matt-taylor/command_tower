# frozen_string_literal: true

require "tmpdir"

# Helpers for specs of the MessageDefinition seal checks. Expects the including group to define
# `definition` (a valid MessageDefinition subclass stubbed as SealCheckSample) and `invalid_error`.
module MessageDefinitionSealHelper
  def declaration(**overrides)
    build_notification_type_declaration(message: "SealCheckSample", **overrides)
  end

  def seal_with(*declarations)
    register_and_seal_notification_types(*declarations)
  end

  def expect_seal_error(pattern, *declarations)
    expect { seal_with(*(declarations.presence || [declaration])) }.to raise_error(invalid_error, pattern)
  end

  # Replaces SealCheckSample with a subclass whose `slots` returns the given Hash.
  def stub_slots(result)
    stub_const("SealCheckSample", Class.new(definition) do
      define_method(:slots) { |**| result }
    end)
  end

  def host_root_with_type_template(dir, key)
    type_dir = File.join(dir, "app/views/command_tower/messaging/rendering", key)
    FileUtils.mkdir_p(type_dir)
    FileUtils.touch(File.join(type_dir, "email.html.erb"))
    allow(Rails).to receive(:root).and_return(Pathname.new(dir))
  end
end

RSpec.configure do |config|
  config.include MessageDefinitionSealHelper, :message_definition_seal
end
