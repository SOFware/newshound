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
        controller = env["action_controller.instance"]
        return [status, headers, response] unless controller
        return [status, headers, response] unless Newshound::Authorization.authorized?(controller)

        # Get banner HTML (nil when nothing notable to display)
        banner_html = generate_banner_html
        return [status, headers, response] unless banner_html

        # Inject banner after <body> tag
        new_response = inject_banner(response, banner_html)

        # Update Content-Length header
        if headers["Content-Length"]
          headers["Content-Length"] = new_response.bytesize.to_s
        end

        [status, headers, [new_response]]
      end

      private

      def html_response?(headers)
        content_type = headers["Content-Type"]
        content_type&.include?("text/html")
      end

      def inject_banner(response, banner_html)
        body = response_body(response)

        # Inject after <body> tag
        body.sub(/(<body[^>]*>)/i, "\\1\n#{banner_html}")
      end

      def response_body(response)
        body = +""
        response.each { |part| body << part }
        body
      end

      def generate_banner_html
        exception_reporter = Newshound::ExceptionReporter.new
        job_reporter = Newshound::JobReporter.new
        warning_reporter = Newshound::WarningReporter.new

        exception_data = exception_reporter.banner_data
        job_data = job_reporter.banner_data
        warning_data = warning_reporter.banner_data

        return nil unless notable_data?(exception_data, job_data, warning_data)

        render_banner(exception_data, job_data, warning_data)
      end

      def notable_data?(exception_data, job_data, warning_data)
        exception_count = exception_data[:exceptions]&.length || 0
        failed_jobs = job_data.dig(:queue_stats, :failed) || 0
        warning_count = warning_data[:warnings]&.length || 0
        threshold = Newshound.configuration.failed_jobs_threshold

        exception_count > 0 || warning_count > 0 || failed_jobs > threshold
      end

      # The stylesheet is a sibling of the banner so closing can remove the banner
      # without taking the `html body` padding rule down with it.
      def render_banner(exception_data, job_data, warning_data = {})
        <<~HTML
          #{render_styles}
          <div id="newshound-banner" class="#{positioned_class(:banner)} newshound-banner-collapsed" data-newshound-signature="#{escape_html(banner_signature(exception_data, job_data, warning_data))}">
            <div class="newshound-header" data-newshound-action="toggle">
              <span class="newshound-title">
                🐕 Newshound
                #{summary_badge(exception_data, job_data, warning_data)}
              </span>
              <span class="newshound-header-controls">
                #{render_header_controls}
              </span>
            </div>
            <div class="#{positioned_class(:content)}">
              #{render_exceptions(exception_data)}
              #{render_warnings(warning_data)}
              #{render_jobs(job_data)}
            </div>
            #{render_restore_control}
          </div>
          #{render_script}
        HTML
      end

      # Two sections, compared by different rules. The counts only rise when there is
      # something unseen, so the script reads a rise as news and a fall as cleanup.
      # The id lists catch one item arriving while another is cleared, which leaves
      # the counts unchanged, and they work for sources whose ids are not numbers.
      def banner_signature(exception_data, job_data, warning_data)
        exceptions = exception_data[:exceptions] || []
        warnings = warning_data[:warnings] || []

        [
          [exceptions.length, warnings.length, actionable_jobs(job_data)].join(","),
          item_ids(exceptions),
          item_ids(warnings)
        ].join("|")
      end

      # Mirror what the banner itself treats as worth showing: jobs at or below the
      # threshold never raise it, so a rise within that tolerance is not news either.
      # Adapters predating the failing/expired split report :failed alone.
      def actionable_jobs(job_data)
        stats = job_data[:queue_stats] || {}
        count = stats.fetch(:expired) { stats[:failed] } || 0

        (count > Newshound.configuration.failed_jobs_threshold) ? count : 0
      end

      def item_ids(items)
        items.filter_map { |item| item[:id] }.join(",")
      end

      def render_header_controls
        <<~HTML
          <button type="button" class="newshound-control newshound-toggle" data-newshound-action="toggle" aria-expanded="false" aria-label="Toggle Newshound details" title="Toggle details">▼</button>
          <button type="button" class="newshound-control newshound-minimize" data-newshound-action="minimize" aria-label="Minimize Newshound" title="Minimize to a corner pill">−</button>
          <button type="button" class="newshound-control newshound-close" data-newshound-action="close" aria-label="Close Newshound" title="Close (returns minimized on the next page)">×</button>
        HTML
      end

      # The only way back once the banner is minimized, so it is always rendered and
      # always focusable.
      def render_restore_control
        <<~HTML
          <button type="button" class="newshound-control newshound-restore" data-newshound-action="restore" aria-label="Restore Newshound" title="Restore Newshound">🐕</button>
        HTML
      end

      def render_script
        <<~JS
          <script>
            (function() {
              function banner() {
                return document.getElementById('newshound-banner');
              }

              // Read once: closing detaches the banner, and the flag is written
              // after that.
              var signature = banner().getAttribute('data-newshound-signature');

              // localStorage throws in some private-browsing modes, and a throw here
              // would leave a control half-applied.
              function rememberMinimized() {
                try {
                  localStorage.setItem('newshound-minimized', '1');
                  localStorage.setItem('newshound-signature', signature);
                } catch (e) {}
              }

              function forgetMinimized() {
                try {
                  localStorage.removeItem('newshound-minimized');
                  localStorage.removeItem('newshound-signature');
                } catch (e) {}
              }

              function wasMinimized() {
                try {
                  return localStorage.getItem('newshound-minimized') === '1';
                } catch (e) {
                  return false;
                }
              }

              // Any number that has risen since the developer minimized the banner
              // is a problem they have not seen yet. Anything else — a number that
              // fell, or a signature this version cannot read — is not news.
              function hasNewNews() {
                var seen;
                try { seen = localStorage.getItem('newshound-signature'); } catch (e) {}
                if (!seen) return true;

                var now = signature.split('|');
                var before = seen.split('|');
                if (now.length !== before.length) return true;

                if (hasRisen(now[0], before[0])) return true;

                for (var s = 1; s < now.length; s++) {
                  if (hasUnseenId(now[s], before[s])) return true;
                }

                return false;
              }

              function hasRisen(counts, seenCounts) {
                var now = counts.split(',');
                var before = seenCounts.split(',');
                if (now.length !== before.length) return true;

                for (var i = 0; i < now.length; i++) {
                  if (Number(now[i]) > Number(before[i])) return true;
                }

                return false;
              }

              // Clearing an item leaves every remaining id already seen, so only an
              // arrival counts.
              function hasUnseenId(current, seen) {
                if (!current) return false;

                var known = seen ? seen.split(',') : [];
                var ids = current.split(',');

                for (var i = 0; i < ids.length; i++) {
                  if (known.indexOf(ids[i]) === -1) return true;
                }

                return false;
              }

              // Applied before the padding script below takes its first measurement.
              // A minimize lasts only until the next problem the developer has not
              // seen, so it cannot leave them blind.
              if (wasMinimized()) {
                if (hasNewNews()) {
                  forgetMinimized();
                } else {
                  banner().classList.add('newshound-banner-minimized');
                }
              }

              #{render_controls_script}

              #{render_padding_script}
            })();
          </script>
        JS
      end

      def render_controls_script
        <<~JS
          var actions = {
            toggle: function(el) {
              var expanded = !el.classList.toggle('newshound-banner-collapsed');
              var toggle = el.querySelector('.newshound-toggle');
              if (toggle) toggle.setAttribute('aria-expanded', expanded ? 'true' : 'false');
            },
            // Minimize and restore each hide the control the keyboard is sitting on,
            // so each hands focus to the one that replaces it.
            minimize: function(el) {
              el.classList.add('newshound-banner-minimized');
              rememberMinimized();
              focusControl(el, '.newshound-restore');
            },
            restore: function(el) {
              el.classList.remove('newshound-banner-minimized');
              forgetMinimized();
              focusControl(el, '.newshound-minimize');
            },
            // Closing clears the current page; the flag brings the banner back as a
            // pill on the next load rather than suppressing it for good.
            close: function(el) {
              el.remove();
              rememberMinimized();
            }
          };

          function focusControl(el, selector) {
            var control = el.querySelector(selector);
            if (control) control.focus();
          }

          // Scoped to the banner so a second injection cannot stack listeners that
          // outlive it.
          banner().addEventListener('click', function(event) {
            if (!event.target.closest) return;

            var trigger = event.target.closest('[data-newshound-action]');
            if (!trigger) return;

            var action = actions[trigger.getAttribute('data-newshound-action')];
            var el = banner();
            if (!action || !el) return;

            action(el);
            if (window.newshoundUpdatePadding) window.newshoundUpdatePadding();
          });
        JS
      end

      # A bottom banner floats over the page, so there is no space to reserve. The
      # delegated click handler still calls this, so it has to exist either way.
      def render_padding_script
        return "window.newshoundUpdatePadding = function() {};" if bottom?

        <<~JS
          var cachedPriority, cachedBodyRule;

          // Detect once whether any non-newshound stylesheet uses !important on the body padding we set
          function detectPriority() {
            var styles = document.querySelectorAll('style:not(#newshound-styles)');

            for (var i = 0; i < styles.length; i++) {
              if (styles[i].textContent.match(/body\\s*{[^}]*padding-top[^;]*!important/s)) {
                return 'important';
              }
            }

            try {
              for (var s = 0; s < document.styleSheets.length; s++) {
                var sheet = document.styleSheets[s];
                if (sheet.ownerNode && sheet.ownerNode.id === 'newshound-styles') continue;
                var rules = sheet.cssRules || [];
                for (var r = 0; r < rules.length; r++) {
                  if (rules[r].selectorText === 'body' &&
                      rules[r].style.getPropertyPriority('padding-top') === 'important') {
                    return 'important';
                  }
                }
              }
            } catch (e) {}

            return '';
          }

          // Find the html body rule in the newshound stylesheet once
          function findBodyRule() {
            var styleEl = document.getElementById('newshound-styles');
            if (!styleEl || !styleEl.sheet) return null;
            var rules = styleEl.sheet.cssRules;
            for (var i = 0; i < rules.length; i++) {
              if (rules[i].selectorText === 'html body') return rules[i];
            }
            return null;
          }

          function applyPadding(offset) {
            if (cachedBodyRule === undefined) cachedBodyRule = findBodyRule();
            if (!cachedBodyRule) return;

            if (cachedPriority === undefined) cachedPriority = detectPriority();

            cachedBodyRule.style.setProperty('padding-top', offset + 'px', cachedPriority);
          }

          window.newshoundUpdatePadding = function() {
            var el = banner();

            // A closed banner is gone and a minimized one is a floating corner pill,
            // so neither displaces the page.
            if (!el || el.classList.contains('newshound-banner-minimized')) {
              applyPadding(0);
              return;
            }

            // Measure only once the content's max-height transition has settled.
            setTimeout(function() { applyPadding(el.offsetHeight); }, 300);
          };

          if (document.readyState === 'loading') {
            document.addEventListener('DOMContentLoaded', window.newshoundUpdatePadding);
          } else {
            window.newshoundUpdatePadding();
          }

          window.addEventListener('resize', window.newshoundUpdatePadding);
        JS
      end

      def render_styles
        <<~CSS
          <style id="newshound-styles">
            #{render_body_padding_styles}
            /* Everything that varies by position or state is a custom property set
               on the banner. The rules below inherit those values, so each element
               is styled by its own flat selector instead of by its ancestry. */
            .newshound-banner {
              --newshound-content-display: block;
              --newshound-content-max-height: 400px;
              --newshound-content-overflow: auto;
              --newshound-divider: 1px solid rgba(255,255,255,0.2);
              --newshound-header-display: flex;
              --newshound-restore-display: none;
              --newshound-corner-radius: 0;
              position: fixed;
              left: 0;
              right: 0;
              background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
              color: white;
              z-index: 10000;
              box-shadow: var(--newshound-shadow);
              border-radius: var(--newshound-corner-radius);
              font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
              font-size: 14px;
            }
            .newshound-banner-top {
              --newshound-shadow: 0 2px 10px rgba(0,0,0,0.3);
              --newshound-toggle-rotation: 0deg;
              --newshound-collapsed-toggle-rotation: -90deg;
              --newshound-minimized-shadow: -2px 2px 6px rgba(0,0,0,0.2);
              --newshound-minimized-corner-radius: 0 0 0 8px;
              top: 0;
            }
            /* Laid out in reverse so the header still sits on the viewport edge and
               the panel expands upward into the page. */
            .newshound-banner-bottom {
              --newshound-shadow: 0 -2px 10px rgba(0,0,0,0.3);
              --newshound-toggle-rotation: 180deg;
              --newshound-collapsed-toggle-rotation: 270deg;
              --newshound-minimized-shadow: -2px -2px 6px rgba(0,0,0,0.2);
              --newshound-minimized-corner-radius: 8px 0 0 0;
              bottom: 0;
              display: flex;
              flex-direction: column-reverse;
            }
            /* State comes after position so it wins the properties they share. */
            .newshound-banner-collapsed {
              --newshound-content-max-height: 0px;
              --newshound-content-overflow: hidden;
              --newshound-divider: none;
              --newshound-toggle-rotation: var(--newshound-collapsed-toggle-rotation);
            }
            .newshound-banner-minimized {
              /* Taken out of layout rather than collapsed to zero height: a
                 shrink-to-fit banner otherwise sizes itself to the hidden
                 content's width. */
              --newshound-content-display: none;
              --newshound-header-display: none;
              --newshound-restore-display: flex;
              --newshound-shadow: var(--newshound-minimized-shadow);
              --newshound-corner-radius: var(--newshound-minimized-corner-radius);
              left: auto;
            }
            .newshound-header {
              padding: 12px 20px;
              cursor: pointer;
              display: var(--newshound-header-display, flex);
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
            .newshound-error {
              background: #ef4444;
            }
            .newshound-warning {
              background: #f59e0b;
            }
            .newshound-success {
              background: #10b981;
            }
            .newshound-toggle {
              transition: transform 0.3s;
              transform: rotate(var(--newshound-toggle-rotation, 0deg));
            }
            .newshound-content {
              display: var(--newshound-content-display, block);
              max-height: var(--newshound-content-max-height, 400px);
              overflow: var(--newshound-content-overflow, auto);
              transition: max-height 0.3s ease-out;
            }
            /* The divider sits between the header and the panel, which means the
               top edge of the content at the top and its bottom edge at the bottom. */
            .newshound-content-top {
              border-top: var(--newshound-divider);
            }
            .newshound-content-bottom {
              border-bottom: var(--newshound-divider);
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
            .newshound-link {
              color: inherit;
              text-decoration: none;
            }
            .newshound-link:hover {
              text-decoration: underline;
            }
            a.newshound-stat {
              color: inherit;
              text-decoration: none;
            }
            a.newshound-stat:hover {
              background: rgba(255,255,255,0.2);
            }
            .newshound-header-controls {
              display: flex;
              align-items: center;
              gap: 12px;
            }
            .newshound-control {
              background: none;
              border: 0;
              margin: 0;
              padding: 0 4px;
              color: inherit;
              font: inherit;
              line-height: 1;
              cursor: pointer;
              opacity: 0.7;
            }
            .newshound-control:hover,
            .newshound-control:focus-visible {
              opacity: 1;
            }
            .newshound-control:focus-visible {
              outline: 2px solid #fff;
              outline-offset: 2px;
            }
            .newshound-minimize,
            .newshound-close {
              font-size: 18px;
              font-weight: 700;
            }
            .newshound-restore {
              display: var(--newshound-restore-display, none);
              align-items: center;
              justify-content: center;
              width: 36px;
              height: 36px;
              padding: 0;
              opacity: 1;
              font-size: 16px;
              user-select: none;
            }
          </style>
        CSS
      end

      def bottom?
        Newshound.configuration.position == :bottom
      end

      # Position is settled before a byte of HTML goes out, so elements that differ
      # between the two edges say so themselves -- "newshound-content
      # newshound-content-bottom" -- rather than making the stylesheet work it out
      # from an ancestor.
      def positioned_class(name)
        "newshound-#{name} newshound-#{name}-#{Newshound.configuration.position}"
      end

      # Only a top banner pushes the page down; a bottom one floats over it.
      def render_body_padding_styles
        return "" if bottom?

        <<~CSS
          html body {
            padding-top: 50px;
            transition: padding-top 0.3s ease-out;
          }
        CSS
      end

      def summary_badge(exception_data, job_data, warning_data = {})
        exception_count = exception_data[:exceptions]&.length || 0
        failed_jobs = job_data.dig(:queue_stats, :failed) || 0
        warning_count = warning_data[:warnings]&.length || 0
        threshold = Newshound.configuration.failed_jobs_threshold

        if exception_count > 0
          badge_class = "newshound-error"
          text = "#{exception_count} exceptions"
        else
          badge_class = "newshound-warning"
          parts = []
          parts << "#{warning_count} warnings" if warning_count > 0
          parts << "#{failed_jobs} failed jobs" if failed_jobs > threshold
          text = parts.join(", ")
        end

        %(<span class="newshound-badge #{badge_class}">#{text}</span>)
      end

      def render_exceptions(data)
        exceptions = data[:exceptions] || []

        if exceptions.empty?
          return %(<div class="newshound-section"><div class="newshound-section-title">✅ Exceptions</div><div class="newshound-item">No exceptions in the last 24 hours</div></div>)
        end

        render_item_section(
          items: exceptions,
          links: Newshound.configuration.exception_links,
          title: "⚠️ Recent Exceptions (#{exceptions.length})"
        )
      end

      def render_warnings(data)
        warnings = data[:warnings] || []

        return "" if warnings.empty?

        render_item_section(
          items: warnings,
          links: Newshound.configuration.warning_links,
          title: "⚠️ Warnings (#{warnings.length})"
        )
      end

      def render_item_section(items:, links:, title:)
        rendered_items = items.take(5).map do |item|
          item_content = <<~HTML
            <div class="newshound-item-title">#{escape_html(item[:title])}</div>
            <div class="newshound-item-detail">
              #{escape_html(item[:message])} • #{escape_html(item[:location])} • #{escape_html(item[:time])}
            </div>
          HTML

          if links[:show] && item[:id]
            url = links[:show].gsub(":id", item[:id].to_s)
            %(<a href="#{escape_html(url)}" class="newshound-link"><div class="newshound-item">#{item_content}</div></a>)
          else
            %(<div class="newshound-item">#{item_content}</div>)
          end
        end.join

        title_html = if links[:index]
          %(<a href="#{escape_html(links[:index])}" class="newshound-link">#{title}</a>)
        else
          title
        end

        <<~HTML
          <div class="newshound-section">
            <div class="newshound-section-title">#{title_html}</div>
            #{rendered_items}
          </div>
        HTML
      end

      def render_jobs(data)
        stats = data[:queue_stats] || {}
        links = Newshound.configuration.job_links

        section_title = "📊 Job Queue Status"
        title_html = if links[:index]
          %(<a href="#{escape_html(links[:index])}" class="newshound-link">#{section_title}</a>)
        else
          section_title
        end

        <<~HTML
          <div class="newshound-section">
            <div class="newshound-section-title">#{title_html}</div>
            <div class="newshound-grid">
              #{render_job_stat(stats[:ready_to_run] || 0, "Ready", links[:index])}
              #{render_job_stat(stats[:scheduled] || 0, "Scheduled", links[:scheduled])}
              #{render_job_stat(stats[:failed] || 0, "Failed", links[:failed])}
              #{render_job_stat(stats[:completed_today] || 0, "Completed Today", links[:completed])}
            </div>
          </div>
        HTML
      end

      def render_job_stat(value, label, link)
        content = <<~HTML
          <span class="newshound-stat-value">#{value}</span>
          <span class="newshound-stat-label">#{label}</span>
        HTML

        if link
          %(<a href="#{escape_html(link)}" class="newshound-stat">#{content}</a>)
        else
          %(<div class="newshound-stat">#{content}</div>)
        end
      end

      def escape_html(text)
        return +"" unless text.present?

        text.to_s
          .gsub("&", "&amp;")
          .gsub("<", "&lt;")
          .gsub(">", "&gt;")
          .gsub('"', "&quot;")
          .gsub("'", "&#39;")
      end
    end
  end
end
