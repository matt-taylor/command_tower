# frozen_string_literal: true

RSpec.describe ApiEngineBase::ServiceBase do
  before do


    # instance.define_singleton_method(:call) do
    #   # send(key_name)
    # end

    allow(klass).to receive(:new).and_return(instance)
    allow(instance).to receive(:log_warn)
  end

  let(:validation_hash) { { key_name => metadata } }
  let(:metadata) { { delegation: } }
  let(:delegation) { true }
  let(:klass) { Class.new(described_class) }
  let(:instance) { klass.new(context_values) }
  let(:context_values) { { key_name => value } }
  let(:value) { }
  let(:key_name) { Faker::Lorem.unique.word.to_sym }
  let(:key_name2) { Faker::Lorem.unique.word.to_sym }
  let(:composition_name) { Faker::Lorem.unique.word.to_sym }

  describe ".one_of" do
    subject(:one_of) do
      klass.one_of(composition_name, required:) do
        validation_hash.each do |key, metadata|
          klass.validate(key, **metadata)
        end
      end
    end

    let(:required) { true }
    let(:count) { 1 }
    let(:validation_hash) { super().merge(key_name2 => metadata) }

    context "with config failure" do
      context "when duplicated nested type" do
        subject(:one_of) do
          klass.one_of(composition_name, required:) do
            klass.one_of("#{composition_name}_anything", required:) do
              validation_hash.each do |key, metadata|
                klass.validate(key, **metadata)
              end
            end
          end
        end

        it do
          expect { one_of }.to raise_error(described_class::NestedDuplicateTypeError, /Duplicate Nested type's are not allowed/)
        end
      end

      context "with existing name" do
        subject(:one_of) do
          klass.one_of(composition_name, required:) do
            validation_hash.each do |key, metadata|
              klass.validate(key, **metadata)
            end
          end

          klass.one_of(composition_name, required:) do
            validation_hash.each do |key, metadata|
              klass.validate(:"#{key}_1", **metadata)
            end
          end
        end

        it do
          expect { one_of }.to raise_error(described_class::NameConflictError, /Name conflict for #{composition_name}/)
        end

        context "when duplicate validate key" do
          subject(:one_of) do
            klass.one_of(composition_name, required:) do
              klass.validate(composition_name, **metadata)
            end
          end

          it do
            expect { one_of }.to raise_error(described_class::NameConflictError, /Name conflict for #{composition_name}/)
          end
        end
      end
    end

    it "sets composition hash" do
      one_of

      expect(klass.compositions).to include(
        {
          composition_name => hash_including({
            type: :compose_exact,
            name: composition_name,
            keys: validation_hash.keys,
          })
        }
      )
    end
  end

  describe ".at_least_one" do
    subject(:at_least_one) do
      klass.at_least_one(composition_name, required:) do
        validation_hash.each do |key, metadata|
          klass.validate(key, **metadata)
        end
      end
    end

    let(:required) { true }
    let(:count) { 1 }
    let(:validation_hash) { super().merge(key_name2 => metadata) }

    context "with config failure" do
      context "when duplicated nested type" do
        subject(:at_least_one) do
          klass.at_least_one(composition_name, required:) do
            klass.at_least_one("#{composition_name}_anything", required:) do
              validation_hash.each do |key, metadata|
                klass.validate(key, **metadata)
              end
            end
          end
        end

        it do
          expect { at_least_one }.to raise_error(described_class::NestedDuplicateTypeError, /Duplicate Nested type's are not allowed/)
        end
      end

      context "with existing name" do
        subject(:at_least_one) do
          klass.at_least_one(composition_name, required:) do
            validation_hash.each do |key, metadata|
              klass.validate(key, **metadata)
            end
          end

          klass.at_least_one(composition_name, required:) do
            validation_hash.each do |key, metadata|
              klass.validate(:"#{key}_1", **metadata)
            end
          end
        end

        it do
          expect { at_least_one }.to raise_error(described_class::NameConflictError, /Name conflict for #{composition_name}/)
        end

        context "when duplicate validate key" do
          subject(:at_least_one) do
            klass.at_least_one(composition_name, required:) do
              klass.validate(composition_name, **metadata)
            end
          end

          it do
            expect { at_least_one }.to raise_error(described_class::NameConflictError, /Name conflict for #{composition_name}/)
          end
        end
      end
    end

    it "sets composition hash" do
      at_least_one

      expect(klass.compositions).to include(
        {
          composition_name => hash_including({
            type: :at_least,
            name: composition_name,
            keys: validation_hash.keys,
          })
        }
      )
    end
  end

  describe ".at_least" do
    subject(:at_least) do
      klass.at_least(count, composition_name, required:) do
        validation_hash.each do |key, metadata|
          klass.validate(key, **metadata)
        end
      end
    end

    let(:required) { true }
    let(:count) { 1 }
    let(:validation_hash) { super().merge(key_name2 => metadata) }

    context "with config failure" do
      context "with invalid count" do
        context "when less than 1" do
          let(:count) { 0 }

          it do
            expect { at_least }.to raise_error(described_class::CompositionValidationError, /Count must be greater than 0/)
          end
        end

        context "when more than key count" do
          let(:count) { validation_hash.length + 1 }

          it do
            expect { at_least }.to raise_error(described_class::CompositionValidationError, /Composition configuration error/)
          end
        end
      end

      context "when duplicated nested type" do
        subject(:at_least) do
          klass.at_least(count, composition_name, required:) do
            klass.at_least(count, "#{composition_name}_anything", required:) do
              validation_hash.each do |key, metadata|
                klass.validate(key, **metadata)
              end
            end
          end
        end

        it do
          expect { at_least }.to raise_error(described_class::NestedDuplicateTypeError, /Duplicate Nested type's are not allowed/)
        end
      end

      context "with existing name" do
        subject(:at_least) do
          klass.compose_exact(count, composition_name, required:) do
            validation_hash.each do |key, metadata|
              klass.validate(key, **metadata)
            end
          end

          klass.at_least(count, composition_name, required:) do
            validation_hash.each do |key, metadata|
              klass.validate(:"#{key}_1", **metadata)
            end
          end
        end

        it do
          expect { at_least }.to raise_error(described_class::NameConflictError, /Name conflict for #{composition_name}/)
        end

        context "when duplicate validate key" do
          subject(:at_least) do
            klass.at_least(count, composition_name, required:) do
              klass.validate(composition_name, **metadata)
            end
          end

          it do
            expect { at_least }.to raise_error(described_class::NameConflictError, /Name conflict for #{composition_name}/)
          end
        end
      end
    end

    it "sets composition hash" do
      at_least

      expect(klass.compositions).to include(
        {
          composition_name => hash_including({
            type: :at_least,
            name: composition_name,
            keys: validation_hash.keys,
          })
        }
      )
    end
  end

  describe ".at_most" do
    subject(:at_most) do
      klass.at_most(count, composition_name, required:) do
        validation_hash.each do |key, metadata|
          klass.validate(key, **metadata)
        end
      end
    end

    let(:required) { true }
    let(:count) { 1 }
    let(:validation_hash) { super().merge(key_name2 => metadata) }

    context "with config failure" do
      context "with invalid count" do
        let(:count) { 0 }

        it do
          expect { at_most }.to raise_error(described_class::CompositionValidationError, /Count must be greater than 0/)
        end
      end

      context "when duplicated nested type" do
        subject(:at_most) do
          klass.at_most(count, composition_name, required:) do
            klass.at_most(count, "#{composition_name}_anything", required:) do
              validation_hash.each do |key, metadata|
                klass.validate(key, **metadata)
              end
            end
          end
        end

        it do
          expect { at_most }.to raise_error(described_class::NestedDuplicateTypeError, /Duplicate Nested type's are not allowed/)
        end
      end

      context "with existing name" do
        subject(:at_most) do
          klass.at_most(count, composition_name, required:) do
            validation_hash.each do |key, metadata|
              klass.validate(key, **metadata)
            end
          end

          klass.at_most(count, composition_name, required:) do
            validation_hash.each do |key, metadata|
              klass.validate(:"#{key}_1", **metadata)
            end
          end
        end

        it do
          expect { at_most }.to raise_error(described_class::NameConflictError, /Name conflict for #{composition_name}/)
        end

        context "when duplicate validate key" do
          subject(:at_most) do
            klass.at_most(count, composition_name, required:) do
              klass.validate(composition_name, **metadata)
            end
          end

          it do
            expect { at_most }.to raise_error(described_class::NameConflictError, /Name conflict for #{composition_name}/)
          end
        end
      end
    end

    it "sets composition hash" do
      at_most

      expect(klass.compositions).to include(
        {
          composition_name => hash_including({
            type: :at_most,
            name: composition_name,
            keys: validation_hash.keys,
          })
        }
      )
    end
  end

  describe ".compose_exact" do
    subject(:compose_exact) do
      klass.compose_exact(count, composition_name, required:, delegation:) do
        validation_hash.each do |key, metadata|
          klass.validate(key, **metadata)
        end
      end
    end

    let(:required) { true }
    let(:count) { 1 }
    let(:validation_hash) { super().merge(key_name2 => metadata) }

    context "with config failure" do
      context "with invalid count" do
        context "when less than 1" do
          let(:count) { 0 }

          it do
            expect { compose_exact }.to raise_error(described_class::CompositionValidationError, /Count must be greater than 0/)
          end
        end

        context "when more than key count" do
          let(:count) { validation_hash.length + 1 }

          it do
            expect { compose_exact }.to raise_error(described_class::CompositionValidationError, /Composition configuration error/)
          end
        end
      end

      context "when duplicated nested type" do
        subject(:compose_exact) do
          klass.compose_exact(count, composition_name, required:, delegation:) do
            klass.compose_exact(count, "#{composition_name}_anything", required:, delegation:) do
              validation_hash.each do |key, metadata|
                klass.validate(key, **metadata)
              end
            end
          end
        end

        it do
          expect { compose_exact }.to raise_error(described_class::NestedDuplicateTypeError, /Duplicate Nested type's are not allowed/)
        end
      end

      context "with existing name" do
        subject(:compose_exact) do
          klass.compose_exact(count, composition_name, required:, delegation:) do
            validation_hash.each do |key, metadata|
              klass.validate(key, **metadata)
            end
          end

          klass.compose_exact(count, composition_name, required:, delegation:) do
            validation_hash.each do |key, metadata|
              klass.validate(:"#{key}_1", **metadata)
            end
          end
        end

        it do
          expect { compose_exact }.to raise_error(described_class::NameConflictError, /Name conflict for #{composition_name}/)
        end

        context "when duplicate validate key" do
          subject(:compose_exact) do
            klass.compose_exact(count, composition_name, required:, delegation:) do
              klass.validate(composition_name, **metadata)
            end
          end

          it do
            expect { compose_exact }.to raise_error(described_class::NameConflictError, /Name conflict for #{composition_name}/)
          end
        end
      end
    end

    it "sets composition hash" do
      compose_exact

      expect(klass.compositions).to include(
        {
          composition_name => hash_including({
            type: :compose_exact,
            name: composition_name,
            keys: validation_hash.keys,
          })
        }
      )
    end
  end

  describe "composition validations" do
    let(:one_of1) { Faker::Lorem.unique.word.to_sym }
    let(:one_of2) { Faker::Lorem.unique.word.to_sym }
    let(:one_of3) { Faker::Lorem.unique.word.to_sym }

    shared_examples "composition failure modes" do
      context "when raise" do
        before { klass.on_argument_validation :raise }

        it do
          expect { subject }.to raise_error(ApiEngineBase::ServiceBase::CompositionValidationError, /Composite Key failure for/)
        end
      end

      context "when log" do
        before { klass.on_argument_validation :log }

        it do
          expect { subject }.to_not raise_error
        end

        it "succeeds" do
          expect(subject.success?).to eq(true)
          expect(subject.invalid_arguments).to eq(true)
        end
      end

      context "when fail early" do
        before { klass.on_argument_validation :fail_early }

        it do
          expect { subject }.to_not raise_error
        end

        it "fails" do
          expect(subject.failure?).to eq(true)
          expect(subject.invalid_arguments).to eq(true)
        end
      end

      context "when not required" do
        let(:required) { false }
        let(:context_values) { {} }

        it do
          expect { subject }.to_not raise_error
        end

        it "succeeds" do
          expect(subject.success?).to eq(true)
          expect(subject.invalid_arguments).to eq(nil)
        end
      end
    end

    context "with at_most" do
      subject { klass.(**context_values) }

      before do
        klass.at_most(count, composition_name, required: required) do
          klass.validate(key_name)
          klass.validate(key_name2)
        end
      end

      let(:required) { true }
      let(:count) { 1 }
      let(:context_values) { { key_name => "value" } }

      it do
        expect { subject }.to_not raise_error
      end

      it "succeeds" do
        expect(subject.success?).to be(true)
      end

      context "when not provided" do
        let(:context_values) { {} }

        it do
          expect { subject }.to_not raise_error
        end

        it "does not set invalid arguments" do
          expect(subject.invalid_arguments).to be(nil)
        end
      end

      context "with failure" do
        let(:context_values) { super().merge(key_name2 => "value") }

        include_examples "composition failure modes"
      end
    end

    context "with at_least" do
      subject { klass.(**context_values) }

      before do
        klass.at_least(count, composition_name, required: required) do
          klass.validate(key_name)
          klass.validate(key_name2)
        end
      end

      let(:required) { true }
      let(:count) { 2 }
      let(:context_values) { { key_name => "value", key_name2 => "value" } }

      it do
        expect { subject }.to_not raise_error
      end

      it "succeeds" do
        expect(subject.success?).to be(true)
      end

      context "when not provided" do
        let(:context_values) { {} }

        it do
          expect { subject }.to raise_error(ApiEngineBase::ServiceBase::CompositionValidationError, /Composite Key failure for/)
        end
      end

      context "with failure" do
        let(:context_values) { { key_name => "value" } }

        include_examples "composition failure modes"
      end
    end

    context "with at_least_one" do
      subject { klass.(**context_values) }

      before do
        klass.at_least_one(composition_name, required: required) do
          klass.validate(key_name)
          klass.validate(key_name2)
        end
      end

      let(:required) { true }
      let(:context_values) { { key_name => "value", key_name2 => "value" } }

      it do
        expect { subject }.to_not raise_error
      end

      it "succeeds" do
        expect(subject.success?).to be(true)
      end

      context "when not provided" do
        let(:context_values) { {} }

        it do
          expect { subject }.to raise_error(ApiEngineBase::ServiceBase::CompositionValidationError, /Composite Key failure for/)
        end
      end

      context "with failure" do
        let(:context_values) { { } }

        include_examples "composition failure modes"
      end
    end

    context "with one_of" do
      subject { klass.(**context_values) }

      before do
        klass.one_of(composition_name, required: required) do
          klass.validate(key_name)
          klass.validate(key_name2)
        end
      end

      let(:required) { true }
      let(:context_values) { { key_name => "value" } }

      it do
        expect { subject }.to_not raise_error
      end

      it "delegates" do
        subject

        expect(instance.public_send(key_name)).to eq("value")
      end

      it "succeeds" do
        expect(subject.success?).to be(true)
      end

      context "when not provided" do
        let(:context_values) { {} }

        it do
          expect { subject }.to raise_error(ApiEngineBase::ServiceBase::CompositionValidationError, /Composite Key failure for/)
        end
      end

      context "with failure" do
        let(:context_values) { { key_name => "value", key_name2 => "value" } }

        include_examples "composition failure modes"
      end
    end

    context "with compose_exact" do
      subject { klass.(**context_values) }

      before do
        klass.compose_exact(count, composition_name, required: required) do
          klass.validate(key_name)
          klass.validate(key_name2)
        end
      end

      let(:count) { 2 }
      let(:required) { true }
      let(:context_values) { { key_name => "value", key_name2 => "value" } }

      it do
        expect { subject }.to_not raise_error
      end

      it "succeeds" do
        expect(subject.success?).to be(true)
      end

      context "when not provided" do
        let(:context_values) { {} }

        it do
          expect { subject }.to raise_error(ApiEngineBase::ServiceBase::CompositionValidationError, /Composite Key failure for/)
        end
      end

      context "with failure" do
        let(:context_values) { { } }

        include_examples "composition failure modes"
      end
    end
  end

  describe "validate options" do
    context "with default" do
      subject do
        klass.validate(key_name, **metadata)
      end
      let(:metadata) { super().merge(default: default_value) }
      let(:default_value) { "Hello" }

      it do
        expect { subject }.to_not raise_error
      end

      context "with is_a" do
        let(:metadata) { super().merge(is_a: String) }

        it do
          expect{ subject }.to_not raise_error
        end

        context "when fails" do
          let(:metadata) { super().merge(is_a: Integer) }

          it do
            expect { subject }.to raise_error(ApiEngineBase::ServiceBase::DefaultValueError, /Default value provided/)
          end
        end
      end

      context "with is_one" do
        let(:metadata) { super().merge(is_one: default_value) }
        it do
          expect{ subject }.to_not raise_error
        end

        context "when fails" do
          let(:metadata) { super().merge(is_one: "not the correct value") }

          it do
            expect { subject }.to raise_error(ApiEngineBase::ServiceBase::DefaultValueError, /Default value provided/)
          end
        end
      end
    end
  end

  describe "validations" do
    subject { klass.(context_values) }

    before do
      validation_hash.each do |key, metadata|
        klass.validate(key, **metadata)
      end
    end

    shared_examples "sharable validations" do
      it "succeeds" do
        expect { subject }.to_not raise_error
      end

      it "successfully delegates" do
        subject

        expect(instance.methods).to include(key_name)
        expect(instance.send(key_name)).to eq(value)
      end

      context "without delegation" do
        let(:delegation) { false }

        it "does not delegate" do
          subject

          expect(instance.methods).to_not include(key_name)
        end
      end

      context "with failure type from on_argument_validation" do
        before { klass.on_argument_validation :raise }
        let(:value) { failure }

        context "when raise" do
          it do
            expect { subject }.to raise_error(described_class::ArgumentValidationError)
          end

          context "when required but missing" do
            let(:metadata) { super().merge({ required: true }) }
            let(:value) { nil }

            it do
              expect { subject }.to raise_error(described_class::ArgumentValidationError)
            end
          end
        end

        context "when fail_early" do
          before { klass.on_argument_validation :fail_early }

          it do
            expect { subject }.to_not raise_error
          end

          it "fails" do
            expect(subject.failure?).to eq(true)
            expect(subject.invalid_arguments).to eq(true)
          end

          context "when required but missing" do
            let(:metadata) { super().merge({ required: true }) }
            let(:value) { nil }

            it do
              expect { subject }.to_not raise_error
            end

            it "fails" do
              expect(subject.failure?).to eq(true)
              expect(subject.invalid_arguments).to eq(true)
            end
          end
        end

        context "when log message" do
          before { klass.on_argument_validation :log }

          it "logs message without error" do
            expect(instance).to receive(:log_warn).with(/Parameter/)

            subject
          end

          it "succeeds" do
            expect(subject.success?).to eq(true)
            expect(subject.invalid_arguments).to eq(true)
          end

          context "when required but missing" do
            let(:metadata) { super().merge({ required: true }) }
            let(:value) { nil }

            it "logs message without error" do
              expect(instance).to receive(:log_warn).with(/Parameter/)

              subject
            end

            it "succeeds" do
              expect(subject.success?).to eq(true)
              expect(subject.invalid_arguments).to eq(true)
            end
          end
        end
      end
    end

    context "when duplicate key" do
      it do
        expect { klass.validate(context_values.keys.sample) }.to raise_error(ApiEngineBase::ServiceBase::NameConflictError, /Duplicate key name found/)
      end
    end

    context "with multiple failures with: fail_early" do
      before do
        klass.validate(:one, required: true)
        klass.validate(:two, required: true)
        klass.validate(:three, required: true)
        klass.validate(:four, required: true)
        klass.on_argument_validation :fail_early
      end

      it "fails" do
        expect(subject.failure?).to be(true)
      end

      it "sets invalid_arguments" do
        expect(subject.invalid_arguments).to be(true)
      end

      it "sets invalid_argument_keys" do
        expect(subject.invalid_argument_keys).to include(:one, :two, :three, :four)
      end

      it "sets msg" do
        expect(subject.msg).to include(
          "Parameter [one]",
          "Parameter [two]",
          "Parameter [three]",
          "Parameter [four]",
        )
      end
    end

    context "with lt" do
      let(:metadata) { super().merge({ lt: limit }) }
      let(:limit) { 10 }
      let(:value) { 5 }
      let(:failure) { limit + 1 }

      include_examples "sharable validations"
    end

    context "with lte" do
      let(:metadata) { super().merge({ lte: limit }) }
      let(:limit) { 10 }
      let(:value) { 10 }
      let(:failure) { limit + 1 }

      include_examples "sharable validations"
    end

    context "with eq" do
      let(:metadata) { super().merge({ eq: limit }) }
      let(:limit) { 10 }
      let(:value) { 10 }
      let(:failure) { limit - 1 }

      include_examples "sharable validations"
    end

    context "with gte" do
      let(:metadata) { super().merge({ gte: limit }) }
      let(:limit) { 10 }
      let(:value) { 10 }
      let(:failure) { limit - 1 }

      include_examples "sharable validations"
    end

    context "with gt" do
      let(:metadata) { super().merge({ gt: limit }) }
      let(:limit) { 10 }
      let(:value) { 11 }
      let(:failure) { limit }

      include_examples "sharable validations"
    end

    context "with default" do
      let(:metadata) { super().merge({ default: default_value }) }
      let(:default_value) { value * 2 }
      let(:value) { rand }

      context "with context_values provided" do
        let(:context_values) { { key_name => value } }

        it "uses value provided" do
          expect(subject.public_send(key_name)).to eq(value)
        end
      end

      context "when context_values NOT provided" do
        let(:context_values) { { } }

        it "uses default value" do
          expect(subject.public_send(key_name)).to eq(default_value)
        end
      end
    end

    context "with is_a" do
      let(:metadata) { super().merge({ is_a: String }) }
      let(:value) { "succesful" }
      let(:failure) { 5 }

      context "with inheritance" do
        let(:metadata) { super().merge({ is_a: [ActionController::Base, ActionController::API] }) }
        let(:value) { ApiEngineBase::AdminController }
        let(:failure) { 5 }

        include_examples "sharable validations"
      end

      include_examples "sharable validations"

      context "with complex" do
        let(:metadata) { super().merge({ length: true }) }

        context "with lt" do
          let(:metadata) { super().merge({ lt: limit }) }
          let(:limit) { 10 }
          let(:value) { "s" * (limit - 1) }
          let(:failure) { "s" * limit }

          include_examples "sharable validations"
        end

        context "with lte" do
          let(:metadata) { super().merge({ lte: limit }) }
          let(:limit) { 10 }
          let(:value) { "s" * (limit) }
          let(:failure) { "s" * (limit + 1) }

          include_examples "sharable validations"
        end

        context "with eq" do
          let(:metadata) { super().merge({ eq: limit }) }
          let(:limit) { 10 }
          let(:value) { "s" * (limit) }
          let(:failure) { "s" * (limit - 5) }

          include_examples "sharable validations"
        end

        context "with gte" do
          let(:metadata) { super().merge({ gte: limit }) }
          let(:limit) { 10 }
          let(:value) { "s" * (limit) }
          let(:failure) { "s" * (limit - 1) }

          include_examples "sharable validations"
        end

        context "with gt" do
          let(:metadata) { super().merge({ gt: limit }) }
          let(:limit) { 10 }
          let(:value) { "s" * (limit + 1) }
          let(:failure) { "s" * (limit) }

          include_examples "sharable validations"
        end
      end
    end

    context "with is_one" do
      let(:metadata) { super().merge({ is_one: is_one }) }
      let(:is_one) { "successful" }
      let(:value) { "successful" }
      let(:failure) { "not the correct value" }

      include_examples "sharable validations"
    end
  end
end
