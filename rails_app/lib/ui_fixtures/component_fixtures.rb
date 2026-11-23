# frozen_string_literal: true

# S1 component fixtures (mocks/components.html). Fictional data throughout.
module UiFixtures
  CLASS_STARTS_AT = Time.utc(2025, 12, 4, 14, 0, 0)
  PICKS_LOCK_AT = Time.utc(2025, 12, 7, 15, 0, 0)
  LA = "America/Los_Angeles"
  NY = "America/New_York"

  define("key_value_facts") do |s|
    s.key_value do |kv|
      kv.item nil, kv.time(at: CLASS_STARTS_AT, zone: LA, label: :always), icon: "calendar"
      kv.item nil, "Mission Street Studio", icon: "map-pin"
      kv.item nil, "Coach Dana R.", icon: "user"
    end
  end

  define("key_value_labelled") do |s|
    s.key_value do |kv|
      kv.item "Starts", kv.time(at: CLASS_STARTS_AT, zone: LA, label: :never), icon: "calendar"
      kv.item "Studio", "Mission Street Studio", icon: "map-pin"
      kv.item "Instructor", "Coach Dana R.", icon: "user"
    end
  end

  define("key_value_mixed_long") do |s|
    s.key_value do |kv|
      kv.item "Address", "2150 Mission Street, Suite 400 (enter through the side door on 17th Street), " \
                         "San Francisco, CA 94110", icon: "map-pin"
      kv.item nil, "Parking validated for 90 minutes at the Bartlett Street garage"
      kv.item "Cancellation policy", "Free until 12 hours before class", icon: "clock"
      kv.item "Reference", "booking-7f3a9c21-4d0e-4b8a-9e55-2c6d1f0b7a43"
    end
  end

  define("key_value_labels_only") do |s|
    s.key_value do |kv|
      kv.item "Week", "14"
      kv.item "Picks made", "9 of 16"
      kv.item "Locks", kv.time(at: PICKS_LOCK_AT, zone: NY, label: :always)
    end
  end

  define("stat_tile_tones") do |s|
    s.stack(gap: :sm) do |tiles|
      tiles.stat_tile value: "12", label: "Classes this month", tone: :neutral, icon: "calendar"
      tiles.stat_tile value: "#4 of 38", label: "Season rank", tone: :accent, icon: "trophy"
      tiles.stat_tile value: "11 of 16", label: "Correct picks", tone: :success, icon: "check"
      tiles.stat_tile value: "7", label: "Picks remaining", tone: :warning, icon: "clock"
      tiles.stat_tile value: "2", label: "Late cancels", tone: :danger, icon: "flame"
    end
  end

  define("stat_tile_long") do |s|
    s.stat_tile value: "Sunrise Ride 45 with Coach Dana R. at Mission Street Studio",
                label: "Next class", tone: :neutral
  end

  # The values below are obvious test values, never real codes.
  define("code_qr", fallback: "Check-in code. Open the app to check in.") do |s|
    s.code value: "TEST-QR-0000", label: "Check-in code", format: :qr
  end

  define("code_text", fallback: "Confirmation code. Open the app to see it.") do |s|
    s.code value: "TEST-0000", label: "Confirmation code", format: :text
  end

  define("banner_tones") do |s|
    s.stack(gap: :sm) do |banners|
      messages = {
        neutral: ["Schedule update", "Holiday hours apply Dec 24-26."],
        accent: ["New classes", "Evening rides are now open for booking."],
        success: ["Payment received", "Your preferences were saved."],
        warning: ["Picks lock soon", "You still have 7 picks to make."],
        danger: ["Class canceled", "The studio canceled this class. Your credit was returned."]
      }
      messages.each do |tone, (title, message)|
        banners.banner(message, title:, tone:)
        banners.banner(message, tone:)
      end
      banners.banner "You still have ", banners.strong("7 picks"), " to make. ",
                     banners.link("See this week's games", action: banners.navigate(path: "/picks")),
                     title: "Picks lock soon", tone: :warning
    end
  end

  define("badge_tones") do |s|
    s.stack(gap: :sm, align: :start) do |badges|
      badges.badge "Week 14", tone: :neutral
      badges.badge "Featured", tone: :accent
      badges.badge "Booked", tone: :success
      badges.badge "Waitlist", tone: :warning
      badges.badge "Canceled", tone: :danger
    end
  end
end
