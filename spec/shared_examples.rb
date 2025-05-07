# frozen_string_literal: true

RSpec.shared_examples "CommandTower::Schema::Error:InvalidArguments examples" do |status, message, keys|
  context "with shared example -- InvalidArguments" do
    let(:response_body) { JSON.parse(response.body) }

    it "sets #{status} status" do
      subject

      expect(response.status).to eq(status)
    end

    it "sets message" do
      subject

      expect(response_body["message"]).to include(*Array(message))
    end

    it "sets invalid_arguments" do
      subject

      safe_keys = Array(keys).map(&:to_s)
      safe_keys.each do |k|
        expect(response_body["invalid_arguments"]).to include(
          hash_including(
          "schema" => be_a(String),
          "argument" => k,
          "reason" => be_a(String),
        ))
      end
    end

    it "sets invalid_argument_keys" do
      subject

      safe_keys = Array(keys).map(&:to_s)
      expect(response_body["invalid_argument_keys"]).to include(*safe_keys)
    end
  end
end

RSpec.shared_examples "Invalid/Missing JWT token on required route" do
  context "with shared example -- UnAuthenticated User(JWT token)" do
    let(:response_body) { JSON.parse(response.body) }

    context "with token missing" do
       before { unset_jwt_token! }

       it "sets 401 status" do
         subject
         expect(response.status).to eq(401)
       end

       it "sets invalid message" do
         subject
         expect(response_body["message"]).to eq("Bearer token missing")
       end

       it "does not set expire header" do
         subject
         expect(response.header[CommandTower::ApplicationController::AUTHENTICATION_EXPIRE_HEADER]).to_not be_present
       end
    end

    context "with valid token" do
      let(:user) { create(:user) }
      let!(:verifier_token) { user.retreive_verifier_token! }
      let(:payload) { { generated_at:, user_id: user.id, verifier_token: } }
      let(:token) { CommandTower::Jwt::Encode.(payload:).token }
      let(:generated_at) { Time.now.to_i }
      before { set_jwt_token!(user:, token:) }

      context "when token is expired" do
        let(:generated_at) { (CommandTower.config.jwt.ttl - 1.day).to_i }

        it "sets 401 status" do
          subject
          expect(response.status).to eq(401)
        end

        it "sets invalid message" do
          subject
          expect(response_body["message"]).to eq("Unauthorized Access. Invalid Authorization token")
        end

        it "does not set expire header" do
          subject
          expect(response.header[CommandTower::ApplicationController::AUTHENTICATION_EXPIRE_HEADER]).to_not be_present
        end
      end

      context "when token verifier does not match" do
        let(:verifier_token) { SecureRandom.alphanumeric(32) }

        it "sets 401 status" do
          subject
          expect(response.status).to eq(401)
        end

        it "sets invalid message" do
          subject
          expect(response_body["message"]).to eq("Unauthorized Access. Token is no longer valid")
        end

        it "does not set expire header" do
          subject
          expect(response.header[CommandTower::ApplicationController::AUTHENTICATION_EXPIRE_HEADER]).to_not be_present
        end
      end
    end
  end
end

RSpec.shared_examples "UnAuthorized Access on Controller Action" do
  context "with shared example -- UnAuthorized User" do
    it "sets 403 status" do
      subject
      expect(response.status).to eq(403)
    end

    it "sets invalid message" do
      subject
      expect(response_body["message"]).to eq("Unauthorized Access. Incorrect User Privileges")
    end
  end
end

