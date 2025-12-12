# frozen_string_literal: true

RSpec.describe Newshound::Warnings::Base do
  subject(:base) { described_class.new }

  describe "#recent" do
    it "raises NotImplementedError" do
      expect {
        base.recent(time_range: 24.hours, limit: 10)
      }.to raise_error(NotImplementedError, /must implement #recent/)
    end
  end

  describe "#format_for_report" do
    it "raises NotImplementedError" do
      expect {
        base.format_for_report(double("warning"), 1)
      }.to raise_error(NotImplementedError, /must implement #format_for_report/)
    end
  end

  describe "#format_for_banner" do
    it "raises NotImplementedError" do
      expect {
        base.format_for_banner(double("warning"))
      }.to raise_error(NotImplementedError, /must implement #format_for_banner/)
    end
  end
end
