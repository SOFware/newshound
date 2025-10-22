module Newshound
  module Exceptions
    class ExceptionTrack < Base
      def recent(time_range:, limit:)
        ::ExceptionTrack::Log
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
        body_data = parse_body(exception)
        controller_name = body_data["controller_name"]
        action_name = body_data["action_name"]

        {
          title: exception.try(:title).presence || exception.try(:exception_class).presence || "Unknown Exception",
          message: body_data["message"].presence&.to_s || exception.try(:message).presence&.to_s || +"",
          location: (controller_name && action_name) ? "#{controller_name}##{action_name}" : +"",
          controller_name: controller_name,
          action_name: action_name
        }
      end

      def parse_body(exception)
        return {} unless exception.respond_to?(:body) && exception.body.present?

        JSON.parse(exception.body)
      rescue JSON::ParserError
        {}
      end

      def format_controller(details)
        return +"" unless details in {controller_name: String, action_name: String}

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
