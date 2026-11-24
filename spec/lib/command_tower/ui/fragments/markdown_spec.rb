# frozen_string_literal: true

RSpec.describe CommandTower::UI::Fragments::Markdown, :aggregate_failures do
  include MarkdownFragmentHelpers

  let(:nodes) { texts(render(source)) }

  describe "blocks" do
    it "emits a stack of body paragraphs" do
      expect(render("One\n\nTwo")).to include("type" => "stack", "gap" => "md")
      expect(texts(render("One\n\nTwo")).map { |node| plain(node) }).to eq(%w[One Two])
      expect(texts(render("One\n\nTwo")).pluck("variant")).to eq(%w[body body])
    end

    it "treats a soft line break as a space and a hard break as a newline" do
      expect(plain(texts(render("a\nb")).first)).to eq("a b")
      expect(plain(texts(render("a  \nb")).first)).to eq("a\nb")
    end

    context "with headings" do
      let(:source) { "# H1\n\n## H2\n\n### H3\n\n#### H4" }

      it "maps headings to title, subtitle and body" do
        expect(nodes.pluck("variant")).to eq(%w[title title subtitle body])
        expect(nodes[2]).to include("textTone" => "secondary")
      end
    end

    context "with an unordered list" do
      let(:list) { render("- one\n* two\n\n+ three")["children"].find { |node| node["type"] == "stack" } }

      it "bullets items with a tight item gap" do
        expect(list["gap"]).to eq("xs")
        expect(list["children"].map { |node| plain(node) }).to include("• one", "• two")
      end
    end

    context "with an ordered list" do
      let(:list) { render("1. a\n2. b\n3. c")["children"].first }

      it "keeps ordered list numbers" do
        expect(list["children"].map { |node| plain(node) }).to eq(["1. a", "2. b", "3. c"])
      end
    end

    context "with nested lists" do
      let(:list) { render("- a\n  - b\n    - c")["children"].first }

      it "flattens them to one level" do
        expect(list["children"].map { |node| plain(node) }).to eq(["• a", "• b", "• c"])
        expect(FragmentTree.types(list).count("stack")).to eq(1)
      end
    end

    context "with a table" do
      let(:source) { "| A | B |\n|---|---|\n| 1 | 2 |" }

      it "turns each row into one paragraph with cells joined by a middle dot" do
        expect(nodes.map { |node| plain(node) }).to eq(["A · B", "1 · 2"])
      end
    end

    it "drops horizontal rules and keeps the text around them" do
      expect(texts(render("above\n\n---\n\nbelow")).map { |node| plain(node) }).to eq(%w[above below])
    end

    context "with code and quotes" do
      let(:source) { "> quoted\n\n```\nline1\nline2\n```\n\nuse `x` here" }

      it "keeps them as plain text" do
        expect(nodes.map { |node| plain(node) }).to eq(["quoted", "line1\nline2", "use x here"])
      end
    end

    context "with emphasis" do
      let(:spans) { spans_of("*em* and **bold** and __also__") }

      it "renders emphasis as plain text and strong as a strong span" do
        expect(spans.select { |span| span["strong"] }.pluck("text")).to eq(%w[bold also])
        expect(spans.pluck("text").join).to eq("em and bold and also")
      end
    end

    it "treats strikethrough and task lists as literal text" do
      expect(plain(texts(render("~~gone~~")).first)).to eq("~~gone~~")
    end
  end

  describe "links" do
    context "with safe schemes" do
      let(:source) do
        "[a](https://example.com/x) [b](mailto:me@example.com) [c](tel:+15551234567) [d](/schedule) " \
          "<https://example.org>"
      end
      let(:targets) do
        link_actions(source).map { |action| action["destination"].values_at("href", "path").compact.first }
      end

      it "keeps https, mailto, tel and internal links as navigate actions" do
        expect(targets).to contain_exactly("https://example.com/x", "mailto:me@example.com", "tel:+15551234567",
                                           "/schedule", "https://example.org")
      end
    end

    context "with unsafe schemes" do
      let(:source) do
        "[a](javascript:alert(1)) [b](data:text/html,x) [c](http://example.com) [d](ftp://x.test) [e](//evil.test)"
      end

      it "downgrades javascript:, data:, http: and other schemes to the label" do
        expect(link_actions(source)).to be_empty
        expect(plain(nodes.first)).to eq("a b c d e")
      end
    end

    it "does not link bare URLs" do
      expect(link_actions("see https://example.com now")).to be_empty
    end
  end

  describe "raw HTML and images" do
    context "with tags" do
      let(:source) { "<div><p>Hello <b>there</b></p></div>\n\nplain <span onclick=\"x()\">span</span>" }

      it "removes tags and keeps their text" do
        expect(nodes.map { |node| plain(node) }.join(" ")).to include("Hello there").and include("plain span")
        expect(nodes.flat_map { |node| node["spans"] }.pluck("text").join).not_to include("<")
      end
    end

    context "with script and style" do
      let(:source) do
        "before\n\n<script>alert('x')</script>\n\n<style>p{color:red}</style>\n\nafter <script>evil()</script>end"
      end
      let(:output) { nodes.map { |node| plain(node) }.join(" ") }

      it "drops script and style with their content" do
        expect(output).to include("before").and include("after")
        expect(output).not_to match(/alert|color|evil/)
      end
    end

    context "with an image-only body" do
      let(:builder) do
        CommandTower::UI::Builder.new.tap { |b| b.fragment(described_class, source: "![alt](https://example.com/i.png)") }
      end

      it "drops images and renders nothing" do
        expect(plain(texts(render("text ![alt](https://example.com/i.png) more")).first)).to eq("text more")
        expect(builder.roots).to be_empty
      end
    end

    it "keeps a comment out of the output" do
      expect(texts(render("a <!-- hidden --> b")).map { |node| plain(node) }.join).not_to include("hidden")
    end
  end

  describe "limits" do
    context "with a long paragraph" do
      let(:source) { Array.new(900) { "word" }.join(" ") }

      it "splits at word boundaries under the string limit" do
        expect(nodes.length).to be > 1
        expect(nodes.map { |node| plain(node).length }).to all(be < 2000)
        expect(nodes.map { |node| plain(node) }.join(" ").split).to all(eq("word"))
      end
    end

    context "with an unbroken string" do
      let(:source) { "x" * 4500 }

      it "splits at the limit" do
        expect(nodes.map { |node| plain(node).length }).to all(be < 2000)
        expect(nodes.sum { |node| plain(node).length }).to eq(4500)
      end
    end

    context "with many links" do
      let(:source) { Array.new(120) { |i| "[l#{i}](/p#{i})" }.join(" ") }

      it "keeps each text under the span cap" do
        expect(nodes.map { |node| node["spans"].length }).to all(be <= CommandTower::UI::Limits::MAX_SPANS)
      end
    end

    context "when the body exceeds the node budget" do
      let(:budgeted) { texts(render(Array.new(40) { |i| "secret paragraph #{i}" }.join("\n\n"), node_budget: 20)) }

      before { allow(Rails.logger).to receive(:warn) }

      it "cuts with a final ellipsis and logs counts only" do
        expect(plain(budgeted.last)).to eq("…")
        expect(Rails.logger).to have_received(:warn) { |&block| expect(block.call).not_to include("secret") }
      end
    end

    context "with a large body" do
      let(:source) { Array.new(400) { |i| "para #{i}" }.join("\n\n") }

      it "stays valid within the default budget" do
        expect(plain(nodes.last)).to eq("…")
      end
    end
  end

  describe "inputs" do
    it "requires a source" do
      expect { described_class.new(source: "") }
        .to raise_error(CommandTower::UI::InvalidFragmentError, /source:blank/)
    end

    it "emits only primitives" do
      # "link" is a span type inside text nodes, not a node.
      expect(FragmentTree.non_primitive_types(render("# t\n\n- a\n\n[l](/x)")) - %w[link]).to be_empty
    end
  end
end
