# frozen_string_literal: true

RSpec.describe Newshound::Jobs::Base do
  subject(:base) { described_class.new }

  describe "#queue_statistics" do
    it "raises NotImplementedError" do
      expect {
        base.queue_statistics
      }.to raise_error(NotImplementedError, /must implement #queue_statistics/)
    end
  end

  describe "#job_counts_by_type" do
    it "raises NotImplementedError" do
      expect {
        base.job_counts_by_type
      }.to raise_error(NotImplementedError, /must implement #job_counts_by_type/)
    end
  end

  describe "#format_for_banner" do
    it "delegates to #queue_statistics" do
      allow(base).to receive(:queue_statistics).and_return(
        ready: 1, scheduled: 2, failed: 3, finished_today: 4
      )

      result = base.format_for_banner

      expect(result).to eq(
        queue_stats: {
          ready_to_run: 1,
          scheduled: 2,
          failed: 3,
          completed_today: 4
        }
      )
    end
  end
end
