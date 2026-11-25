# frozen_string_literal: true

module CommandTower
  module HomeNotices
    # Per-request facts passed to `show?`, `compose` and `period_key`.
    Context = Data.define(
      :now, :time_zone, :app_version, :platform, :ui_catalog, :client_compatibility, :impersonating
    )
  end
end
