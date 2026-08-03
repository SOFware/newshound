# frozen_string_literal: true

RSpec.describe Newshound::Jobs::Que do
  let(:connection) { double("connection") }
  let(:logger) { double("logger", error: nil) }

  subject(:adapter) { described_class.new(logger: logger) }

  before do
    stub_const("ActiveRecord::Base", double("ActiveRecord::Base"))
    allow(ActiveRecord::Base).to receive(:connection).and_return(connection)
  end

  describe "#queue_statistics" do
    context "when the database is accessible" do
      before do
        allow(connection).to receive(:quote).and_return("'mocked_time'")
        allow(connection).to receive(:select_value).and_return(3, 5, 4, 2, 6, 15)
      end

      it "returns queue statistics" do
        stats = adapter.queue_statistics

        expect(stats).to eq(
          ready: 3,
          scheduled: 5,
          failing: 4,
          expired: 2,
          failed: 6,
          finished_today: 15
        )
      end

      it "counts expired jobs on expired_at alone" do
        adapter.queue_statistics

        expect(connection).to have_received(:select_value).with(
          "SELECT COUNT(*) FROM que_jobs WHERE expired_at IS NOT NULL"
        )
      end

      it "excludes expired jobs from the failing count" do
        adapter.queue_statistics

        expect(connection).to have_received(:select_value).with(
          "SELECT COUNT(*) FROM que_jobs WHERE error_count > 0 AND finished_at IS NULL AND expired_at IS NULL"
        )
      end
    end

    context "when the database is not accessible" do
      before do
        allow(connection).to receive(:quote).and_raise(StandardError, "Database connection error")
      end

      it "logs the error and returns default stats" do
        expect(logger).to receive(:error).with("Failed to fetch Que statistics: Database connection error")

        stats = adapter.queue_statistics

        expect(stats).to eq(
          ready: 0,
          scheduled: 0,
          failing: 0,
          expired: 0,
          failed: 0,
          finished_today: 0
        )
      end
    end
  end

  describe "#job_counts_by_type" do
    context "when jobs are present" do
      before do
        job_rows = [
          {"job_class" => "ProcessEmailJob", "success" => "5", "failing" => "2", "expired" => "1", "total" => "8"},
          {"job_class" => "SendNotificationJob", "success" => "10", "failing" => "0", "expired" => "0", "total" => "10"}
        ]
        allow(connection).to receive(:execute).and_return(job_rows)
      end

      it "returns job counts grouped by type" do
        counts = adapter.job_counts_by_type

        expect(counts).to eq(
          "ProcessEmailJob" => {success: 5, failing: 2, expired: 1, failed: 3, total: 8},
          "SendNotificationJob" => {success: 10, failing: 0, expired: 0, failed: 0, total: 10}
        )
      end

      it "buckets each job class into disjoint success, failing, and expired counts" do
        adapter.job_counts_by_type

        expect(connection).to have_received(:execute).with(
          a_string_including(
            "COUNT(*) FILTER (WHERE error_count = 0 AND expired_at IS NULL) AS success",
            "COUNT(*) FILTER (WHERE error_count > 0 AND expired_at IS NULL) AS failing",
            "COUNT(*) FILTER (WHERE expired_at IS NOT NULL) AS expired"
          )
        )
      end
    end

    context "when no jobs are present" do
      before do
        allow(connection).to receive(:execute).and_return([])
      end

      it "returns an empty hash" do
        expect(adapter.job_counts_by_type).to eq({})
      end
    end

    context "when the database is not accessible" do
      before do
        allow(connection).to receive(:execute).and_raise(StandardError, "Database error")
      end

      it "logs the error and returns an empty hash" do
        expect(logger).to receive(:error).with("Failed to fetch job counts: Database error")
        expect(adapter.job_counts_by_type).to eq({})
      end
    end
  end

  describe "#format_for_banner" do
    before do
      allow(connection).to receive(:quote).and_return("'mocked_time'")
      allow(connection).to receive(:select_value).and_return(3, 5, 4, 2, 6, 15)
    end

    it "returns data formatted for the banner" do
      data = adapter.format_for_banner

      expect(data).to eq(
        queue_stats: {
          ready_to_run: 3,
          scheduled: 5,
          failing: 4,
          expired: 2,
          failed: 6,
          completed_today: 15
        }
      )
    end
  end
end
