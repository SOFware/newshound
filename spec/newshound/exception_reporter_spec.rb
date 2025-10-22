# frozen_string_literal: true

RSpec.describe Newshound::ExceptionReporter do
  let(:exception_source) { double("exception_source") }
  let(:configuration) { double("configuration", exception_limit: 10) }
  let(:time_range) { 24.hours }

  subject(:reporter) do
    described_class.new(
      exception_source: exception_source,
      configuration: configuration,
      time_range: time_range
    )
  end

  describe "#initialize" do
    it "uses Exceptions.source when given a symbol" do
      expect(Newshound::Exceptions).to receive(:source).with(:exception_track).and_return(exception_source)

      reporter = described_class.new(
        exception_source: :exception_track,
        configuration: configuration
      )

      expect(reporter.exception_source).to eq(exception_source)
    end

    it "uses provided exception_source object directly" do
      reporter = described_class.new(
        exception_source: exception_source,
        configuration: configuration
      )

      expect(reporter.exception_source).to eq(exception_source)
    end

    it "uses Newshound.configuration when configuration is not provided" do
      allow(Newshound).to receive(:configuration).and_return(configuration)

      reporter = described_class.new(exception_source: exception_source)

      expect(reporter.configuration).to eq(configuration)
    end

    it "defaults time_range to 24.hours" do
      reporter = described_class.new(exception_source: exception_source)

      expect(reporter.time_range).to eq(24.hours)
    end
  end

  describe "#generate_report" do
    context "when there are no recent exceptions" do
      before do
        allow(exception_source).to receive(:recent).and_return([])
      end

      it "returns a no exceptions message" do
        report = reporter.generate_report

        expect(report).to eq([
          {
            type: "section",
            text: {
              type: "mrkdwn",
              text: "*✅ No Exceptions in the Last 24 Hours*"
            }
          }
        ])
      end
    end

    context "when there are recent exceptions" do
      let(:exception1) { double("exception1") }
      let(:exception2) { double("exception2") }

      before do
        allow(exception_source).to receive(:recent).and_return([exception1, exception2])
        allow(exception_source).to receive(:format_for_report).with(exception1, 1).and_return(
          "*1. ActiveRecord::RecordNotFound*\n• *Time:* 02:00 PM\n• *Controller:* UsersController#show\n• *Message:* `Record not found`"
        )
        allow(exception_source).to receive(:format_for_report).with(exception2, 2).and_return(
          "*2. ArgumentError*\n• *Time:* 03:00 PM\n• *Message:* `Invalid argument`"
        )
      end

      it "returns a formatted report with header and exception sections" do
        report = reporter.generate_report

        expect(report.length).to eq(3) # header + 2 exceptions
        expect(report[0]).to eq({
          type: "section",
          text: {
            type: "mrkdwn",
            text: "*🚨 Recent Exceptions (Last 24 Hours)*"
          }
        })
      end

      it "delegates formatting to the exception source adapter" do
        report = reporter.generate_report

        expect(exception_source).to have_received(:format_for_report).with(exception1, 1)
        expect(exception_source).to have_received(:format_for_report).with(exception2, 2)

        expect(report[1][:text][:text]).to include("ActiveRecord::RecordNotFound")
        expect(report[2][:text][:text]).to include("ArgumentError")
      end
    end
  end

  describe "#report" do
    it "is an alias for generate_report" do
      allow(exception_source).to receive(:recent).and_return([])

      expect(reporter.report).to eq(reporter.generate_report)
    end
  end

  describe "#banner_data" do
    let(:exception1) { double("exception1") }

    before do
      allow(exception_source).to receive(:recent).and_return([exception1])
      allow(exception_source).to receive(:format_for_banner).with(exception1).and_return(
        {
          title: "ActiveRecord::RecordNotFound",
          message: "Record not found",
          location: "UsersController#show",
          time: "02:00 PM"
        }
      )
    end

    it "delegates formatting to the exception source adapter" do
      data = reporter.banner_data

      expect(exception_source).to have_received(:format_for_banner).with(exception1)
      expect(data).to have_key(:exceptions)
      expect(data[:exceptions].length).to eq(1)

      exception_data = data[:exceptions][0]
      expect(exception_data).to include(
        title: "ActiveRecord::RecordNotFound",
        message: "Record not found",
        location: "UsersController#show",
        time: "02:00 PM"
      )
    end
  end
end
