# frozen_string_literal: true

module Newshound
  module Middleware
    class BannerInjector
      def initialize(app)
        @app = app
      end

      def call(env)
        status, headers, response = @app.call(env)

        # Only inject into HTML responses
        return [status, headers, response] unless html_response?(headers)
        return [status, headers, response] unless status == 200

        # Check authorization
        controller = env['action_controller.instance']
        return [status, headers, response] unless controller
        return [status, headers, response] unless Newshound::Authorization.authorized?(controller)

        # Get banner HTML
        banner_html = generate_banner_html

        # Inject banner after <body> tag
        new_response = inject_banner(response, banner_html)

        # Update Content-Length header
        if headers['Content-Length']
          headers['Content-Length'] = new_response.bytesize.to_s
        end

        [status, headers, [new_response]]
      end

      private

      def html_response?(headers)
        content_type = headers['Content-Type']
        content_type && content_type.include?('text/html')
      end

      def inject_banner(response, banner_html)
        body = response_body(response)

        # Inject after <body> tag
        body.sub(/(<body[^>]*>)/i, "\\1\n#{banner_html}")
      end

      def response_body(response)
        body = String.new
        response.each { |part| body << part }
        body
      end

      def generate_banner_html
        exception_reporter = Newshound::ExceptionReporter.new
        que_reporter = Newshound::QueReporter.new

        exception_data = exception_reporter.banner_data
        job_data = que_reporter.banner_data

        # Generate HTML from template
        render_banner(exception_data, job_data)
      end

      def render_banner(exception_data, job_data)
        <<~HTML
          <div id="newshound-banner" class="newshound-banner newshound-collapsed">
            #{render_styles}
            <div class="newshound-header" onclick="document.getElementById('newshound-banner').classList.toggle('newshound-collapsed')">
              <span class="newshound-title">
                🐕 Newshound
                #{summary_badge(exception_data, job_data)}
              </span>
              <span class="newshound-toggle">▼</span>
            </div>
            <div class="newshound-content">
              #{render_exceptions(exception_data)}
              #{render_jobs(job_data)}
            </div>
          </div>
        HTML
      end

      def render_styles
        <<~CSS
          <style>
            .newshound-banner {
              position: fixed;
              top: 0;
              left: 0;
              right: 0;
              background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
              color: white;
              z-index: 10000;
              box-shadow: 0 2px 10px rgba(0,0,0,0.3);
              font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
              font-size: 14px;
            }
            .newshound-header {
              padding: 12px 20px;
              cursor: pointer;
              display: flex;
              justify-content: space-between;
              align-items: center;
              user-select: none;
            }
            .newshound-title {
              font-weight: 600;
              display: flex;
              align-items: center;
              gap: 10px;
            }
            .newshound-badge {
              display: inline-block;
              padding: 2px 8px;
              border-radius: 12px;
              font-size: 12px;
              font-weight: 600;
              background: rgba(255,255,255,0.2);
            }
            .newshound-badge.error {
              background: #ef4444;
            }
            .newshound-badge.warning {
              background: #f59e0b;
            }
            .newshound-badge.success {
              background: #10b981;
            }
            .newshound-toggle {
              transition: transform 0.3s;
            }
            .newshound-banner.newshound-collapsed .newshound-toggle {
              transform: rotate(-90deg);
            }
            .newshound-content {
              max-height: 400px;
              overflow-y: auto;
              border-top: 1px solid rgba(255,255,255,0.2);
              transition: max-height 0.3s ease-out;
            }
            .newshound-banner.newshound-collapsed .newshound-content {
              max-height: 0;
              overflow: hidden;
              border-top: none;
            }
            .newshound-section {
              padding: 15px 20px;
              border-bottom: 1px solid rgba(255,255,255,0.1);
            }
            .newshound-section:last-child {
              border-bottom: none;
            }
            .newshound-section-title {
              font-weight: 600;
              margin-bottom: 10px;
              font-size: 15px;
            }
            .newshound-item {
              background: rgba(255,255,255,0.1);
              padding: 10px;
              margin-bottom: 8px;
              border-radius: 6px;
              font-size: 13px;
            }
            .newshound-item:last-child {
              margin-bottom: 0;
            }
            .newshound-item-title {
              font-weight: 600;
              margin-bottom: 4px;
            }
            .newshound-item-detail {
              opacity: 0.9;
              font-size: 12px;
            }
            .newshound-grid {
              display: grid;
              grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
              gap: 10px;
            }
            .newshound-stat {
              background: rgba(255,255,255,0.1);
              padding: 12px;
              border-radius: 6px;
              text-align: center;
            }
            .newshound-stat-value {
              font-size: 24px;
              font-weight: 700;
              display: block;
            }
            .newshound-stat-label {
              font-size: 11px;
              opacity: 0.8;
              text-transform: uppercase;
              letter-spacing: 0.5px;
            }
          </style>
        CSS
      end

      def summary_badge(exception_data, job_data)
        exception_count = exception_data[:exceptions]&.length || 0
        failed_jobs = job_data.dig(:queue_stats, :failed) || 0

        if exception_count > 0 || failed_jobs > 10
          badge_class = "error"
          text = "#{exception_count} exceptions, #{failed_jobs} failed jobs"
        elsif failed_jobs > 5
          badge_class = "warning"
          text = "#{failed_jobs} failed jobs"
        else
          badge_class = "success"
          text = "All clear"
        end

        %(<span class="newshound-badge #{badge_class}">#{text}</span>)
      end

      def render_exceptions(data)
        exceptions = data[:exceptions] || []

        if exceptions.empty?
          return %(<div class="newshound-section"><div class="newshound-section-title">✅ Exceptions</div><div class="newshound-item">No exceptions in the last 24 hours</div></div>)
        end

        items = exceptions.take(5).map do |ex|
          <<~HTML
            <div class="newshound-item">
              <div class="newshound-item-title">#{escape_html(ex[:title])}</div>
              <div class="newshound-item-detail">
                #{escape_html(ex[:message])} • #{escape_html(ex[:location])} • #{escape_html(ex[:time])}
              </div>
            </div>
          HTML
        end.join

        <<~HTML
          <div class="newshound-section">
            <div class="newshound-section-title">⚠️ Recent Exceptions (#{exceptions.length})</div>
            #{items}
          </div>
        HTML
      end

      def render_jobs(data)
        stats = data[:queue_stats] || {}

        <<~HTML
          <div class="newshound-section">
            <div class="newshound-section-title">📊 Job Queue Status</div>
            <div class="newshound-grid">
              <div class="newshound-stat">
                <span class="newshound-stat-value">#{stats[:ready_to_run] || 0}</span>
                <span class="newshound-stat-label">Ready</span>
              </div>
              <div class="newshound-stat">
                <span class="newshound-stat-value">#{stats[:scheduled] || 0}</span>
                <span class="newshound-stat-label">Scheduled</span>
              </div>
              <div class="newshound-stat">
                <span class="newshound-stat-value">#{stats[:failed] || 0}</span>
                <span class="newshound-stat-label">Failed</span>
              </div>
              <div class="newshound-stat">
                <span class="newshound-stat-value">#{stats[:completed_today] || 0}</span>
                <span class="newshound-stat-label">Completed Today</span>
              </div>
            </div>
          </div>
        HTML
      end

      def escape_html(text)
        return String.new unless text.present?
        text.to_s
          .gsub('&', '&amp;')
          .gsub('<', '&lt;')
          .gsub('>', '&gt;')
          .gsub('"', '&quot;')
          .gsub("'", '&#39;')
      end
    end
  end
end
