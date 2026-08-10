# frozen_string_literal: true

RSpec.describe CommandTower::Clients::Transport::FaradayAdapter do
  let(:build_test_adapter) do
    lambda do |stubs|
      connection = Faraday.new { |faraday| faraday.adapter(:test, stubs) }
      described_class.new(connection: connection)
    end
  end

  let(:request) do
    lambda do |**attrs|
      CommandTower::Clients::Transport::Request.build(
        method: attrs.fetch(:method, :get),
        url: attrs.fetch(:url, "https://example.test/resource"),
        headers: attrs.fetch(:headers, {}),
        body: attrs.fetch(:body, nil),
        query: attrs.fetch(:query, {}),
        timeout: attrs[:timeout]
      )
    end
  end

  describe "#initialize" do
    subject(:adapter) { described_class.new(config: CommandTower::Clients::Transport::FaradayConfig.from_env) }

    it "builds a ConnectionPool backed Faraday adapter" do
      expect(adapter.pool).to be_a(ConnectionPool)
      expect(adapter.config).to be_a(CommandTower::Clients::Transport::FaradayConfig)
    end
  end

  describe "connection pooling" do
    context "when checking connections out of the pool" do
      let(:stubs) do
        Faraday::Adapter::Test::Stubs.new do |stub|
          stub.get("/a") { [ 200, {}, "a" ] }
          stub.get("/b") { [ 200, {}, "b" ] }
        end
      end
      let(:adapter) { build_test_adapter.call(stubs) }
      let(:seen) { [] }

      before do
        allow(adapter.pool).to receive(:with).and_wrap_original do |original, *args, &block|
          original.call(*args) do |connection|
            seen << connection
            block.call(connection)
          end
        end
        adapter.call(request.call(url: "https://example.test/a"))
        adapter.call(request.call(url: "https://example.test/b"))
      end

      it "checks Faraday connections out of a ConnectionPool for each call" do
        expect(adapter.pool).to be_a(ConnectionPool)
        expect(seen.size).to eq(2)
        expect(seen.uniq.size).to eq(1)
        stubs.verify_stubbed_calls
      end
    end

    context "when connections are created by the pool" do
      subject(:adapter) { described_class.new(pool_size: 1) }

      it "installs net_http_persistent on connections created by the pool" do
        adapter.pool.with do |connection|
          expect(connection.builder.adapter).to eq(Faraday::Adapter::NetHttpPersistent)
        end
      end
    end

    context "when the connection pool times out" do
      let(:stubs) { Faraday::Adapter::Test::Stubs.new }
      let(:adapter) { build_test_adapter.call(stubs) }

      before do
        allow(adapter.pool).to receive(:with).and_raise(ConnectionPool::TimeoutError)
      end

      subject(:invoke) { adapter.call(request.call) }

      it "maps ConnectionPool timeouts to Transport::Error" do
        expect { invoke }.to raise_error(
          CommandTower::Clients::Transport::Error,
          /connection pool timeout|TimeoutError|timed out/i
        )
      end
    end
  end

  describe "#call" do
    %i[get post put patch delete].each do |method|
      context "when executing #{method.upcase}" do
        let(:stubs) do
          Faraday::Adapter::Test::Stubs.new do |stub|
            stub.public_send(method, "/resource") do |env|
              expect(env.method).to eq(method)
              [ 200, { "Content-Type" => "text/plain" }, "#{method}-ok" ]
            end
          end
        end
        let(:adapter) { build_test_adapter.call(stubs) }

        subject(:result) { adapter.call(request.call(method: method)) }

        it "executes #{method.upcase} through one run_request path" do
          expect(result).to be_a(CommandTower::Clients::Transport::Response)
          expect(result.status).to eq(200)
          expect(result.body).to eq("#{method}-ok")
          expect(result.duration_ms).to be_a(Integer)
          stubs.verify_stubbed_calls
        end
      end
    end

    context "when merging request.query with an existing URL query string" do
      let(:stubs) do
        Faraday::Adapter::Test::Stubs.new do |stub|
          stub.get("/items") do |env|
            params = Rack::Utils.parse_nested_query(env.url.query)
            expect(params).to eq("existing" => "true", "page" => "2")
            [ 200, {}, "ok" ]
          end
        end
      end
      let(:adapter) { build_test_adapter.call(stubs) }

      before do
        adapter.call(
          request.call(
            url: "https://example.test/items?existing=true",
            query: { page: 2 }
          )
        )
      end

      it "merges request.query with an existing URL query string" do
        stubs.verify_stubbed_calls
      end
    end

    context "when forwarding request headers" do
      let(:stubs) do
        Faraday::Adapter::Test::Stubs.new do |stub|
          stub.get("/resource") do |env|
            expect(env.request_headers["X-Trace"]).to eq("abc")
            [ 200, {}, "ok" ]
          end
        end
      end
      let(:adapter) { build_test_adapter.call(stubs) }

      before { adapter.call(request.call(headers: { "X-Trace" => "abc" })) }

      it "forwards request headers" do
        stubs.verify_stubbed_calls
      end
    end

    context "when encoding a Hash body without Content-Type" do
      let(:stubs) do
        Faraday::Adapter::Test::Stubs.new do |stub|
          stub.post("/resource") do |env|
            expect(env.request_headers["Content-Type"]).to eq("application/json")
            expect(JSON.parse(env.body)).to eq("name" => "Ada")
            [ 201, {}, '{"id":1}' ]
          end
        end
      end
      let(:adapter) { build_test_adapter.call(stubs) }

      subject(:result) { adapter.call(request.call(method: :post, body: { name: "Ada" })) }

      it "JSON-encodes Hash bodies and sets Content-Type when absent" do
        expect(result.status).to eq(201)
        stubs.verify_stubbed_calls
      end
    end

    context "when a Hash body has an explicit Content-Type" do
      let(:stubs) do
        Faraday::Adapter::Test::Stubs.new do |stub|
          stub.post("/resource") do |env|
            expect(env.request_headers["Content-Type"]).to eq("application/vnd.custom+json")
            expect(JSON.parse(env.body)).to eq("a" => 1)
            [ 200, {}, "ok" ]
          end
        end
      end
      let(:adapter) { build_test_adapter.call(stubs) }

      before do
        adapter.call(
          request.call(
            method: :post,
            body: { a: 1 },
            headers: { "Content-Type" => "application/vnd.custom+json" }
          )
        )
      end

      it "does not override an explicit Content-Type for Hash bodies" do
        stubs.verify_stubbed_calls
      end
    end

    context "when the body is a String" do
      let(:stubs) do
        Faraday::Adapter::Test::Stubs.new do |stub|
          stub.post("/resource") do |env|
            expect(env.body).to eq("raw-payload")
            [ 200, {}, "ok" ]
          end
        end
      end
      let(:adapter) { build_test_adapter.call(stubs) }

      before { adapter.call(request.call(method: :post, body: "raw-payload")) }

      it "passes String bodies through unchanged" do
        stubs.verify_stubbed_calls
      end
    end

    context "when Faraday raises a timeout error" do
      let(:stubs) do
        Faraday::Adapter::Test::Stubs.new do |stub|
          stub.get("/resource") { raise Faraday::TimeoutError, "timed out" }
        end
      end
      let(:adapter) { build_test_adapter.call(stubs) }

      subject(:invoke) { adapter.call(request.call) }

      it "maps Faraday timeout errors to Transport::Error" do
        expect { invoke }.to raise_error(
          CommandTower::Clients::Transport::Error,
          /timed out/
        )
      end
    end

    context "when Faraday raises a connection failure" do
      let(:stubs) do
        Faraday::Adapter::Test::Stubs.new do |stub|
          stub.get("/resource") { raise Faraday::ConnectionFailed, "refused" }
        end
      end
      let(:adapter) { build_test_adapter.call(stubs) }

      subject(:invoke) { adapter.call(request.call) }

      it "maps Faraday connection failures to Transport::Error" do
        expect { invoke }.to raise_error(
          CommandTower::Clients::Transport::Error,
          /refused/
        )
      end
    end

    context "when Faraday raises a non-transport error" do
      let(:stubs) do
        Faraday::Adapter::Test::Stubs.new do |stub|
          stub.get("/resource") { raise Faraday::ParsingError, "bad parse" }
        end
      end
      let(:adapter) { build_test_adapter.call(stubs) }

      subject(:invoke) { adapter.call(request.call) }

      it "does not map arbitrary Faraday errors to Transport::Error" do
        expect { invoke }.to raise_error(Faraday::ParsingError)
      end
    end

    context "when a per-request timeout is provided" do
      let(:seen_timeout) { [] }
      let(:stubs) do
        Faraday::Adapter::Test::Stubs.new do |stub|
          stub.get("/resource") do |env|
            seen_timeout << env.request.timeout
            [ 200, {}, "ok" ]
          end
        end
      end
      let(:adapter) { build_test_adapter.call(stubs) }

      before { adapter.call(request.call(timeout: 7)) }

      it "propagates per-request timeout onto the Faraday request options" do
        expect(seen_timeout.first).to eq(7)
        stubs.verify_stubbed_calls
      end
    end
  end
end
