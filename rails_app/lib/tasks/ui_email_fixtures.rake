# frozen_string_literal: true

namespace :command_tower do
  namespace :ui do
    desc "Write the email fixtures to spec/fixtures/ui/email/<fixture>.html and .txt"
    task email_fixtures: :environment do
      require Rails.root.join("test/mailers/previews/ui_document_preview").to_s

      UiDocumentPreview.write_all
      puts "Wrote #{UiDocumentPreview.fixtures.length} email fixtures to #{UiDocumentPreview::OUTPUT_DIR}"
    end
  end
end
