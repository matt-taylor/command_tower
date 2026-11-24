# frozen_string_literal: true

module MessagingFixtures
  # The admin gallery payloads in wire form: the list, an empty list, and a preview per type for
  # the default zone and for America/New_York.
  module GalleryFixtures
    DIR = File.join(MessagingFixtures::ROOT, "messaging/gallery")
    SERIALIZER = CommandTower::Serializers::Admin::Messaging::GallerySerializer

    module_function

    # @return [Hash{String => Object}] absolute path => wire value (not yet encoded)
    def values
      types = CommandTower::Services::Messaging::Gallery::ListGalleryTypes.call.data[:types]
      values = { path("list") => SERIALIZER.serialize_list(types), path("list_empty") => SERIALIZER.serialize_list([]) }
      types.each do |type|
        key = type[:notification_type_key]
        values[path("preview_#{key}")] = preview(key, nil)
        values[path("preview_#{key}_america_new_york")] = preview(key, MessagingFixtures::USER_ZONE)
      end
      values
    end

    def path(name)
      File.join(DIR, "#{name}.json")
    end

    def preview(key, zone)
      result = CommandTower::Services::Messaging::Gallery::RenderGalleryPreview.call(
        notification_type_key: key, zone:
      )
      raise "gallery preview failed for #{key}" unless result.success?

      SERIALIZER.serialize_preview(result.data[:preview])
    end
  end
end
