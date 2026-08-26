# frozen_string_literal: true

RSpec.describe CommandTower::Services::Auth::TombstoneUser do
  subject(:result) { described_class.call(user:) }

  let(:stored_password) { "password1234abcdef" }
  let(:user) do
    create(
      :user,
      username: "tombstoneuser",
      email: "tombstone@example.com",
      first_name: "Pat",
      last_name: "Example",
      password: stored_password,
      password_confirmation: stored_password
    )
  end

  it "marks the user deleted and scrubs PII" do
    expect(result).to be_success

    user.reload
    expect(user.deleted_at).to be_present
    expect(user.email).to eq(User.tombstone_email_for(user.id))
    expect(user.username).to eq(User.tombstone_username_for(user.id))
    expect(user.first_name).to eq("")
    expect(user.last_name).to eq("")
    expect(user.authenticate(stored_password)).to be_falsey
  end

  context "when already deleted" do
    before { described_class.call(user:) }

    it "is idempotent" do
      expect(result).to be_success
      expect(result.data[:changed]).to be(false)
    end
  end
end
