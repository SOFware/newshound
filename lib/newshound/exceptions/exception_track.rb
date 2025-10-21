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
          *#{number}. #{exception_title(exception)}*
          • *Time:* #{exception.created_at.strftime("%I:%M %p")}
          #{format_controller(details)}
          #{format_message(exception, details)}
        TEXT
      end

      def format_for_banner(exception)
        details = parse_exception_details(exception)

        # Extract message
        message = if details["message"].present?
          details["message"].to_s
        elsif exception.respond_to?(:message) && exception.message.present?
          exception.message.to_s
        else
          +""
        end

        # Extract location
        location = if details["controller_name"] && details["action_name"]
          "#{details["controller_name"]}##{details["action_name"]}"
        else
          +""
        end

        {
          title: exception_title(exception),
          message: message.truncate(100),
          location: location,
          time: exception.created_at.strftime("%I:%M %p")
        }
      end

      private

      def exception_title(exception)
        if exception.respond_to?(:title) && exception.title.present?
          exception.title
        elsif exception.respond_to?(:exception_class) && exception.exception_class.present?
          exception.exception_class
        else
          "Unknown Exception"
        end
      end

      def parse_exception_details(exception)
        return {} unless exception.respond_to?(:body) && exception.body.present?

        JSON.parse(exception.body)
      rescue JSON::ParserError
        {}
      end

      def format_controller(details)
        return +"" unless details["controller_name"] && details["action_name"]

        "• *Controller:* #{details["controller_name"]}##{details["action_name"]}\n"
      end

      def format_message(exception, details = nil)
        details ||= parse_exception_details(exception)

        # Try to get message from different sources
        message = if details["message"].present?
          details["message"]
        elsif exception.respond_to?(:message) && exception.message.present?
          exception.message
        end

        return +"" unless message.present?

        message = message.to_s.truncate(100)
        "• *Message:* `#{message}`"
      end
    end
  end
end
