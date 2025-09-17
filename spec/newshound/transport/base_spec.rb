# frozen_string_literal: true

require "spec_helper"
require "newshound/transport/base"

RSpec.describe Newshound::Transport::Base do
  let(:configuration) { double("Configuration") }
  let(:logger) { double("Logger") }
  let(:transport) { described_class.new(configuration: configuration, logger: logger) }

  describe "#initialize" do
    it "accepts configuration and logger" do
      expect(transport.configuration).to eq(configuration)
      expect(transport.logger).to eq(logger)
    end

    context "with default values" do
      let(:transport) { described_class.new }

      before do
        allow(Newshound).to receive(:configuration).and_return(configuration)
      end

      it "uses default configuration" do
        expect(transport.configuration).to eq(configuration)
      end
    end
  end

  describe "#deliver" do
    it "raises NotImplementedError" do
      expect { transport.deliver({}) }.to raise_error(NotImplementedError, "Subclasses must implement the #deliver method")
    end
  end
end