# frozen_string_literal: true

require "json"
require "fileutils"

# Writes normalized inbox wire responses to spec/fixtures/messaging/inbox_contract/<name>.json
# so contract drift shows up as a git diff. Hosts and the frontend copy these files.
#
# The stamp is a literal, not CommandTower::VERSION, which stays unchanged until the release task.
module InboxContractFixtures
  CONTRACT_STAMP = "command_tower 0.27.0"
  FIXED_TIMESTAMP = "2026-01-01T00:00:00.000Z"
  DIRECTORY = File.expand_path("../fixtures/messaging/inbox_contract", __dir__)
  ID_KEY = /\A(id|ids|[a-z][A-Za-z]*Ids?)\z/
  TIMESTAMP = /\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?(Z|[+-]\d{2}:\d{2})\z/

  module_function

  def write_inbox_contract_fixture(name, response)
    body = JSON.parse(response.body)
    document = { "contract" => CONTRACT_STAMP }.merge(normalize(body, {}))
    FileUtils.mkdir_p(DIRECTORY)
    File.write(File.join(DIRECTORY, "#{name}.json"), "#{JSON.pretty_generate(document)}\n")
  end

  def normalize(value, id_map, key = nil)
    case value
    when Hash then value.to_h { |k, v| [k, normalize(v, id_map, k)] }
    when Array then value.map { |v| normalize(v, id_map, key) }
    when Integer then normalize_integer(value, id_map, key)
    when String then normalize_string(value)
    else value
    end
  end

  def normalize_integer(value, id_map, key)
    return value unless key&.match?(ID_KEY)

    id_map[value] ||= id_map.size + 1
  end

  # Timestamps are fixed; factory sequence numbers ("Message title 15") depend on spec order.
  def normalize_string(value)
    return FIXED_TIMESTAMP if value.match?(TIMESTAMP)

    value.gsub(/(Message (?:title|body)) \d+/, '\1 1')
  end
end

RSpec.configure do |config|
  config.include InboxContractFixtures, type: :request
end
