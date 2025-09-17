# frozen_string_literal: true

RSpec.describe Newshound::QueReporter do
  let(:job_source) { double("job_source") }
  let(:logger) { double("logger") }

  subject(:reporter) { described_class.new(job_source: job_source, logger: logger) }

  describe "#generate_report" do
    context "when no jobs are present" do
      before do
        allow(job_source).to receive(:group).and_return(double(group: double(count: {})))

        unfinished_mock = double("unfinished")
        allow(job_source).to receive(:where).with(finished_at: nil, expired_at: nil).and_return(unfinished_mock)
        allow(unfinished_mock).to receive(:where).with("run_at <= ?", anything).and_return(double(count: 0))
        allow(unfinished_mock).to receive(:where).with("run_at > ?", anything).and_return(double(count: 0))

        allow(job_source).to receive(:where).with(no_args).and_return(
          double("all").tap do |d|
            allow(d).to receive(:not).with(error_count: 0).and_return(
              double("with_errors").tap do |e|
                allow(e).to receive(:where).with(finished_at: nil).and_return(double(count: 0))
              end
            )
          end
        )

        allow(job_source).to receive(:where).with("finished_at >= ?", anything).and_return(double(count: 0))
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
      let(:job_counts) do
        {
          ["ProcessEmailJob", 0] => 5,
          ["ProcessEmailJob", 3] => 2,
          ["SendNotificationJob", 0] => 10
        }
      end

      before do
        job_group_mock = double("job_group")
        allow(job_source).to receive(:group).with(:job_class).and_return(job_group_mock)
        allow(job_group_mock).to receive(:group).with(:error_count).and_return(double(count: job_counts))

        ready_mock = double("ready", count: 3)
        scheduled_mock = double("scheduled", count: 5)
        failed_mock = double("failed", count: 2)
        finished_mock = double("finished", count: 15)

        allow(job_source).to receive(:where)
          .with(finished_at: nil, expired_at: nil)
          .and_return(double("unfinished").tap do |d|
            allow(d).to receive(:where).with("run_at <= ?", anything).and_return(ready_mock)
            allow(d).to receive(:where).with("run_at > ?", anything).and_return(scheduled_mock)
          end)

        allow(job_source).to receive(:where)
          .with(no_args)
          .and_return(double("all").tap do |d|
            allow(d).to receive(:not).with(error_count: 0).and_return(
              double("with_errors").tap do |e|
                allow(e).to receive(:where).with(finished_at: nil).and_return(failed_mock)
              end
            )
          end)

        allow(job_source).to receive(:where)
          .with("finished_at >= ?", anything)
          .and_return(finished_mock)
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
        allow(job_source).to receive(:group).and_return(double(group: double(count: {})))
        allow(job_source).to receive(:where).and_raise(StandardError, "Database connection error")
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