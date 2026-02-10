# frozen_string_literal: true

RSpec.describe Newshound::JobReporter do
  let(:logger) { double("logger", error: nil) }
  let(:configuration) { Newshound::Configuration.new }

  describe "#initialize" do
    it "uses Jobs.source when given a symbol" do
      adapter = instance_double(Newshound::Jobs::Base)
      expect(Newshound::Jobs).to receive(:source).with(:que).and_return(adapter)

      reporter = described_class.new(
        job_source: :que,
        configuration: configuration,
        logger: logger
      )

      expect(reporter.job_source).to eq(adapter)
    end

    it "uses provided job_source object directly" do
      adapter = instance_double(Newshound::Jobs::Base)

      reporter = described_class.new(
        job_source: adapter,
        configuration: configuration,
        logger: logger
      )

      expect(reporter.job_source).to eq(adapter)
    end

    it "uses Newshound.configuration when configuration is not provided" do
      allow(Newshound).to receive(:configuration).and_return(configuration)

      reporter = described_class.new(job_source: nil, logger: logger)

      expect(reporter.configuration).to eq(configuration)
    end

    it "uses configuration.job_source when job_source is nil" do
      config = Newshound::Configuration.new
      config.job_source = :que

      adapter = instance_double(Newshound::Jobs::Base)
      expect(Newshound::Jobs).to receive(:source).with(:que).and_return(adapter)

      reporter = described_class.new(configuration: config, logger: logger)

      expect(reporter.job_source).to eq(adapter)
    end

    it "sets job_source to nil when not configured" do
      reporter = described_class.new(configuration: configuration, logger: logger)

      expect(reporter.job_source).to be_nil
    end

    it "falls back to a default logger when none provided" do
      reporter = described_class.new(configuration: configuration)

      expect(reporter.logger).to be_a(Logger)
    end
  end

  describe "#report" do
    it "is an alias for generate_report" do
      reporter = described_class.new(configuration: configuration, logger: logger)

      expect(reporter.report).to eq(reporter.generate_report)
    end
  end

  describe "when no job source is configured" do
    subject(:reporter) { described_class.new(configuration: configuration, logger: logger) }

    it "returns a no-source-configured message" do
      report = reporter.generate_report

      expect(report).to include(
        hash_including(
          type: "section",
          text: hash_including(text: "*✅ No Job Source Configured*")
        )
      )
    end

    it "returns empty queue_stats in banner_data" do
      expect(reporter.banner_data).to eq(queue_stats: {})
    end
  end

  describe "when a job source adapter is provided" do
    let(:adapter) { instance_double(Newshound::Jobs::Base) }

    subject(:reporter) { described_class.new(job_source: adapter, logger: logger) }

    context "when no jobs are present" do
      before do
        allow(adapter).to receive(:job_counts_by_type).and_return({})
        allow(adapter).to receive(:queue_statistics).and_return(
          ready: 0, scheduled: 0, failed: 0, finished_today: 0
        )
      end

      it "returns a report with no jobs message" do
        report = reporter.generate_report

        expect(report).to include(
          hash_including(
            type: "section",
            text: hash_including(text: "*No jobs found in the queue*")
          )
        )
      end
    end

    context "when jobs are present" do
      before do
        allow(adapter).to receive(:job_counts_by_type).and_return(
          "ProcessEmailJob" => {success: 5, failed: 2, total: 7},
          "SendNotificationJob" => {success: 10, failed: 0, total: 10}
        )
        allow(adapter).to receive(:queue_statistics).and_return(
          ready: 3, scheduled: 5, failed: 2, finished_today: 15
        )
      end

      it "returns a report with job statistics" do
        report = reporter.generate_report

        expect(report[0]).to eq({
          type: "section",
          text: {
            type: "mrkdwn",
            text: "*📊 Job Queue Status*"
          }
        })

        job_counts_text = report[1][:text][:text]
        expect(job_counts_text).to include("*Job Counts by Type:*")
        expect(job_counts_text).to include("ProcessEmailJob")
        expect(job_counts_text).to include("SendNotificationJob")

        queue_health_text = report[2][:text][:text]
        expect(queue_health_text).to include("*Queue Health")
        expect(queue_health_text).to include("*Ready to Run:* 3")
        expect(queue_health_text).to include("*Scheduled:* 5")
        expect(queue_health_text).to include("*Failed (Retry Queue):* 2")
        expect(queue_health_text).to include("*Completed Today:* 15")
      end
    end

    context "when the adapter raises an error" do
      it "propagates the error from job_counts_by_type" do
        allow(adapter).to receive(:job_counts_by_type).and_raise(StandardError, "adapter failure")

        expect { reporter.generate_report }.to raise_error(StandardError, "adapter failure")
      end

      it "propagates the error from queue_statistics" do
        allow(adapter).to receive(:job_counts_by_type).and_return({})
        allow(adapter).to receive(:queue_statistics).and_raise(StandardError, "adapter failure")

        expect { reporter.generate_report }.to raise_error(StandardError, "adapter failure")
      end

      it "propagates the error from format_for_banner" do
        allow(adapter).to receive(:format_for_banner).and_raise(StandardError, "adapter failure")

        expect { reporter.banner_data }.to raise_error(StandardError, "adapter failure")
      end
    end

    context "banner_data" do
      before do
        allow(adapter).to receive(:format_for_banner).and_return(
          queue_stats: {
            ready_to_run: 3,
            scheduled: 5,
            failed: 2,
            completed_today: 15
          }
        )
      end

      it "delegates to the adapter" do
        data = reporter.banner_data

        expect(data[:queue_stats][:ready_to_run]).to eq(3)
        expect(data[:queue_stats][:failed]).to eq(2)
      end
    end
  end

  describe "when job source is configured via symbol" do
    before do
      configuration.job_source = :que
    end

    it "resolves the adapter from the Jobs module" do
      stub_const("ActiveRecord::Base", double("ActiveRecord::Base"))
      allow(ActiveRecord::Base).to receive(:connection).and_return(double("connection"))

      reporter = described_class.new(configuration: configuration, logger: logger)

      expect(reporter.job_source).to be_a(Newshound::Jobs::Que)
    end
  end
end
