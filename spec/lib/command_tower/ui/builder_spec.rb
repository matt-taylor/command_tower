# frozen_string_literal: true

RSpec.describe CommandTower::UI::Builder, :aggregate_failures do
  let(:ui) { CommandTower::UI }

  before { allow(CommandTower.config.ui).to receive(:image_hosts).and_return(["img.example.com"]) }

  describe "UI.document" do
    context "with nested primitives" do
      let(:document) do
        ui.document(text_fallback: "Class canceled") do |d|
          d.card(surface: :raised, padding: :xl) do |c|
            c.stack(gap: :lg, align: :start) do |s|
              s.text("Class ", d.strong("canceled"), variant: :heading_m)
              s.divider
              s.key_value do |kv|
                kv.item "When", kv.time(at: "2025-12-04T14:00:00Z", zone: "America/Los_Angeles"), icon: "calendar"
                kv.item "Where", "Studio B"
              end
              s.button "View classes", action: d.navigate(path: "/classes"), variant: :primary
            end
          end
        end
      end
      let(:stack) { document.as_json["root"]["children"].first }

      it "validates" do
        expect(document.validate!).to equal(document)
      end

      it "emits stack tokens and ordered children" do
        expect(stack).to include("type" => "stack", "gap" => "lg", "align" => "start")
        expect(stack["children"].pluck("type")).to eq(%w[text divider key_value button])
      end

      it "emits spans and key_value time values" do
        expect(stack["children"][0]["spans"]).to eq(
          [{ "type" => "text", "text" => "Class " }, { "type" => "text", "text" => "canceled", "strong" => true }]
        )
        expect(stack["children"][2]["items"].first["value"]).to include("type" => "time", "format" => "short")
      end
    end

    context "when compared with a hand-built document" do
      let(:built) { ui.document(text_fallback: "x") { |d| d.stack(gap: :xs) { |s| s.text("Hi", text_tone: :muted) } } }
      let(:by_hand) do
        ui::Document.new(
          root: ui::Nodes::Stack.new(gap: "xs", children: [ui::Nodes::Text.new(spans: ["Hi"], text_tone: "muted")]),
          text_fallback: "x"
        )
      end

      it "matches the wire shape" do
        expect(built.as_json).to eq(by_hand.as_json)
      end
    end

    context "with a configured default zone" do
      let(:document) { ui.document(text_fallback: "x") { |d| d.time(at: Time.utc(2025, 12, 4, 14)) } }

      before { allow(CommandTower.config.ui).to receive(:default_zone).and_return("America/New_York") }

      it "applies it to time" do
        expect(document.as_json["root"]).to include("zone" => "America/New_York", "at" => "2025-12-04T14:00:00Z")
      end
    end

    describe "root node" do
      it "is required" do
        expect { ui.document { |_d| nil } }.to raise_error(ui::InvalidDocumentError) { |e|
          expect(e.details).to eq([{ path: "root", code: "root_required" }])
        }
      end

      it "must be single" do
        expect { ui.document { |d| 2.times { d.divider } } }.to raise_error(ui::InvalidDocumentError) { |e|
          expect(e.details).to eq([{ path: "root", code: "multiple_roots" }])
        }
      end
    end
  end

  describe "primitives" do
    context "with every leaf primitive" do
      let(:document) do
        ui.document(text_fallback: "x") do |d|
          d.stack do |s|
            s.badge "New", tone: :success
            s.image src: "https://img.example.com/a.png", aspect: 1.5, alt: "A"
            s.banner "Heads up", title: "Notice", tone: :warning
            s.avatar initials: "AB", size: :lg
            s.stat_tile value: "12", label: "Spots", tone: :accent, icon: "users"
            s.code value: "SECRET-123", label: "Check-in", format: :qr
            s.time at: "2025-12-04T14:00:00Z", zone: "UTC", format: :long, label: :never
          end
        end
      end

      it "validates" do
        expect(document.validate!).to equal(document)
      end

      it "emits each wire type in order" do
        expect(document.as_json["root"]["children"].pluck("type")).to eq(
          %w[badge image banner avatar stat_tile code time]
        )
      end
    end

    context "with a component" do
      let(:document) do
        ui.document(text_fallback: "x") do |d|
          d.component(key: "ct.thing", variant: "wide", data: { id: 1 }) { |c| c.text("fallback") }
        end
      end

      it "builds the fallback from the block" do
        expect(document.validate!.as_json["root"]).to include(
          "type" => "component", "key" => "ct.thing", "fallback" => include("type" => "text")
        )
      end
    end

    context "with a link span" do
      let(:document) do
        ui.document(text_fallback: "x") do |d|
          d.text("See ", d.link("this", action: d.navigate(href: "https://example.com")))
        end
      end

      it "carries the navigate action" do
        expect(document.as_json["root"]["spans"].last).to include(
          "type" => "link",
          "action" => { "type" => "navigate",
                        "destination" => { "kind" => "external", "href" => "https://example.com" } }
        )
      end
    end

    context "with a fragment" do
      let(:fragment) do
        Class.new do
          def initialize(title:)
            @title = title
          end

          def compose(builder)
            builder.text(@title, variant: :title)
          end
        end
      end
      let(:document) { ui.document(text_fallback: "x") { |d| d.fragment(fragment, title: "From fragment") } }

      it "expands into primitives at the call site" do
        expect(document.as_json["root"]["spans"]).to eq([{ "type" => "text", "text" => "From fragment" }])
      end
    end
  end

  describe "unknown tokens" do
    it "raises InvalidTokenError in test without echoing the value" do
      expect { ui.document { |d| d.stack(gap: :huge, &:divider) } }
        .to raise_error(ui::InvalidTokenError) { |e|
          expect(e.message).to include("root.gap")
          expect(e.message).not_to include("huge")
        }
    end

    it "reports the nested node path" do
      expect { ui.document { |d| d.stack { |s| s.badge("x", tone: :loud) } } }
        .to raise_error(ui::InvalidTokenError, /root\.children\[0\]\.tone/)
    end

    context "when not in a local environment" do
      let(:logger) { instance_double(Logger) }
      let(:logged) { [] }
      let(:document) do
        ui.document(text_fallback: "x") do |d|
          d.stack(gap: :huge, align: :sideways) { |s| s.badge("x", tone: :loud) }
        end
      end

      before do
        allow(Rails.env).to receive(:local?).and_return(false)
        allow(Rails).to receive(:logger).and_return(logger)
        allow(logger).to receive(:warn) { |&message| logged << message.call }
        document
      end

      it "falls back to the default token and omits tokens without one" do
        expect(document.as_json["root"]).to include("gap" => "md")
        expect(document.as_json["root"]).not_to have_key("align")
        expect(document.as_json["root"]["children"].first).to include("tone" => "neutral")
      end

      it "logs node path and code only" do
        expect(logged.length).to eq(3)
        expect(logged).to all(include("unknown_token"))
        expect(logged.join).not_to match(/huge|loud|sideways/)
      end
    end
  end
end
