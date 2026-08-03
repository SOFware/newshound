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
        expect(html).to include("Failed")
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

    context "when job_links failed is configured" do
      before do
        configuration.job_links = {failed: "/background_jobs/failed"}
      end

      it "links the Failed stat" do
        html = response_body(env)

        expect(html).to match(%r{<a [^>]*href="/background_jobs/failed"[^>]*>.*Failed}m)
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
          failed: "/background_jobs/failed",
          completed: "/background_jobs/completed"
        }
      end

      it "links each stat to its respective path" do
        html = response_body(env)

        expect(html).to match(%r{<a [^>]*href="/background_jobs"[^>]*>.*Job Queue Status}m)
        expect(html).to match(%r{<a [^>]*href="/background_jobs/scheduled"[^>]*>.*Scheduled}m)
        expect(html).to match(%r{<a [^>]*href="/background_jobs/failed"[^>]*>.*Failed}m)
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

    context "when failed jobs exceed the configured threshold" do
      before do
        allow_any_instance_of(Newshound::JobReporter).to receive(:banner_data).and_return(
          queue_stats: {failed: 3}
        )
        configuration.failed_jobs_threshold = 2
      end

      it "injects the banner" do
        html = response_body(env)

        expect(html).to include("newshound-banner")
      end
    end

    context "when failed jobs are at or below the configured threshold" do
      before do
        allow_any_instance_of(Newshound::JobReporter).to receive(:banner_data).and_return(
          queue_stats: {failed: 2}
        )
        configuration.failed_jobs_threshold = 2
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

      expect(html).to include("newshound-minimize")
    end

    it "includes minimized state CSS that hides everything except the toggle" do
      html = response_body(env)

      expect(html).to include("newshound-minimized")
    end

    it "sets body padding to 0 when minimized via script" do
      html = response_body(env)

      expect(html).to include("newshound-minimized")
      expect(html).to include("newshoundUpdatePadding")
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

      it "keeps the padding hook callable for the header's onclick" do
        html = response_body(env)

        expect(html).to include("window.newshoundUpdatePadding = function() {};")
      end
    end

    # Position and state are carried by classes and custom properties on the
    # elements themselves, so no rule has to walk down from an ancestor to find
    # what it styles.
    it "styles every element without reaching through the markup" do
      Newshound::Configuration::POSITIONS.each do |position|
        configuration.position = position
        nested = banner_selectors(response_body(env)).grep(/\S\s+\S/)

        expect(nested).to be_empty,
          "expected flat selectors for position :#{position}, found #{nested.inspect}"
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
