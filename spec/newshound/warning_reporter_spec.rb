# frozen_string_literal: true

RSpec.describe Newshound::WarningReporter do
  let(:warning_source) { double("warning_source") }
  let(:configuration) { double("configuration", warning_limit: 10, warning_source: nil) }
  let(:time_range) { 24.hours }

  subject(:reporter) do
    described_class.new(
      warning_source: warning_source,
      configuration: configuration,
      time_range: time_range
    )
  end

  describe "#initialize" do
    it "uses Warnings.source when given a symbol" do
      expect(Newshound::Warnings).to receive(:source).with(:test_warnings).and_return(warning_source)

      reporter = described_class.new(
        warning_source: :test_warnings,
        configuration: configuration
      )

      expect(reporter.warning_source).to eq(warning_source)
    end

    it "uses provided warning_source object directly" do
      reporter = described_class.new(
        warning_source: warning_source,
        configuration: configuration
      )

      expect(reporter.warning_source).to eq(warning_source)
    end

    it "uses Newshound.configuration when configuration is not provided" do
      allow(Newshound).to receive(:configuration).and_return(configuration)

      reporter = described_class.new(warning_source: warning_source)

      expect(reporter.configuration).to eq(configuration)
    end

    it "defaults time_range to 24.hours" do
      reporter = described_class.new(warning_source: warning_source)

      expect(reporter.time_range).to eq(24.hours)
    end

    it "uses configuration.warning_source when warning_source is nil" do
      config = double("configuration", warning_limit: 10, warning_source: :test_warnings)
      allow(Newshound).to receive(:configuration).and_return(config)
      expect(Newshound::Warnings).to receive(:source).with(:test_warnings).and_return(warning_source)

      reporter = described_class.new

      expect(reporter.warning_source).to eq(warning_source)
    end

    it "sets warning_source to nil when not configured" do
      config = double("configuration", warning_limit: 10, warning_source: nil)
      allow(Newshound).to receive(:configuration).and_return(config)

      reporter = described_class.new

      expect(reporter.warning_source).to be_nil
    end
  end

  describe "#generate_report" do
    context "when there are no recent warnings" do
      before do
        allow(warning_source).to receive(:recent).and_return([])
      end

      it "returns a no warnings message" do
        report = reporter.generate_report

        expect(report).to eq([
          {
            type: "section",
            text: {
              type: "mrkdwn",
              text: "*✅ No Warnings in the Last 24 Hours*"
            }
          }
        ])
      end
    end

    context "when there are recent warnings" do
      let(:warning1) { double("warning1") }
      let(:warning2) { double("warning2") }

      before do
        allow(warning_source).to receive(:recent).and_return([warning1, warning2])
        allow(warning_source).to receive(:format_for_report).with(warning1, 1).and_return(
          "*1. Unprocessable Event: LRS*\n• *Time:* 02:00 PM\n• *Reason:* Invalid data format"
        )
        allow(warning_source).to receive(:format_for_report).with(warning2, 2).and_return(
          "*2. Unprocessable Event: SOFLMS*\n• *Time:* 03:00 PM\n• *Reason:* Missing user UUID"
        )
      end

      it "returns a formatted report with header and warning sections" do
        report = reporter.generate_report

        expect(report.length).to eq(3) # header + 2 warnings
        expect(report[0]).to eq({
          type: "section",
          text: {
            type: "mrkdwn",
            text: "*⚠️ Recent Warnings (Last 24 Hours)*"
          }
        })
      end

      it "delegates formatting to the warning source adapter" do
        report = reporter.generate_report

        expect(warning_source).to have_received(:format_for_report).with(warning1, 1)
        expect(warning_source).to have_received(:format_for_report).with(warning2, 2)

        expect(report[1][:text][:text]).to include("Unprocessable Event: LRS")
        expect(report[2][:text][:text]).to include("Unprocessable Event: SOFLMS")
      end
    end
  end

  describe "#report" do
    it "is an alias for generate_report" do
      allow(warning_source).to receive(:recent).and_return([])

      expect(reporter.report).to eq(reporter.generate_report)
    end
  end

  describe "#banner_data" do
    context "when warning_source is nil" do
      subject(:reporter) do
        described_class.new(
          warning_source: nil,
          configuration: configuration
        )
      end

      it "returns empty warnings array" do
        data = reporter.banner_data

        expect(data).to eq({warnings: []})
      end
    end

    context "when warning_source is configured" do
      let(:warning1) { double("warning1") }

      before do
        allow(warning_source).to receive(:recent).and_return([warning1])
        allow(warning_source).to receive(:format_for_banner).with(warning1).and_return(
          {
            title: "Unprocessable: LRS",
            message: "Invalid data format",
            location: "user-123",
            time: "02:00 PM"
          }
        )
      end

      it "delegates formatting to the warning source adapter" do
        data = reporter.banner_data

        expect(warning_source).to have_received(:format_for_banner).with(warning1)
        expect(data).to have_key(:warnings)
        expect(data[:warnings].length).to eq(1)

        warning_data = data[:warnings][0]
        expect(warning_data).to include(
          title: "Unprocessable: LRS",
          message: "Invalid data format",
          location: "user-123",
          time: "02:00 PM"
        )
      end
    end
  end
end
