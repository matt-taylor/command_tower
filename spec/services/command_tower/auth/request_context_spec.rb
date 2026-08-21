# frozen_string_literal: true

RSpec.describe CommandTower::Auth::RequestContext do
  let(:request) { instance_double(ActionDispatch::Request) }
  let(:response) { ActionDispatch::Response.new }

  subject(:ctx) { described_class.from(request, response) }

  it "holds request and response from .from" do
    expect(ctx.request).to eq(request)
    expect(ctx.response).to eq(response)
  end

  it { expect(described_class.instance_methods(false)).not_to include(:execution_uuid) }
end
