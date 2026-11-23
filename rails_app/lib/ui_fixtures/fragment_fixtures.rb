# frozen_string_literal: true

# S2 fragment fixtures (mocks/fragments.html). Fictional data throughout.
module UiFixtures
  Fragments = CommandTower::UI::Fragments

  # A host-style fact block: title, when and where, and a status badge.
  class ClassFacts < Fragments::Facts
    def compose(builder, metadata:)
      builder.text(metadata.fetch(:title), variant: :title)
      builder.key_value do |kv|
        kv.item nil, kv.time(at: metadata.fetch(:starts_at), zone: LA, label: :always), icon: "calendar"
        kv.item nil, metadata.fetch(:studio), icon: "map-pin"
      end
      builder.badge(metadata.fetch(:status), tone: :danger)
    end
  end

  CLASS_METADATA = { title: "Sunrise Ride 45", starts_at: CLASS_STARTS_AT,
                     studio: "Mission Street Studio", status: "Canceled" }.freeze

  def self.nav(builder, path)
    builder.navigate(path:)
  end

  define("header_title") do |s|
    s.fragment Fragments::Header, title: "Your weekly summary"
  end

  define("header_subtitle") do |s|
    s.fragment Fragments::Header, title: "Your weekly summary", subtitle: "Nov 24 - Nov 30"
  end

  define("header_badge") do |s|
    s.fragment Fragments::Header, title: "Your class was canceled", subtitle: "The studio canceled this class.",
                                  badge_label: "Canceled", badge_tone: :danger
  end

  define("header_avatar") do |s|
    s.fragment Fragments::Header, title: "A note from Coach Dana R.", subtitle: "Sunrise Ride 45",
                                  avatar: { initials: "DR" }
  end

  define("header_all") do |s|
    s.fragment Fragments::Header, title: "You're in", subtitle: "Sunrise Ride 45, Thu, Dec 4",
                                  badge_label: "Booked", badge_tone: :success, avatar: { initials: "DR" }
  end

  define("header_long") do |s|
    s.fragment Fragments::Header,
               title: "Confirm your spot for the holiday marathon ride before it is released to the waitlist",
               subtitle: "Reply by Friday", badge_label: "Action needed", badge_tone: :warning
  end

  define("fact_row_icon") do |s|
    s.fragment Fragments::FactRow, icon: "map-pin", value: "Mission Street Studio"
  end

  define("fact_row_label") do |s|
    s.fragment Fragments::FactRow, label: "Instructor", value: "Coach Dana R."
  end

  # FactRow takes a String value, so the time row is the one-item key_value it would emit.
  define("fact_row_time") do |s|
    s.key_value { |kv| kv.item nil, kv.time(at: CLASS_STARTS_AT, zone: LA), icon: "calendar" }
  end

  define("cta_primary") do |s|
    s.fragment Fragments::CtaGroup,
               buttons: [{ label: "Find another class", action: nav(s, "/classes"), variant: :primary }]
  end

  define("cta_full") do |s|
    s.fragment Fragments::CtaGroup, buttons: [
      { label: "Find another class", action: nav(s, "/classes"), variant: :primary },
      { label: "View my bookings", action: nav(s, "/bookings") },
      { label: "Contact the studio", action: nav(s, "/contact") }
    ]
  end

  define("cta_secondary_ghost") do |s|
    s.fragment Fragments::CtaGroup, buttons: [
      { label: "View my bookings", action: nav(s, "/bookings") },
      { label: "Not now", action: nav(s, "/inbox"), variant: :ghost }
    ]
  end

  define("cta_long_label") do |s|
    s.fragment Fragments::CtaGroup, buttons: [
      { label: "Browse every class at Mission Street Studio this week", action: nav(s, "/classes"),
        variant: :primary }
    ]
  end

  define("notice_frame_tones") do |s|
    s.fragment Fragments::NoticeFrame, tone: :neutral, title: "Holiday hours",
                                       body: ["Studios close at 2:00 PM on Dec 24 and reopen Dec 26."]
    s.fragment Fragments::NoticeFrame, tone: :accent, title: "New: book classes two weeks out",
                                       body: ["You can now reserve up to 14 days ahead."]
    s.fragment Fragments::NoticeFrame, tone: :success, title: "Your payment method is updated",
                                       body: ["Future bookings will use the card ending 4421."]
    s.fragment Fragments::NoticeFrame, tone: :warning, title: "Week 14 picks lock Sunday",
                                       body: ["You have 7 picks left."]
    s.fragment Fragments::NoticeFrame, tone: :danger, title: "Your membership has lapsed",
                                       body: ["Update your payment details to keep booking classes."]
  end

  # The body holds a key_value, which NoticeFrame's string body cannot, so this is the
  # frame's emission written out with primitives.
  define("notice_frame_body") do |s|
    s.card(surface: :tinted, tone: :warning, padding: :lg) do |card|
      card.stack(gap: :sm) do |body|
        body.text "Week 14 picks lock Sunday, so make them before the long weekend", variant: :heading_m
        body.text "You have 7 picks left.", variant: :body
        body.key_value { |kv| kv.item nil, kv.time(at: PICKS_LOCK_AT, zone: NY, label: :always), icon: "clock" }
      end
    end
  end

  define("facts_block") do |s|
    ClassFacts.call(s, metadata: CLASS_METADATA)
  end

  define("class_canceled_inbox") do |s|
    ClassFacts.call(s, metadata: CLASS_METADATA)
    s.banner "No late-cancel fee was charged.", tone: :warning
    s.fragment Fragments::CtaGroup, buttons: [
      { label: "Find another class", action: nav(s, "/classes"), variant: :primary },
      { label: "View my bookings", action: nav(s, "/bookings") }
    ]
  end

  define("picks_reminder") do |s|
    s.fragment Fragments::Header, title: "Week 14 picks lock Sunday", subtitle: "Sun, Dec 7, 10:00 AM ET",
                                  badge_label: "Action needed", badge_tone: :warning
    s.stack(gap: :sm) do |tiles|
      tiles.stat_tile value: "7", label: "Picks remaining", tone: :warning, icon: "clock"
      tiles.stat_tile value: "#4 of 38", label: "Season rank", tone: :accent, icon: "trophy"
    end
    s.fragment Fragments::CtaGroup,
               buttons: [{ label: "Make my picks", action: nav(s, "/picks"), variant: :primary }]
  end
end