RSpec.shared_examples "Services Pagination examples" do |klass|
  context "with shared example -- Services pagination" do
    let(:service_records) do
      object = call
      records_chain.each { object = object.try(_1) }
      object
    end
    let(:service_records_count) do
      object = call
      records_count.each { object = object.try(_1) }
      object
    end
    let(:pagination) { { limit:, cursor:, page: } }
    let(:limit) { nil }
    let(:cursor) { nil }
    let(:page) { nil }

    context "with records" do
      let(:count) { CommandTower.config.pagination.limit * 3 }

      it "succeeds" do
        expect(call.success?).to eq(true)
      end

      it "returns default limit / default cursor / default page" do
        expect(service_records_count).to eq(CommandTower.config.pagination.limit)
        expect(service_records.map(&:id).sort).to eq(records[0...CommandTower.config.pagination.limit].map(&:id).sort)

        call
      end

      context "with custom limit" do
        let(:limit) { 5 }

        it "succeeds" do
          expect(call.success?).to eq(true)
        end

        it "returns custom limit / default cursor / default page" do
          expect(service_records_count).to eq(limit)
          expect(service_records.map(&:id).sort).to eq(records[0...limit].map(&:id).sort)

          call
        end

        context "with custom cursor" do
          let(:cursor) { 4 }

          it "succeeds" do
            expect(call.success?).to eq(true)
          end

          it "returns custom limit / custom cursor / default page" do
            expect(service_records_count).to eq(limit)
            expect(service_records.map(&:id).sort).to eq(records[cursor...cursor+limit].map(&:id).sort)

            call
          end
        end

        context "with custom page" do
          let(:page) { 2 }

          it "succeeds" do
            expect(call.success?).to eq(true)
          end

          it "returns custom limit / default cursor / custom page" do
            expect(service_records_count).to eq(limit)

            start_i = limit
            end_i = start_i + limit
            expect(service_records.map(&:id).sort).to eq(records[start_i...end_i].map(&:id).sort)

            call
          end
        end
      end

      context "with custom cursor" do
        let(:cursor) { 5 }

        it "succeeds" do
          expect(call.success?).to eq(true)
        end

        it "returns default limit / custom cursor / default page" do
          expect(service_records_count).to eq(CommandTower.config.pagination.limit)
          limit = cursor + CommandTower.config.pagination.limit
          expect(service_records.map(&:id).sort).to eq(records[cursor...limit].map(&:id).sort)

          call
        end

        context "when cursor + limit is over record count" do
          let(:cursor) { count - (CommandTower.config.pagination.limit - 1) }

          it "succeeds" do
            expect(call.success?).to eq(true)
          end

          it "returns default limit / custom cursor / default page" do
            equality = klass == ::User ? CommandTower.config.pagination.limit : CommandTower.config.pagination.limit - 1
            records_mapping = if klass == ::User
              (records[cursor..-1].map(&:id) + [user.id]).sort
            else
              records[cursor..-1].map(&:id).sort
            end
            expect(service_records_count).to eq(equality)
            expect(service_records.map(&:id).sort).to eq(records_mapping)

            call
          end
        end

        context "when cursor is over record count" do
          let(:cursor) { count + 1 }

          it "succeeds" do
            expect(call.success?).to eq(true)
          end

          it "returns default limit / custom cursor / default page" do
            expect(service_records_count).to eq(0)
            expect(service_records.map(&:id).sort).to eq([])

            call
          end
        end
      end

      context "with custom page" do
        let(:page) { 2 }

        it "succeeds" do
          expect(call.success?).to eq(true)
        end

        it "returns default limit / default cursor / custom page" do
          expect(service_records_count).to eq(CommandTower.config.pagination.limit)

          start_i = CommandTower.config.pagination.limit
          end_i = CommandTower.config.pagination.limit * page
          expect(service_records.map(&:id).sort).to eq(records[start_i...end_i].map(&:id).sort)

          call
        end

        context "with custom cursor" do
          let(:cursor) { 5 }
          let(:limit) { 7 }

          it "cursor overrides page" do
            expect(service_records_count).to eq(limit)

            start_i = cursor
            end_i = start_i + limit
            expect(service_records.map(&:id).sort).to eq(records[start_i...end_i].map(&:id).sort)

            call
          end
        end
      end

      context "with corrected input values" do
        context "when incorrect limit" do
          let(:limit) { -1 }

          it "succeeds" do
            expect(call.success?).to eq(true)
          end

          it "returns 1 limit" do
            expect(service_records_count).to eq(1)

            call
          end
        end

        context "when incorrect cursor" do
          let(:cursor) { -1 }
          let(:limit) { 2 }

          it "succeeds" do
            expect(call.success?).to eq(true)
          end

          it "returns correct cursor" do
            expect(service_records.map(&:id)).to include(*records[0..1].map(&:id))

            call
          end
        end

        context "when incorrect page" do
          let(:page) { -1 }

          it "succeeds" do
            expect(call.success?).to eq(true)
          end

          it "returns correct cursor" do
            expect(service_records.map(&:id)).to include(*records[0..1].map(&:id))

            call
          end
        end
      end
    end

    context "without records" do
      let(:count) { 0 }

      it "succeeds" do
        expect(call.success?).to eq(true)
      end
    end
  end
end
