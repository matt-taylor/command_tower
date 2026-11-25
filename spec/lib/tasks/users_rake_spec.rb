# frozen_string_literal: true

require "rake"

RSpec.describe "command_tower:users email tasks", type: :task do
  let!(:first_user) { create(:user) }
  let!(:second_user) { create(:user) }

  before do
    Rake::Task.define_task(:environment) unless Rake::Task.task_defined?(:environment)
    %w[email_duplicates add_email_unique_index normalize_emails].each do |name|
      full_name = "command_tower:users:#{name}"
      Rake::Task[full_name].clear if Rake::Task.task_defined?(full_name)
    end
    load File.expand_path("../../../lib/tasks/users.rake", __dir__)
    allow($stdout).to receive(:puts)
    allow($stderr).to receive(:puts)
    # MySQL DDL commits implicitly, so the index calls are stubbed rather than run.
    allow(ActiveRecord::Base.connection).to receive(:index_exists?).and_return(false)
    allow(ActiveRecord::Base.connection).to receive(:add_index)
  end

  context "with no duplicates" do
    it "reports none" do
      run_task("email_duplicates")
      expect($stdout).to have_received(:puts).with(/No duplicate emails/)
    end

    it "adds the unique index" do
      run_task("add_email_unique_index")
      expect(ActiveRecord::Base.connection).to have_received(:add_index).with(:users, :email, unique: true)
    end
  end

  context "with a seeded duplicate" do
    before { seed_raw_email(second_user, first_user.email.upcase) }

    it "reports the group by ids without printing the address", :aggregate_failures do
      run_task("email_duplicates")
      expect($stdout).to have_received(:puts).with(/2 users, ids=#{first_user.id},#{second_user.id}/)
      expect($stdout).not_to have_received(:puts).with(/#{Regexp.escape(first_user.email)}/)
    end

    it "skips the index with a warning", :aggregate_failures do
      expect { run_task("add_email_unique_index") }.to output(/skipped unique index/).to_stderr
      expect(ActiveRecord::Base.connection).not_to have_received(:add_index)
    end

    context "when subscribed to the skip metric" do
      let(:subscription) { capture_notifications(/email_unique_index_skipped/) }

      before { subscription }

      after { unsubscribe_notifications(subscription.last) }

      it "publishes a metric event" do
        run_task("add_email_unique_index")
        expect(subscription.first.first[:payload]).to include(duplicate_groups: 1)
      end
    end

    it "skips colliding rows when normalizing", :aggregate_failures do
      run_task("normalize_emails")
      expect(second_user.reload.email).to eq(first_user.email.upcase)
      expect($stdout).to have_received(:puts).with(/skipped 1 collision/)
    end
  end

  context "with blank emails" do
    before do
      seed_raw_email(first_user, "")
      seed_raw_email(second_user, "")
    end

    it "reports them as a group" do
      run_task("email_duplicates")
      expect($stdout).to have_received(:puts).with(/\(blank\): 2 users/)
    end
  end

  context "with a non-colliding unnormalized email" do
    before { seed_raw_email(second_user, "  Mixed.Case@Example.com ") }

    it "normalizes it", :aggregate_failures do
      run_task("normalize_emails")
      expect(second_user.reload.email).to eq("mixed.case@example.com")
      expect($stdout).to have_received(:puts).with(/Normalized 1 email/)
    end

    it "leaves it alone on a dry run" do
      ENV["DRY_RUN"] = "1"
      run_task("normalize_emails")
      expect(second_user.reload.email).to eq("  Mixed.Case@Example.com ")
    ensure
      ENV.delete("DRY_RUN")
    end
  end
end
