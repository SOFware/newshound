# frozen_string_literal: true

RSpec.describe Newshound::Middleware::BannerInjector do
  let(:app) { ->(env) { [200, {"Content-Type" => "text/html"}, ["<html><body>Hello</body></html>"]] } }
  let(:middleware) { described_class.new(app) }
  let(:configuration) { Newshound::Configuration.new }
  let(:controller) { double("controller") }

  let(:env) do
    {"action_controller.instance" => controller}
  end

  before do
    allow(Newshound).to receive(:configuration).and_return(configuration)
    allow(Newshound::Authorization).to receive(:authorized?).with(controller).and_return(true)

    # Default: no data from reporters
    allow_any_instance_of(Newshound::ExceptionReporter).to receive(:banner_data).and_return(exceptions: [])
    allow_any_instance_of(Newshound::JobReporter).to receive(:banner_data).and_return(queue_stats: {})
    allow_any_instance_of(Newshound::WarningReporter).to receive(:banner_data).and_return(warnings: [])
  end

  def response_body(env)
    _status, _headers, body = middleware.call(env)
    body.first
  end

  describe "exception links" do
    let(:exception_data) do
      {
        exceptions: [
          {id: 42, title: "NoMethodError", message: "undefined method", location: "UsersController#show", time: "02:30 PM"}
        ]
      }
    end

    before do
      allow_any_instance_of(Newshound::ExceptionReporter).to receive(:banner_data).and_return(exception_data)
    end

    context "when exception_links are not configured" do
      it "renders exception items without links" do
        html = response_body(env)

        expect(html).to include("NoMethodError")
        expect(html).not_to include("<a ")
      end

      it "renders the section title without a link" do
        html = response_body(env)

        expect(html).to include("Recent Exceptions")
        expect(html).not_to match(%r{<a [^>]*>.*Recent Exceptions}m)
      end
    end

    context "when exception_links index is configured" do
      before do
        configuration.exception_links = {index: "/errors"}
      end

      it "renders the section title as a link" do
        html = response_body(env)

        expect(html).to match(%r{<a [^>]*href="/errors"[^>]*>.*Recent Exceptions}m)
      end
    end

    context "when exception_links show is configured" do
      before do
        configuration.exception_links = {show: "/errors/:id"}
      end

      it "renders each exception item as a link with the ID interpolated" do
        html = response_body(env)

        expect(html).to match(%r{<a [^>]*href="/errors/42"})
      end

      it "does not render a link when the exception has no id" do
        allow_any_instance_of(Newshound::ExceptionReporter).to receive(:banner_data).and_return(
          exceptions: [
            {title: "NoMethodError", message: "undefined method", location: "UsersController#show", time: "02:30 PM"}
          ]
        )

        html = response_body(env)

        expect(html).to include("NoMethodError")
        expect(html).not_to include("<a ")
      end
    end

    context "when both index and show exception_links are configured" do
      before do
        configuration.exception_links = {index: "/errors", show: "/errors/:id"}
      end

      it "renders both the section title link and item links" do
        html = response_body(env)

        expect(html).to match(%r{<a [^>]*href="/errors"[^>]*>.*Recent Exceptions}m)
        expect(html).to match(%r{<a [^>]*href="/errors/42"})
      end
    end
  end

  describe "job links" do
    let(:job_data) do
      {
        queue_stats: {
          ready_to_run: 3,
          scheduled: 5,
          failing: 4,
          expired: 2,
          failed: 6,
          completed_today: 15
        }
      }
    end

    before do
      allow_any_instance_of(Newshound::JobReporter).to receive(:banner_data).and_return(job_data)
    end

    context "when job_links are not configured" do
      it "renders job stats without links" do
        html = response_body(env)

        expect(html).to include("Ready")
        expect(html).to include("Scheduled")
        expect(html).to include("Failing")
        expect(html).to include("Expired")
        expect(html).to include("Completed Today")
        expect(html).not_to match(%r{<a [^>]*class="newshound-stat})
      end
    end

    context "when job_links index is configured" do
      before do
        configuration.job_links = {index: "/background_jobs"}
      end

      it "renders the section title as a link" do
        html = response_body(env)

        expect(html).to match(%r{<a [^>]*href="/background_jobs"[^>]*>.*Job Queue Status}m)
      end

      it "links the Ready stat to the index" do
        html = response_body(env)

        expect(html).to match(%r{<a [^>]*href="/background_jobs"[^>]*>.*Ready}m)
      end
    end

    context "when job_links scheduled is configured" do
      before do
        configuration.job_links = {scheduled: "/background_jobs/scheduled"}
      end

      it "links the Scheduled stat" do
        html = response_body(env)

        expect(html).to match(%r{<a [^>]*href="/background_jobs/scheduled"[^>]*>.*Scheduled}m)
      end
    end

    context "when job_links failing is configured" do
      before do
        configuration.job_links = {failing: "/background_jobs/failing"}
      end

      it "links the Failing stat" do
        html = response_body(env)

        expect(html).to match(%r{<a [^>]*href="/background_jobs/failing"[^>]*>.*Failing}m)
      end
    end

    context "when job_links expired is configured" do
      before do
        configuration.job_links = {expired: "/background_jobs/expired"}
      end

      it "links the Expired stat" do
        html = response_body(env)

        expect(html).to match(%r{<a [^>]*href="/background_jobs/expired"[^>]*>.*Expired}m)
      end
    end

    context "when only the deprecated job_links failed key is configured" do
      before do
        configuration.job_links = {failed: "/background_jobs/failed"}
      end

      it "links the Failing stat to it" do
        html = response_body(env)

        expect(html).to match(%r{<a [^>]*href="/background_jobs/failed"[^>]*>.*Failing}m)
      end
    end

    context "when job_links completed is configured" do
      before do
        configuration.job_links = {completed: "/background_jobs/completed"}
      end

      it "links the Completed Today stat" do
        html = response_body(env)

        expect(html).to match(%r{<a [^>]*href="/background_jobs/completed"[^>]*>.*Completed Today}m)
      end
    end

    context "when all job_links are configured" do
      before do
        configuration.job_links = {
          index: "/background_jobs",
          scheduled: "/background_jobs/scheduled",
          failing: "/background_jobs/failing",
          expired: "/background_jobs/expired",
          completed: "/background_jobs/completed"
        }
      end

      it "links each stat to its respective path" do
        html = response_body(env)

        expect(html).to match(%r{<a [^>]*href="/background_jobs"[^>]*>.*Job Queue Status}m)
        expect(html).to match(%r{<a [^>]*href="/background_jobs/scheduled"[^>]*>.*Scheduled}m)
        expect(html).to match(%r{<a [^>]*href="/background_jobs/failing"[^>]*>.*Failing}m)
        expect(html).to match(%r{<a [^>]*href="/background_jobs/expired"[^>]*>.*Expired}m)
        expect(html).to match(%r{<a [^>]*href="/background_jobs/completed"[^>]*>.*Completed Today}m)
      end
    end
  end

  describe "warning links" do
    let(:warning_data) do
      {
        warnings: [
          {id: 7, title: "Deprecation Warning", message: "Method will be removed", location: "legacy.rb:42", time: "01:00 PM"}
        ]
      }
    end

    before do
      allow_any_instance_of(Newshound::WarningReporter).to receive(:banner_data).and_return(warning_data)
    end

    context "when warning_links are not configured" do
      it "renders warning items without links" do
        html = response_body(env)

        expect(html).to include("Deprecation Warning")
        expect(html).not_to match(%r{<a [^>]*href=.*Deprecation Warning}m)
      end
    end

    context "when warning_links index is configured" do
      before do
        configuration.warning_links = {index: "/warnings"}
      end

      it "renders the section title as a link" do
        html = response_body(env)

        expect(html).to match(%r{<a [^>]*href="/warnings"[^>]*>.*Warnings}m)
      end
    end

    context "when warning_links show is configured" do
      before do
        configuration.warning_links = {show: "/warnings/:id"}
      end

      it "renders each warning item as a link with the ID interpolated" do
        html = response_body(env)

        expect(html).to match(%r{<a [^>]*href="/warnings/7"})
      end
    end
  end

  describe "link styling" do
    before do
      configuration.exception_links = {index: "/errors", show: "/errors/:id"}
      allow_any_instance_of(Newshound::ExceptionReporter).to receive(:banner_data).and_return(
        exceptions: [{id: 1, title: "Error", message: "msg", location: "loc", time: "12:00 PM"}]
      )
    end

    it "styles links to inherit color and remove underline" do
      html = response_body(env)

      expect(html).to include("color: inherit")
      expect(html).to include("text-decoration: none")
    end
  end

  describe "no notable data" do
    it "does not inject the banner" do
      _status, _headers, body = middleware.call(env)

      expect(body.first).not_to include("newshound-banner")
      expect(body.first).to eq("<html><body>Hello</body></html>")
    end

    context "when expired jobs exceed the configured threshold" do
      before do
        allow_any_instance_of(Newshound::JobReporter).to receive(:banner_data).and_return(
          queue_stats: {expired: 3}
        )
        configuration.expired_jobs_threshold = 2
      end

      it "injects the banner" do
        html = response_body(env)

        expect(html).to include("newshound-banner")
      end

      it "names the expired jobs in the summary badge" do
        html = response_body(env)

        expect(html).to include("3 expired jobs")
      end
    end

    context "when expired jobs are at or below the configured threshold" do
      before do
        allow_any_instance_of(Newshound::JobReporter).to receive(:banner_data).and_return(
          queue_stats: {expired: 2}
        )
        configuration.expired_jobs_threshold = 2
      end

      it "does not inject the banner" do
        _status, _headers, body = middleware.call(env)

        expect(body.first).not_to include("newshound-banner")
      end
    end

    context "when jobs are failing but none have expired" do
      before do
        allow_any_instance_of(Newshound::JobReporter).to receive(:banner_data).and_return(
          queue_stats: {failing: 50, expired: 0, failed: 50}
        )
      end

      it "does not inject the banner" do
        _status, _headers, body = middleware.call(env)

        expect(body.first).not_to include("newshound-banner")
      end
    end
  end

  describe "minimize" do
    before do
      allow_any_instance_of(Newshound::ExceptionReporter).to receive(:banner_data).and_return(
        exceptions: [{title: "RuntimeError", message: "boom", location: "app.rb:1", time: "12:00 PM"}]
      )
    end

    it "includes a minimize button in the header" do
      html = response_body(env)

      expect(html).to include(%(class="newshound-control newshound-minimize"))
    end

    it "includes minimized state CSS that hides everything except the toggle" do
      html = response_body(env)

      expect(html).to include(".newshound-banner-minimized {")
      expect(html).to include("--newshound-header-display: none;")
      expect(html).to include("--newshound-restore-display: flex;")
    end

    it "recalculates body padding when minimized via script" do
      html = response_body(env)

      expect(html).to include("el.classList.add('newshound-banner-minimized');")
      expect(html).to include("window.newshoundUpdatePadding();")
    end

    it "persists minimized state to localStorage" do
      html = response_body(env)

      expect(html).to include("localStorage.setItem('newshound-minimized'")
    end

    it "restores minimized state from localStorage on load" do
      html = response_body(env)

      expect(html).to include("localStorage.getItem('newshound-minimized')")
    end

    it "clears localStorage when restoring from minimized" do
      html = response_body(env)

      expect(html).to include("localStorage.removeItem('newshound-minimized')")
    end

    it "renders the minimize control as a button with an accessible name" do
      html = response_body(env)

      expect(html).to match(%r{<button[^>]*class="[^"]*newshound-minimize})
      expect(html).to include(%(aria-label="Minimize Newshound"))
      expect(html).to include(%(title="Minimize to a corner pill"))
    end

    it "reserves no body padding while minimized rather than measuring the pill" do
      html = response_body(env)

      expect(html).to include("classList.contains('newshound-banner-minimized')")
      expect(html).to include("applyPadding(0)")
    end

    it "takes the header and content out of layout when minimized" do
      html = response_body(env)
      rule = html[/\.newshound-banner-minimized \{.*?\}/m]

      expect(rule).to include("--newshound-content-display: none;")
      expect(rule).to include("--newshound-header-display: none;")
      expect(html).to include("display: var(--newshound-content-display, block);")
    end

    it "renders the restore control as a button with an accessible name" do
      html = response_body(env)

      expect(html).to match(%r{<button[^>]*class="[^"]*newshound-restore})
      expect(html).to include(%(aria-label="Restore Newshound"))
    end

    it "applies the stored state before the padding script measures" do
      html = response_body(env)

      expect(html.index("if (wasMinimized())")).to be < html.index("newshoundUpdatePadding =")
    end
  end

  describe "close" do
    before do
      allow_any_instance_of(Newshound::ExceptionReporter).to receive(:banner_data).and_return(
        exceptions: [{title: "RuntimeError", message: "boom", location: "app.rb:1", time: "12:00 PM"}]
      )
    end

    it "renders a close button with an accessible name and a title" do
      html = response_body(env)

      expect(html).to match(%r{<button[^>]*class="[^"]*newshound-close})
      expect(html).to include(%(aria-label="Close Newshound"))
      expect(html).to include(%(title="Close (returns minimized on the next page)"))
    end

    it "removes the banner from the DOM" do
      html = response_body(env)

      expect(html).to match(/close: function\(el\) \{\s*el\.remove\(\);/)
    end

    it "persists the minimized flag so the next page shows the pill" do
      html = response_body(env)

      expect(html).to match(/close: function\(el\) \{[^}]*rememberMinimized\(\);/m)
      expect(html).to include("localStorage.setItem('newshound-minimized', '1')")
    end

    it "renders the stylesheet outside the banner so closing keeps the styles" do
      html = response_body(env)

      styles_at = html.index(%(<style id="newshound-styles">))
      banner_at = html.index(%(<div id="newshound-banner"))

      expect(styles_at).to be < banner_at
      expect(html.index("</style>")).to be < banner_at
    end

    it "never persists a state that hides the banner without a restore control" do
      html = response_body(env)

      expect(html).to include("localStorage.setItem('newshound-minimized'")
      expect(html).not_to include("localStorage.setItem('newshound-closed'")
      expect(html).not_to include("localStorage.setItem('newshound-dismissed'")
    end
  end

  describe "auto restore" do
    before do
      allow_any_instance_of(Newshound::ExceptionReporter).to receive(:banner_data).and_return(
        exceptions: [{id: 42, title: "RuntimeError", message: "boom", location: "app.rb:1", time: "12:00 PM"}]
      )
    end

    def signature(html)
      html[/data-newshound-signature="([^"]*)"/, 1]
    end

    it "renders the exception count and its ids" do
      expect(signature(response_body(env))).to eq("1,0,0|42|")
    end

    it "renders the warning count and its ids" do
      allow_any_instance_of(Newshound::WarningReporter).to receive(:banner_data).and_return(
        warnings: [{id: 7, title: "Deprecation", message: "old", location: "legacy.rb:1", time: "12:00 PM"}]
      )

      expect(signature(response_body(env))).to eq("1,1,0|42|7")
    end

    it "renders the expired job count" do
      allow_any_instance_of(Newshound::JobReporter).to receive(:banner_data).and_return(queue_stats: {expired: 3})

      expect(signature(response_body(env))).to eq("1,0,3|42|")
    end

    # A retry is not news, so it must never un-minimize the banner.
    it "ignores jobs that are still retrying" do
      allow_any_instance_of(Newshound::JobReporter).to receive(:banner_data).and_return(queue_stats: {failing: 9, expired: 0})

      expect(signature(response_body(env))).to eq("1,0,0|42|")
    end

    # The banner stays hidden at or below the threshold, so a rise inside it is not
    # news either.
    it "ignores expired jobs within the configured threshold" do
      configuration.failed_jobs_threshold = 5
      allow_any_instance_of(Newshound::JobReporter).to receive(:banner_data).and_return(queue_stats: {expired: 3})

      expect(signature(response_body(env))).to eq("1,0,0|42|")
    end

    it "counts expired jobs once they pass the threshold" do
      configuration.failed_jobs_threshold = 5
      allow_any_instance_of(Newshound::JobReporter).to receive(:banner_data).and_return(queue_stats: {expired: 6})

      expect(signature(response_body(env))).to eq("1,0,6|42|")
    end

    it "falls back to the failed count for adapters predating the split" do
      allow_any_instance_of(Newshound::JobReporter).to receive(:banner_data).and_return(queue_stats: {failed: 3})

      expect(signature(response_body(env))).to eq("1,0,3|42|")
    end

    # Bugsink ids look like "uuid-1", so a numeric reading collapses them all to 0.
    it "keeps non-numeric ids intact" do
      allow_any_instance_of(Newshound::ExceptionReporter).to receive(:banner_data).and_return(
        exceptions: [{id: "uuid-1", title: "RuntimeError", message: "boom", location: "app.rb:1", time: "12:00 PM"}]
      )

      expect(signature(response_body(env))).to eq("1,0,0|uuid-1|")
    end

    it "stores the signature alongside the minimized flag" do
      html = response_body(env)

      expect(html).to include("localStorage.setItem('newshound-signature', signature)")
    end

    it "clears the stored signature whenever the minimized flag is cleared" do
      html = response_body(env)

      expect(html).to include("localStorage.removeItem('newshound-signature')")
    end

    it "treats a risen number as news and a fallen one as nothing" do
      html = response_body(env)

      expect(html).to include("if (Number(now[i]) > Number(before[i])) return true;")
    end

    it "treats a missing stored signature as news" do
      html = response_body(env)

      expect(html).to match(/if \(!seen\) return true;/)
    end

    it "drops the minimized flag rather than leaving it stale when news arrives" do
      html = response_body(env)

      expect(html).to match(/if \(hasNewNews\(\)\) \{\s*forgetMinimized\(\);/)
    end

    it "honors the minimized flag only when nothing new has arrived" do
      html = response_body(env)

      expect(html).to match(/\} else \{\s*banner\(\)\.classList\.add\('newshound-banner-minimized'\);/)
    end

    it "reads the signature before any control can detach the banner" do
      html = response_body(env)

      read_at = html.index("var signature = banner().getAttribute")

      expect(read_at).to be < html.index("el.remove();")
      expect(read_at).to be < html.index("if (wasMinimized())")
    end

    context "when position is :bottom" do
      before { configuration.position = :bottom }

      it "renders the same signature" do
        expect(signature(response_body(env))).to eq("1,0,0|42|")
      end
    end
  end

  describe "banner controls" do
    before do
      allow_any_instance_of(Newshound::ExceptionReporter).to receive(:banner_data).and_return(
        exceptions: [{title: "RuntimeError", message: "boom", location: "app.rb:1", time: "12:00 PM"}]
      )
    end

    it "renders every control as a real button" do
      html = response_body(env)

      %w[newshound-toggle newshound-minimize newshound-close newshound-restore].each do |control|
        expect(html).to match(%r{<button type="button"[^>]*class="[^"]*#{control}})
      end
    end

    it "reports the collapsed state on the toggle" do
      html = response_body(env)

      expect(html).to match(%r{<button[^>]*newshound-toggle[^>]*aria-expanded="false"})
      expect(html).to include(%(aria-label="Toggle Newshound details"))
      expect(html).to include("setAttribute('aria-expanded'")
    end

    it "gives focused controls a visible outline" do
      html = response_body(env)

      expect(html).to include(".newshound-control:focus-visible")
    end

    it "drives every control from one delegated listener rather than inline onclick" do
      html = response_body(env)

      expect(html).not_to include("onclick=")
      expect(html).to include("banner().addEventListener('click'")
      expect(html).to match(/closest\('\[data-newshound-action\]'\)/)
    end

    it "hands focus to the control that replaces the one being hidden" do
      html = response_body(env)

      expect(html).to include("focusControl(el, '.newshound-restore');")
      expect(html).to include("focusControl(el, '.newshound-minimize');")
    end
  end

  describe "banner position" do
    before do
      allow_any_instance_of(Newshound::ExceptionReporter).to receive(:banner_data).and_return(
        exceptions: [{title: "RuntimeError", message: "boom", location: "app.rb:1", time: "12:00 PM"}]
      )
    end

    def banner_classes(html)
      html[/<div id="newshound-banner" class="([^"]*)"/, 1].split
    end

    def content_classes(html)
      html[/<div class="(newshound-content[^"]*)"/, 1].split
    end

    context "by default" do
      it "marks the banner as top-positioned" do
        expect(banner_classes(response_body(env))).to include("newshound-banner-top")
      end

      it "marks the content panel as top-positioned" do
        expect(content_classes(response_body(env))).to include("newshound-content", "newshound-content-top")
      end

      it "reserves space with body padding-top" do
        html = response_body(env)

        expect(html).to include("padding-top: 50px;")
        expect(html).to include("setProperty('padding-top'")
      end
    end

    context "when position is :bottom" do
      before { configuration.position = :bottom }

      it "marks the banner as bottom-positioned" do
        expect(banner_classes(response_body(env))).to include("newshound-banner-bottom")
      end

      it "marks the content panel as bottom-positioned" do
        expect(content_classes(response_body(env))).to include("newshound-content", "newshound-content-bottom")
      end

      it "floats over the page without reserving any body padding" do
        html = response_body(env)

        expect(html).not_to include("html body {")
        expect(html).not_to include("setProperty('padding")
      end

      it "keeps the padding hook callable for the delegated click handler" do
        html = response_body(env)

        expect(html).to include("window.newshoundUpdatePadding = function() {};")
      end

      it "renders the same minimize, close and restore controls" do
        html = response_body(env)

        %w[newshound-minimize newshound-close newshound-restore].each do |control|
          expect(html).to match(%r{<button type="button"[^>]*class="[^"]*#{control}})
        end
      end

      it "rounds the minimized pill toward the bottom edge" do
        html = response_body(env)

        expect(html).to include("--newshound-minimized-corner-radius: 8px 0 0 0;")
        expect(html).to include("border-radius: var(--newshound-corner-radius);")
      end
    end

    # Position and state are carried by classes and custom properties on the elements
    # themselves, so no rule has to walk down from an ancestor to find what it
    # styles.
    it "styles every element without reaching through the markup" do
      Newshound::Configuration::POSITIONS.each do |position|
        configuration.position = position
        nested = banner_selectors(response_body(env)).grep(/\S\s+\S/)

        expect(nested).to be_empty,
          "expected flat selectors for position :#{position}, found #{nested.inspect}"
      end
    end

    # A variant is named for what it modifies -- newshound-content-bottom rather than
    # newshound-content plus newshound-bottom -- so no rule has to stack classes to
    # identify its target.
    it "identifies every element by a single class" do
      Newshound::Configuration::POSITIONS.each do |position|
        configuration.position = position
        stacked = banner_selectors(response_body(env)).grep(/\.[\w-]+\./)

        expect(stacked).to be_empty,
          "expected one class per selector for position :#{position}, found #{stacked.inspect}"
      end
    end

    def banner_selectors(html)
      css = html[%r{<style id="newshound-styles">(.*?)</style>}m, 1]
      css.scan(/^\s*([^{}\n]+?)\s*\{/).flatten.grep(/newshound-/)
    end
  end

  describe "HTML safety" do
    before do
      configuration.exception_links = {show: "/errors/:id"}
    end

    it "escapes exception data in linked items" do
      allow_any_instance_of(Newshound::ExceptionReporter).to receive(:banner_data).and_return(
        exceptions: [{id: 1, title: "<script>alert('xss')</script>", message: "msg", location: "loc", time: "12:00 PM"}]
      )

      html = response_body(env)

      expect(html).not_to include("<script>alert")
      expect(html).to include("&lt;script&gt;")
    end
  end
end
