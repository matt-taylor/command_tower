# frozen_string_literal: true

RSpec.describe CommandTower::Services::Me::DeleteAccount do
  subject(:result) { described_class.call(user:, password:) }

  let(:stored_password) { "password1234abcdef" }
  let(:password) { stored_password }
  let(:user) do
    create(
      :user,
      username: "deleteaccount",
      email: "delete@example.com",
      password: stored_password,
      password_confirmation: stored_password
    )
  end

  it "tombstones the account" do
    expect(result).to be_success
    expect(user.reload.deleted_at).to be_present
  end

  context "when the password is wrong" do
    let(:password) { "not-the-password" }

    it "returns validation error" do
      expect(result).not_to be_success
      expect(result.errors.first).to be_a(CommandTower::Errors::ValidationError)
    end
  end

  context "when email is reused after deletion" do
    let(:original_email) { "reuse@example.com" }
    let(:user) do
      create(
        :user,
        username: "reuseuser",
        email: original_email,
        password: stored_password,
        password_confirmation: stored_password
      )
    end

    before { result }

    it "allows a new registration with the same email" do
      register = CommandTower::Services::Auth::Register.call(
        first_name: "New",
        last_name: "Person",
        username: "newreuseuser",
        email: original_email,
        password: stored_password,
        password_confirmation: stored_password
      )

      expect(register).to be_success
      expect(register.data[:user].id).not_to eq(user.id)
    end
  end
end
