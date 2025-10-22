# frozen_string_literal: true

RSpec.describe Newshound::Exceptions do
  describe ".source" do
    context "when given :exception_track" do
      it "returns an ExceptionTrack instance" do
        source = described_class.source(:exception_track)
        expect(source).to be_a(Newshound::Exceptions::ExceptionTrack)
      end
    end

    context "when given an invalid source" do
      it "raises an error" do
        expect {
          described_class.source(:invalid_source)
        }.to raise_error("Invalid exception source: invalid_source")
      end
    end

    context "when given nil" do
      it "raises an error" do
        expect {
          described_class.source(nil)
        }.to raise_error("Invalid exception source: ")
      end
    end
  end
end
