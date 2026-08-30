# frozen_string_literal: true

module CommandTower
  module Intervention
    # Canonical blocker severity strings for host-authored action interventions.
    # Transport-only: CT FE presentation (`tone`) is host-owned and is not
    # serialized on the envelope. Hosts may map these severities to FE tones.
    #
    # - BLOCKING — policy / hard stop (typical FE tone: destructive)
    # - WARNING — attention without framing as an error (typical FE tone: warning)
    # - INFORMATIONAL — soft notice (typical FE tone: informational)
    module Severity
      BLOCKING = "blocking"
      WARNING = "warning"
      INFORMATIONAL = "informational"

      ALL = [BLOCKING, WARNING, INFORMATIONAL].freeze
    end
  end
end
