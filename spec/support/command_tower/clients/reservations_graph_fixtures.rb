# frozen_string_literal: true

require "json"

# Recursive response-deserialization fixture graph for Phase 1.3.4.
# Test-only — mirrors legacy MT list *shape*, not production MarianaTek code.
module CommandTower
  module Clients
    module SpecSupport
      module ReservationsGraph
        Location = Data.define(:external_id, :name)
        Instructor = Data.define(:external_id, :name)
        Spot = Data.define(:external_id, :label)
        Pagination = Data.define(:page, :pages, :count)
        Reservation = Data.define(:external_id, :location, :instructors, :spots, :optional_note)
        ListOutput = Data.define(:reservations, :pagination)

        class LocationDeserializer
          def self.call(payload)
            unless payload.is_a?(Hash)
              raise TypeError, "location payload must be a Hash"
            end

            Location.new(
              external_id: payload.fetch("id").to_s,
              name: payload.fetch("name").to_s
            )
          end
        end

        class InstructorDeserializer
          def self.call(payload)
            Instructor.new(
              external_id: payload.fetch("id").to_s,
              name: payload.fetch("name").to_s
            )
          end
        end

        class SpotDeserializer
          def self.call(payload)
            Spot.new(
              external_id: payload.fetch("id").to_s,
              label: payload.fetch("name").to_s
            )
          end
        end

        class PaginationDeserializer
          def self.call(payload)
            Pagination.new(
              page: Integer(payload.fetch("page")),
              pages: Integer(payload.fetch("pages")),
              count: Integer(payload.fetch("count"))
            )
          end
        end

        class ReservationDeserializer
          def self.call(payload)
            location_payload = payload["location"]
            location = if location_payload.nil?
                         nil
            else
                         LocationDeserializer.call(location_payload)
            end

            Reservation.new(
              external_id: payload.fetch("id").to_s,
              location: location,
              instructors: payload.fetch("instructors").map do |item|
                InstructorDeserializer.call(item)
              end,
              spots: payload.fetch("spots", []).map do |item|
                SpotDeserializer.call(item)
              end,
              optional_note: payload["note"]
            )
          end
        end

        class ListResponseDeserializer
          # Receives provider-decoded payload (Hash), not Transport::Response.
          def self.call(payload)
            unless payload.is_a?(Hash)
              raise TypeError, "list payload must be a Hash"
            end

            ListOutput.new(
              reservations: payload.fetch("results").map do |item|
                ReservationDeserializer.call(item)
              end,
              pagination: PaginationDeserializer.call(
                payload.fetch("meta").fetch("pagination")
              )
            )
          end
        end

        ListInput = Data.define

        class ListRequestSerializer
          def self.call(_input)
            SerializedRequest.build
          end
        end

        class List < EndpointBase
          http_method :get
          path "/reservations"
          input ListInput
          request_serializer ListRequestSerializer
          response_deserializer ListResponseDeserializer
        end

        SAMPLE_PAYLOAD = {
          "results" => [
            {
              "id" => "r1",
              "note" => nil,
              "location" => { "id" => "loc1", "name" => "Castro" },
              "instructors" => [
                { "id" => "i1", "name" => "Alex" },
                { "id" => "i2", "name" => "Blake" }
              ],
              "spots" => [
                { "id" => "s1", "name" => "DF12" },
                { "id" => "s2", "name" => "T3" }
              ]
            },
            {
              "id" => "r2",
              "location" => nil,
              "instructors" => [],
              "spots" => []
            }
          ],
          "meta" => {
            "pagination" => { "page" => 1, "pages" => 3, "count" => 40 }
          }
        }.freeze
      end

      class ReservationsGraphProvider < ClientBase
        # Fixture provider owns JSON encoding (same ownership layer as MarianaTek).
        def decode_response(response)
          DecodedResponse.new(
            payload: JSON.parse(response.body.to_s),
            provider_metadata: {}
          )
        end

        protected

        def base_url
          "https://example.test/api/v1"
        end
      end
    end
  end
end
