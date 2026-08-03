module Newshound
  module Exceptions
    class SolidErrors < Base
      LAST_OCCURRED_AT = "MAX(solid_errors_occurrences.created_at) AS last_occurred_at"
      OCCURRENCE_COUNT = "COUNT(solid_errors_occurrences.id) AS occurrence_count"

      # Pass `unresolved_only: false` in exception_source_config to list raw
      # occurrence rows instead of one row per unresolved error.
      def initialize(config = {})
        super
        config = config.transform_keys(&:to_sym)
        @unresolved_only = config.fetch(:unresolved_only, true)
      end

      def recent(time_range:, limit:)
        return unresolved_errors(time_range, limit) if @unresolved_only

        ::SolidErrors::Occurrence
          .where("created_at >= ?", time_range.ago)
          .order(created_at: :desc)
          .limit(limit)
      end

      def format_for_report(exception, number)
        details = parse_exception_details(exception)

        <<~TEXT
          *#{number}. #{details[:title]}*
          • *Time:* #{details[:time]}
          #{format_location(details)}
          #{format_message(details)}
        TEXT
      end

      def format_for_banner(exception)
        details = parse_exception_details(exception)

        {
          id: banner_id(exception),
          title: details[:title],
          message: details[:message].truncate(100),
          location: details[:location],
          time: details[:time]
        }
      end

      private

      # Apps build /errors/:id links from this, so both modes report the error id.
      def banner_id(exception)
        return exception.id if @unresolved_only

        exception.try(:error)&.id || exception.try(:id)
      end

      # Resolved state lives on the parent error, so listing errors rather than
      # occurrences is what lets the /errors UI quiet the banner. Grouping also keeps
      # one error hit 300 times from filling every banner slot.
      def unresolved_errors(time_range, limit)
        ::SolidErrors::Error
          .unresolved
          .joins(:occurrences)
          .where(solid_errors_occurrences: {created_at: time_range.ago..})
          .group(:id)
          .select("solid_errors.*", LAST_OCCURRED_AT, OCCURRENCE_COUNT)
          .order("last_occurred_at DESC")
          .limit(limit)
      end

      def parse_exception_details(exception)
        @unresolved_only ? error_details(exception) : occurrence_details(exception)
      end

      # Request context is recorded per occurrence, so an error row has none to
      # offer the location slot. The occurrence count is what grouping produces,
      # and it is already selected.
      def error_details(exception)
        {
          title: exception.exception_class.presence || "Unknown Exception",
          message: exception.message.presence.to_s,
          location: occurrence_summary(exception),
          location_label: "Occurrences",
          time: format_time(exception.last_occurred_at)
        }
      end

      def occurrence_details(exception)
        context_data = parse_context(exception)
        controller = context_data["controller"]
        action = context_data["action"]
        error_record = exception.try(:error)
        message = error_record&.message.presence || context_data["message"].presence

        {
          title: error_record&.exception_class.presence || "Unknown Exception",
          message: message.to_s,
          location: (controller && action) ? "#{controller}##{action}" : +"",
          location_label: "Controller",
          time: format_time(exception.created_at)
        }
      end

      def occurrence_summary(exception)
        count = exception.occurrence_count.to_i
        "#{count} #{(count == 1) ? "occurrence" : "occurrences"}"
      end

      # MAX() comes back as a String on some adapters.
      def format_time(time)
        time.in_time_zone.strftime("%I:%M %p")
      end

      def parse_context(exception)
        return {} unless exception.respond_to?(:context) && exception.context.present?

        case exception.context
        when Hash
          exception.context
        when String
          JSON.parse(exception.context)
        else
          {}
        end
      rescue JSON::ParserError
        {}
      end

      def format_location(details)
        return +"" if details[:location].blank?

        "• *#{details[:location_label]}:* #{details[:location]}\n"
      end

      def format_message(details)
        return +"" unless details in {message: String}

        message = details[:message].to_s.truncate(100)
        "• *Message:* `#{message}`"
      end
    end
  end
end
