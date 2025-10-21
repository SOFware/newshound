# frozen_string_literal: true

RSpec.describe Newshound::QueReporter do
  let(:job_source) { double("job_source") }
  let(:logger) { double("logger", error: nil) }
  let(:connection) { double("connection") }

  subject(:reporter) { described_class.new(job_source: job_source, logger: logger) }

  before do
    # Mock ActiveRecord::Base.connection
    stub_const("ActiveRecord::Base", double("ActiveRecord::Base"))
    allow(ActiveRecord::Base).to receive(:connection).and_return(connection)
  end

  describe "#generate_report" do
    context "when no jobs are present" do
      before do
        # Mock job_counts_by_type query
        allow(connection).to receive(:execute).and_return([])

        # Mock queue_statistics queries
        allow(connection).to receive(:quote).and_return("'mocked_time'")
        allow(connection).to receive(:select_value).and_return(0)
      end

      it "returns a report with no jobs message" do
        report = reporter.generate_report
        expect(report).to include(
          hash_including(
            type: "section",
            text: hash_including(
              text: "*No jobs found in the queue*"
            )
          )
        )
      end
    end

    context "when jobs are present" do
      before do
        # Mock job_counts_by_type query - return rows like database would
        job_rows = [
          {"job_class" => "ProcessEmailJob", "error_count" => "0", "count" => "5"},
          {"job_class" => "ProcessEmailJob", "error_count" => "3", "count" => "2"},
          {"job_class" => "SendNotificationJob", "error_count" => "0", "count" => "10"}
        ]
        allow(connection).to receive(:execute).and_return(job_rows)

        # Mock queue_statistics queries
        allow(connection).to receive(:quote).and_return("'mocked_time'")
        allow(connection).to receive(:select_value).and_return(3, 5, 2, 15)
      end

      it "returns a report with job statistics" do
        report = reporter.generate_report

        expect(report[0]).to eq({
          type: "section",
          text: {
            type: "mrkdwn",
            text: "*📊 Que Jobs Status*"
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

    context "when an error occurs fetching statistics" do
      before do
        # Mock job_counts_by_type to return empty (no jobs)
        allow(connection).to receive(:execute).and_return([])

        # Mock queue_statistics to raise an error
        allow(connection).to receive(:quote).and_raise(StandardError, "Database connection error")
      end

      it "logs the error and returns default stats" do
        expect(logger).to receive(:error).with("Failed to fetch Que statistics: Database connection error")

        report = reporter.generate_report
        queue_health_text = report[2][:text][:text]

        expect(queue_health_text).to include("*Ready to Run:* 0")
        expect(queue_health_text).to include("*Scheduled:* 0")
        expect(queue_health_text).to include("*Failed (Retry Queue):* 0")
        expect(queue_health_text).to include("*Completed Today:* 0")
      end
    end
  end
end
