# frozen_string_literal: true

RSpec.describe CommandTower::UI::RequiredFacts::Verdict, :aggregate_failures do
  let(:metadata) do
    { "class_name" => "Barre Basics", "starts_at" => "2026-11-24T14:00:00Z", "studio_zone" => "America/Los_Angeles" }
  end
  let(:render_zone) { "America/New_York" }
  let(:verdict) do
    ->(texts, facts) { described_class.call(texts:, metadata:, required_facts: facts, render_zone:) }
  end

  it "passes a :text fact found in the text and fails one that is missing" do
    expect(verdict.call({ sms: "Barre Basics canceled", email: "Canceled" }, [{ key: :class_name, matcher: :text }]))
      .to eq([{ channel: :sms, fact_key: :class_name, passed: true },
              { channel: :email, fact_key: :class_name, passed: false }])
  end

  it "checks a :time fact in the zone named by a metadata key" do
    expect(
      verdict.call({ ok: "Tue, Nov 24, 6:00 AM PT", wrong: "9:00 AM ET" },
                   [{ key: :starts_at, matcher: :time, zone: "studio_zone" }]).pluck(:passed)
    ).to eq([true, false])
  end

  context "with the render zone" do
    let(:user) { verdict.call({ a: "9:00 AM ET" }, [{ key: :starts_at, matcher: :time, zone: :user }]) }
    let(:none) { verdict.call({ a: "9:00 AM ET" }, [{ key: :starts_at, matcher: :time }]) }

    it "uses the render zone for :user and for a missing zone" do
      expect(user.first[:passed]).to be(true)
      expect(none.first[:passed]).to be(true)
    end
  end

  context "with a host matcher" do
    let(:seen) { [] }
    let(:matcher) do
      lambda do |text:, metadata:, t:|
        at = "2026-11-24T14:00:00Z"
        seen.push(text, metadata["class_name"], t.call(at, zone: "UTC", format: :time, label: :never))
      end
    end

    it "calls it with text:, metadata: and t:" do
      expect(verdict.call({ push: "hello" }, [{ key: :class_name, matcher: }]))
        .to eq([{ channel: :push, fact_key: :class_name, passed: false }])
      expect(seen).to eq(["hello", "Barre Basics", "2:00 PM"])
    end
  end

  it "skips an optional fact with no metadata value" do
    expect(verdict.call({ sms: "x" }, [{ key: :room, matcher: :text, optional: true }])).to eq([])
  end

  it "fails a required fact with no metadata value" do
    expect(verdict.call({ sms: "x" }, [{ key: :room, matcher: :text }])).to eq(
      [{ channel: :sms, fact_key: :room, passed: false }]
    )
  end
end
