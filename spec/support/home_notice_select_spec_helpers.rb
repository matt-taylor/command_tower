# frozen_string_literal: true

# Builders for HomeNotices::Select specs. Example groups cannot define `def` helpers (test
# standards guard), so notice classes, rows and the request context are built here.
module HomeNoticeSelectSpecHelpers
  module_function

  DEFAULT_PACING = { max: 3, cooldown: 4.hours }.freeze
  NOTICE_OPTIONS = { kind: :dismissible, rank: 10, active: nil, shows: nil, body: nil }.freeze
  CAMPAIGN_OPTIONS = NOTICE_OPTIONS.merge(pacing: DEFAULT_PACING, period: nil).freeze

  # The frozen clock every Select example starts at.
  def start_time
    Time.utc(2026, 11, 24, 12)
  end

  # A campaign. Options: `kind` (severity), `rank` (priority), `pacing` (feeds `impressions`),
  # `active` (feeds `window`), `period` (the `period_key` block), and `shows` / `body` (see `behave`).
  def campaign(notice_key, **options)
    options.assert_valid_keys(*CAMPAIGN_OPTIONS.keys)
    opts = CAMPAIGN_OPTIONS.merge(options)
    klass = Class.new(CommandTower::HomeNotices::Campaign) do
      key notice_key
      severity opts[:kind]
      priority opts[:rank]
      blocking_reason "Terms changed and need acceptance"
    end
    pace(klass, opts)
    behave(klass, shows: opts[:shows], body: opts[:body])
  end

  def pace(klass, opts)
    klass.impressions(**opts[:pacing]) if opts[:pacing]
    klass.window(**opts[:active]) if opts[:active]
    klass.period_key(&opts[:period]) if opts[:period]
  end

  # An unlinked delivery. Options: `kind`, `rank`, `active`, `shows` and `body`, as for `campaign`.
  def delivery(notice_key, **options)
    options.assert_valid_keys(*NOTICE_OPTIONS.keys)
    opts = NOTICE_OPTIONS.merge(options)
    klass = Class.new(CommandTower::HomeNotices::Delivery) do
      key notice_key
      severity opts[:kind]
      priority opts[:rank]
      blocking_reason "Class changed and needs acceptance"
      window(**opts[:active]) if opts[:active]
    end
    behave(klass, shows: opts[:shows], body: opts[:body])
  end

  # A `show?` lambda that is true only for requests from `platform`.
  def shown_on(platform)
    ->(context:, **) { context.platform == platform }
  end

  # `show?` calls `shows` (keyword arguments user:, context:, notice:) or is always true. `compose`
  # calls `body` with the builder or writes one text card.
  def behave(klass, shows:, body:)
    klass.class_eval do
      define_method(:show?) { |**args| shows ? shows.call(**args) : true }
      define_method(:compose) do |builder, **|
        body ? body.call(builder) : builder.card { |card| card.text "Notice" }
      end
    end
    klass
  end

  # A compose body the `:blocking_notice` profile rejects (internal navigation).
  def internal_link_body
    ->(builder) { builder.card { |card| card.button "Go", action: card.navigate(path: "/settings") } }
  end

  def campaign_row(user:, key:, period_key: "", **attributes)
    CommandTower::HomeNotice.create!(user:, kind: "campaign", key:, campaign_key: key, period_key:, **attributes)
  end

  def delivery_row(user:, key:, identity:, **attributes)
    CommandTower::HomeNotice.create!(user:, kind: "delivery", key:, identity:, **attributes)
  end

  def request_context(now: Time.current, platform: "web", ui_catalog: 2)
    CommandTower::HomeNotices::Context.new(
      now:, time_zone: "UTC", app_version: nil, platform:,
      ui_catalog:, client_compatibility: nil, impersonating: false
    )
  end

  def run_select(user:, now: Time.current, **context_options)
    CommandTower::Services::HomeNotices::Select.call(user:, request_context: request_context(now:, **context_options))
  end

  def picked_key(result, severity)
    result.data[severity]&.notice_class&.key
  end

  def candidate_keys(result)
    result.data[:candidates].map { |candidate| candidate.notice_class.key }
  end

  def candidate_identities(result)
    result.data[:candidates].map { |candidate| candidate.record&.identity }
  end

  def candidate_for(result, key)
    result.data[:candidates].find { |candidate| candidate.notice_class.key == key }
  end
end
