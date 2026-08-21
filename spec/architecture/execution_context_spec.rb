# frozen_string_literal: true

RSpec.describe "CommandTower Execution Context architecture" do
  let(:engine_root) { CommandTower::Engine.root }
  let(:production_ruby) { Dir[engine_root.join("{app,lib}/**/*.rb").to_s] }

  let(:execution_files) do
    [
      engine_root.join("lib/command_tower/current.rb"),
      engine_root.join("lib/command_tower/execution.rb"),
      engine_root.join("app/controllers/concerns/command_tower/execution/http_boundary.rb"),
      engine_root.join("app/jobs/command_tower/execution/job_boundary.rb"),
      engine_root.join("app/controllers/command_tower/application_controller.rb"),
      engine_root.join("app/jobs/command_tower/application_job.rb")
    ]
  end

  context "when scanning execution-boundary production files" do
    let(:asn_offenders) do
      execution_files.filter_map do |path|
        path.to_s if File.read(path).include?("ActiveSupport::Notifications")
      end
    end

    let(:thread_offenders) do
      execution_files.filter_map do |path|
        path.to_s if File.read(path).include?("Thread.current")
      end
    end

    it { expect(asn_offenders).to eq([]) }
    it { expect(thread_offenders).to eq([]) }
  end

  let(:ambient_storage_offenders) do
    production_ruby.filter_map do |path|
      source = File.read(path)
      path.to_s if source.match?(/Thread\.current|Fiber\.current/)
    end
  end

  let(:current_attributes_offenders) do
    production_ruby.filter_map do |path|
      next if path.end_with?("/current.rb")

      path.to_s if File.read(path).include?("ActiveSupport::CurrentAttributes")
    end
  end

  it "does not use Thread or Fiber bags for ambient execution identity" do
    expect(ambient_storage_offenders).to eq([])
  end

  let(:current_source) { File.read(engine_root.join("lib/command_tower/current.rb")) }
  let(:request_context_source) do
    File.read(engine_root.join("app/services/command_tower/auth/request_context.rb"))
  end

  it "has a single CurrentAttributes subclass" do
    expect(current_attributes_offenders).to eq([])
    expect(current_source).to include("class Current < ActiveSupport::CurrentAttributes")
  end

  it "keeps Auth::RequestContext as a PORO" do
    expect(request_context_source).not_to include("CurrentAttributes")
    expect(request_context_source).to include("class RequestContext")
  end
end
