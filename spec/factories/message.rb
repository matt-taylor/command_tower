# frozen_string_literal: true

FactoryBot.define do
  factory :message do
    user { create(:user) }

    title { Faker::Lorem.sentence(word_count: 3) }
    text { Faker::Lorem.paragraph(sentence_count: (3...15).to_a.sample) }
    viewed { false }
    message_blast { nil }
    pushed { false }
  end

  factory :message_blast do
    user { create(:user) }

    title { Faker::Lorem.sentence(word_count: 3) }
    text { Faker::Lorem.paragraph(sentence_count: (3...15).to_a.sample) }
    existing_users { false }
    new_users { false }

    after :create do |blast, options|
      if blast.existing_users
        User.all.each do |u|
          Message.create!(
            user: user,
            text: text,
            title: title,
            message_blast: blast,
          )
        end
      end
    end
  end
end
