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
        context = parse_context(exception)

        <<~TEXT
          *#{number}. #{exception_title(exception)}*
          • *Time:* #{exception.created_at.strftime("%I:%M %p")}
          #{format_controller(context)}
          #{format_message(exception, context)}
        TEXT
      end

      def format_for_banner(exception)
        context = parse_context(exception)

        # Extract message
        message = if exception.respond_to?(:message) && exception.message.present?
          exception.message.to_s
        elsif context["message"].present?
          context["message"].to_s
        else
          +""
        end

        # Extract location from context
        location = if context["controller"] && context["action"]
          "#{context["controller"]}##{context["action"]}"
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
        if exception.respond_to?(:error_class) && exception.error_class.present?
          exception.error_class
        else
          "Unknown Exception"
        end
      end

      def parse_context(exception)
        return {} unless exception.respond_to?(:context) && exception.context.present?

        # SolidErrors context might be a hash or JSON string
        if exception.context.is_a?(Hash)
          exception.context
        elsif exception.context.is_a?(String)
          JSON.parse(exception.context)
        else
          {}
        end
      rescue JSON::ParserError
        {}
      end

      def format_controller(context)
        return +"" unless context["controller"] && context["action"]

        "• *Controller:* #{context["controller"]}##{context["action"]}\n"
      end

      def format_message(exception, context = nil)
        context ||= parse_context(exception)

        # Try to get message from different sources
        message = if exception.respond_to?(:message) && exception.message.present?
          exception.message
        elsif context["message"].present?
          context["message"]
        end

        return +"" unless message.present?

        message = message.to_s.truncate(100)
        "• *Message:* `#{message}`"
      end
    end
  end
end
