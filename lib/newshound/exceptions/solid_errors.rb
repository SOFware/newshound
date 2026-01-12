module Newshound
  module Exceptions
    class SolidErrors < Base
      def recent(time_range:, limit:)
        ::SolidErrors::Occurrence
          .where("created_at >= ?", time_range.ago)
          .order(created_at: :desc)
          .limit(limit)
      end

      def format_for_report(exception, number)
        details = parse_exception_details(exception)

        <<~TEXT
          *#{number}. #{details[:title]}*
          • *Time:* #{exception.created_at.strftime("%I:%M %p")}
          #{format_controller(details)}
          #{format_message(details)}
        TEXT
      end

      def format_for_banner(exception)
        details = parse_exception_details(exception)

        {
          title: details[:title],
          message: details[:message].truncate(100),
          location: details[:location],
          time: exception.created_at.strftime("%I:%M %p")
        }
      end

      private

      def parse_exception_details(exception)
        context_data = parse_context(exception)
        controller = context_data["controller"]
        action = context_data["action"]

        error_record = exception.try(:error)

        {
          title: error_record&.exception_class.presence || "Unknown Exception",
          message: error_record&.message.presence&.to_s || context_data["message"].presence&.to_s || +"",
          location: (controller && action) ? "#{controller}##{action}" : +"",
          controller: controller,
          action: action
        }
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

      def format_controller(details)
        return +"" unless details in {controller: String, action: String}

        "• *Controller:* #{details[:location]}\n"
      end

      def format_message(details)
        return +"" unless details in {message: String}

        message = details[:message].to_s.truncate(100)
        "• *Message:* `#{message}`"
      end
    end
  end
end
