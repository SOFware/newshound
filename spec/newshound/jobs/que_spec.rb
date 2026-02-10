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
        allow(connection).to receive(:select_value).and_return(3, 5, 2, 15)
      end

      it "returns queue statistics" do
        stats = adapter.queue_statistics

        expect(stats).to eq(
          ready: 3,
          scheduled: 5,
          failed: 2,
          finished_today: 15
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

        expect(stats).to eq(ready: 0, scheduled: 0, failed: 0, finished_today: 0)
      end
    end
  end

  describe "#job_counts_by_type" do
    context "when jobs are present" do
      before do
        job_rows = [
          {"job_class" => "ProcessEmailJob", "error_count" => "0", "count" => "5"},
          {"job_class" => "ProcessEmailJob", "error_count" => "3", "count" => "2"},
          {"job_class" => "SendNotificationJob", "error_count" => "0", "count" => "10"}
        ]
        allow(connection).to receive(:execute).and_return(job_rows)
      end

      it "returns job counts grouped by type" do
        counts = adapter.job_counts_by_type

        expect(counts).to eq(
          "ProcessEmailJob" => {success: 5, failed: 2, total: 7},
          "SendNotificationJob" => {success: 10, failed: 0, total: 10}
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
      allow(connection).to receive(:select_value).and_return(3, 5, 2, 15)
    end

    it "returns data formatted for the banner" do
      data = adapter.format_for_banner

      expect(data).to eq(
        queue_stats: {
          ready_to_run: 3,
          scheduled: 5,
          failed: 2,
          completed_today: 15
        }
      )
    end
  end
end
