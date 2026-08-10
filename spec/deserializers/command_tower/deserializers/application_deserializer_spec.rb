# frozen_string_literal: true

RSpec.describe CommandTower::Deserializers::ApplicationDeserializer do
  let(:deserializer_class) do
    Class.new(described_class) do
      const_set(:Input, Data.define(:name, :count, :scope)) unless const_defined?(:Input, false)

      def call(params)
        name_raw = unwrap(fetch_param(params, :name, :firstName, "name", "firstName"))
        return name_raw if deserializer_result?(name_raw)

        name = unwrap(require_string(name_raw, field: "name"))
        return name if deserializer_result?(name)

        count_raw = unwrap(fetch_param(params, :count, "count"))
        return count_raw if deserializer_result?(count_raw)

        count = if count_raw.nil?
                  1
                else
                  unwrapped = unwrap(require_integer(count_raw, code: "invalid_count", field: "count", min: 1, max: 10))
                  return unwrapped if deserializer_result?(unwrapped)

                  unwrapped
                end

        scope_raw = unwrap(fetch_param(params, :scope, "scope"))
        return scope_raw if deserializer_result?(scope_raw)

        scope = if scope_raw.nil? || (scope_raw.is_a?(String) && scope_raw.strip.empty?)
                  "inbox"
                else
                  unwrapped = unwrap(one_of(scope_raw, allowed: %w[inbox archived], code: "invalid_scope", field: "scope"))
                  return unwrapped if deserializer_result?(unwrapped)

                  unwrapped
                end

        optional = unwrap(optional_string(params[:note], default: "none"))
        return optional if deserializer_result?(optional)

        success(self.class::Input.new(name: name, count: count, scope: scope))
      end
    end
  end

  describe ".call" do
    subject(:result) { deserializer_class.call(params) }

    context "with valid params" do
      let(:params) { { name: "Ada", count: "3", scope: "archived" } }

      it "returns success with typed input" do
        expect(result).to be_success
        expect(result.input.name).to eq("Ada")
        expect(result.input.count).to eq(3)
        expect(result.input.scope).to eq("archived")
      end
    end

    context "with camelCase alias" do
      let(:params) { { "firstName" => "Ada" } }

      it "fetches the alias" do
        expect(result).to be_success
        expect(result.input.name).to eq("Ada")
      end
    end

    context "when required string is missing" do
      let(:params) { {} }

      it "returns normalized failure errors" do
        expect(result).to be_failure
        expect(result.errors).to contain_exactly(
          hash_including(code: "missing_required_fields", field: "name")
        )
      end
    end

    context "when integer is out of bounds" do
      let(:params) { { name: "Ada", count: 99 } }

      it "fails with invalid_count" do
        expect(result).to be_failure
        expect(result.errors.first[:code]).to eq("invalid_count")
      end
    end

    context "when one_of rejects the value" do
      let(:params) { { name: "Ada", scope: "trash" } }

      it "fails with invalid_scope" do
        expect(result).to be_failure
        expect(result.errors.first[:code]).to eq("invalid_scope")
      end
    end

    context "when failure is given a Hash" do
      let(:hash_failure_class) do
        Class.new(described_class) do
          def call(_params)
            failure(errors: { message: "invalid_credentials" })
          end
        end
      end

      subject(:result) { hash_failure_class.call({}) }

      it "wraps the Hash in an Array without converting it to pairs" do
        expect(result).to be_failure
        expect(result.errors).to eq([{ message: "invalid_credentials" }])
      end
    end
  end
end
