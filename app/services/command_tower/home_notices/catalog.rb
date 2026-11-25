# frozen_string_literal: true

module CommandTower
  module HomeNotices
    # Boot-time registry of host notices. `load!` constantizes `config.home_notices.notices`, checks
    # every class (see `Catalog::Validator`) and raises `Catalog::InvalidNoticeError` on the first
    # problem, in every environment. Runs from the engine's `to_prepare` only when
    # `config.home_notices.enabled`.
    class Catalog
      class InvalidNoticeError < StandardError; end

      class << self
        # @param class_names [Array<String>] defaults to `config.home_notices.notices`
        # @return [Array<Class>] the validated notice classes
        def load!(class_names = CommandTower.config.home_notices.notices)
          classes = Array(class_names).map { |name| constantize!(name) }
          classes.each { |klass| validate!(klass) }
          validate_unique_keys!(classes)

          @notices = classes.freeze
          @campaigns_by_key = classes.select { |klass| klass < Campaign }.index_by(&:key).freeze
          @notices
        end

        def reset!
          @notices = nil
          @campaigns_by_key = nil
        end

        def notices
          @notices || []
        end

        # Deliveries are not indexed: they are found through their persisted rows.
        def campaign(key)
          (@campaigns_by_key || {})[key.to_s]
        end

        def find(key)
          notices.find { |klass| klass.key == key.to_s }
        end

        def registered?(key)
          !find(key).nil?
        end

        def validate!(klass)
          errors = Validator.errors_for(klass)
          return klass if errors.empty?

          raise InvalidNoticeError, "#{klass.name || klass.inspect}: #{errors.join('; ')}"
        end

        private

        def constantize!(name)
          return name if name.is_a?(Class)

          name.to_s.constantize
        rescue NameError
          raise InvalidNoticeError, "config.home_notices.notices names an unknown class: #{name}"
        end

        def validate_unique_keys!(classes)
          duplicate = classes.group_by(&:key).find { |_key, group| group.size > 1 }
          return if duplicate.nil?

          raise InvalidNoticeError, "duplicate notice key: #{duplicate.first}"
        end
      end
    end
  end
end
