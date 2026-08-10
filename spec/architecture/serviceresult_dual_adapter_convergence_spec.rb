# frozen_string_literal: true

RSpec.describe "ServiceResult dual-adapter convergence architecture" do
  REMOVED_LEGACY_SERVICE_BASE = %w[
    CommandTower::AdminService::Users
    CommandTower::UserAttributes::Roles
    CommandTower::Jwt::TimeDelayToken
    CommandTower::LoginStrategy::PlainText::ValidIdentifier
  ].freeze

  CONVERTED_ABSENT_CONSTANTS = [
    "CommandTower::LoginStrategy::PlainText::Create",
    "CommandTower::LoginStrategy::PlainText::Login",
    "CommandTower::LoginStrategy::PlainText::ChangePassword",
    "CommandTower::LoginStrategy::PlainText::PasswordReset::Send",
    "CommandTower::LoginStrategy::PlainText::PasswordReset::Validate",
    "CommandTower::LoginStrategy::PlainText::PasswordReset::Reset",
    "CommandTower::Identity::Phone::Set",
    "CommandTower::Identity::Phone::Clear",
    "CommandTower::Identity::PhoneVerification::Send",
    "CommandTower::Identity::PhoneVerification::Verify",
    "CommandTower::Identity::PhoneVerification::Generate",
    "CommandTower::UserAttributes::Modify",
    "CommandTower::Services::Auth::SignupRateLimiter",
    "CommandTower::Services::Auth::PasswordRecovery::RateLimitPolicy",
  ].freeze

  MODERN_AUTH_ME_ACCOUNT_SERVICES = [
    CommandTower::Services::Auth::Register,
    CommandTower::Services::Auth::PlainText::Login,
    CommandTower::Services::Me::ChangePassword,
    CommandTower::Services::Me::UpdateName,
    CommandTower::Services::Auth::EmailVerification::Send,
    CommandTower::Services::Auth::EmailVerification::Verify,
    CommandTower::Services::Auth::PasswordReset::Send,
    CommandTower::Services::Auth::PasswordReset::Validate,
    CommandTower::Services::Auth::PasswordReset::Reset,
    CommandTower::Services::Auth::UsernameAvailability,
    CommandTower::Services::Auth::AuthorizeRequest,
    CommandTower::Services::Account::UpdatePhone,
    CommandTower::Services::Account::ClearPhone,
    CommandTower::Services::Account::PhoneVerification::Send,
    CommandTower::Services::Account::PhoneVerification::Verify,
  ].freeze

  let(:constant_defined?) do
    lambda do |name|
      Object.const_get(name)
      true
    rescue NameError
      false
    end
  end

  it "keeps ApplicationService as ServiceBase subclass (Interactor kernel)" do
    expect(CommandTower::Services::ApplicationService).to be < CommandTower::ServiceBase
  end

  context "AuthenticateSession source" do
    let(:source) do
      File.read(
        CommandTower::Engine.root.join(
          "app/services/command_tower/services/auth/authenticate_session.rb",
        ),
      )
    end

    it "does not type AuthenticateSession against Workflows::Auth::RequestContext" do
      expect(source).not_to include("Workflows::Auth::RequestContext")
      expect(source).to include("CommandTower::Auth::RequestContext")
    end
  end

  it "uses Auth::RequestContext outside the workflow namespace" do
    expect(defined?(CommandTower::Auth::RequestContext)).to eq("constant")
    expect(defined?(CommandTower::Workflows::Auth::RequestContext)).to be_nil
  end

  it "makes rate-limit entrypoints ApplicationServices" do
    expect(CommandTower::Services::RateLimits::Check).to be < CommandTower::Services::ApplicationService
    expect(CommandTower::Services::Auth::SignupRateLimits::CheckTokenIssue)
      .to be < CommandTower::Services::ApplicationService
    expect(CommandTower::Services::Auth::SignupRateLimits::CheckAvailability)
      .to be < CommandTower::Services::ApplicationService
    expect(CommandTower::Services::Auth::SignupRateLimits::CheckRegister)
      .to be < CommandTower::Services::ApplicationService
    expect(CommandTower::Services::Auth::PasswordRecovery::RateLimits::CheckTokenIssue)
      .to be < CommandTower::Services::ApplicationService
    expect(CommandTower::Services::Auth::PasswordRecovery::RateLimits::CheckSend)
      .to be < CommandTower::Services::ApplicationService
  end

  it "removes converted dual-adapter ServiceBase capability constants" do
    CONVERTED_ABSENT_CONSTANTS.each do |name|
      expect(constant_defined?.call(name)).to eq(false), "expected #{name} to be absent after 4.4 absorb"
    end
  end

  it "retypes JWT primitives off ServiceBase" do
    expect(CommandTower::Jwt::Encode).not_to be < CommandTower::ServiceBase
    expect(CommandTower::Jwt::Decode).not_to be < CommandTower::ServiceBase
    expect(CommandTower::Jwt::LoginCreate).not_to be < CommandTower::ServiceBase
    expect(CommandTower::Jwt::AuthenticateUser).not_to be < CommandTower::ServiceBase
  end

  it "does not leave modern Auth/Me/Account ApplicationServices calling parallel LoginStrategy/Identity ServiceBase bodies" do
    MODERN_AUTH_ME_ACCOUNT_SERVICES.each do |klass|
      expect(File.read(Object.const_source_location(klass.name).first)).not_to match(/LoginStrategy::PlainText::(Create|Login|ChangePassword)\b/)
      expect(File.read(Object.const_source_location(klass.name).first)).not_to match(/Identity::Phone::(Set|Clear)\.call/)
      expect(File.read(Object.const_source_location(klass.name).first)).not_to match(/Identity::PhoneVerification::(Send|Verify|Generate)\.call/)
      expect(File.read(Object.const_source_location(klass.name).first)).not_to match(/UserAttributes::Modify\b/)
    end
  end

  it "removes retired legacy ServiceBase stacks from Phase 7.2 cleanup" do
    REMOVED_LEGACY_SERVICE_BASE.each do |name|
      expect(constant_defined?.call(name)).to eq(false), "expected #{name} removed in Phase 7.2"
    end
  end

  it "keeps UserAttributes::Mutate as a non-ServiceBase PORO used by Me" do
    expect(defined?(CommandTower::UserAttributes::Mutate)).to eq("constant")
    expect(CommandTower::UserAttributes::Mutate).not_to be < CommandTower::ServiceBase
  end
end
