# frozen_string_literal: true

require "net/http"
require "json"
require "uri"
require "time"

module Newshound
  module Exceptions
    class Bugsink < Base
      def self.required_keys
        %i[url token project_id].freeze
      end

      def initialize(config = {})
        super
        config = config.transform_keys(&:to_sym)

        missing = self.class.required_keys.select { |key| config[key].nil? }
        if missing.any?
          raise ArgumentError,
            "Bugsink requires #{missing.map { |k| ":#{k}" }.join(", ")} in exception_source_config"
        end

        @url = config[:url]
        @token = config[:token]
        @project_id = config[:project_id]
      end

      def recent(time_range:, limit:)
        issues = fetch_issues
        cutoff = Time.now.utc - time_range

        issues
          .select { |i| Time.parse(i["last_seen"]) >= cutoff }
          .first(limit)
      end

      def format_for_report(issue, number)
        <<~TEXT
          *#{number}. #{issue["calculated_type"] || "Unknown"}*
          • *Time:* #{Time.parse(issue["last_seen"]).strftime("%I:%M %p")}
          • *Message:* `#{(issue["calculated_value"] || "").truncate(100)}`
        TEXT
      end

      def format_for_banner(issue)
        {
          id: issue["id"],
          title: issue["calculated_type"] || "Unknown",
          message: (issue["calculated_value"] || "").truncate(100),
          location: issue["transaction"] || "",
          time: Time.parse(issue["last_seen"]).strftime("%I:%M %p")
        }
      end

      private

      def fetch_issues
        uri = URI("#{@url.chomp("/")}/api/canonical/0/issues/")
        uri.query = URI.encode_www_form(project: @project_id, sort: "last_seen", order: "desc")

        request = Net::HTTP::Get.new(uri)
        request["Authorization"] = "Bearer #{@token}"
        request["Accept"] = "application/json"

        response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
          http.request(request)
        end

        raise "Bugsink API error: #{response.code}" unless response.is_a?(Net::HTTPSuccess)

        JSON.parse(response.body)["results"] || []
      end
    end
  end
end
