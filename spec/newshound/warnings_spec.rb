# frozen_string_literal: true

RSpec.describe Newshound::Warnings do
  after do
    described_class.clear_registry!
  end

  describe ".register" do
    it "adds an adapter class to the registry" do
      adapter_class = Class.new(Newshound::Warnings::Base)

      described_class.register(:custom_adapter, adapter_class)

      expect(described_class.registry[:custom_adapter]).to eq(adapter_class)
    end

    it "converts string names to symbols" do
      adapter_class = Class.new(Newshound::Warnings::Base)

      described_class.register("string_name", adapter_class)

      expect(described_class.registry[:string_name]).to eq(adapter_class)
    end
  end

  describe ".source" do
    context "when given a registered symbol" do
      it "returns a new instance of the registered adapter" do
        adapter_class = Class.new(Newshound::Warnings::Base)
        described_class.register(:test_adapter, adapter_class)

        source = described_class.source(:test_adapter)

        expect(source).to be_a(adapter_class)
      end

      it "returns a new instance each time" do
        adapter_class = Class.new(Newshound::Warnings::Base)
        described_class.register(:test_adapter, adapter_class)

        source1 = described_class.source(:test_adapter)
        source2 = described_class.source(:test_adapter)

        expect(source1).not_to be(source2)
      end
    end

    context "when given an unregistered symbol" do
      it "raises an error" do
        expect {
          described_class.source(:unknown_adapter)
        }.to raise_error("Invalid warning source: unknown_adapter")
      end
    end

    context "when given an object (not a symbol)" do
      it "returns the object as-is" do
        adapter_instance = double("adapter_instance")

        source = described_class.source(adapter_instance)

        expect(source).to eq(adapter_instance)
      end
    end
  end

  describe ".registry" do
    it "returns the current registry hash" do
      expect(described_class.registry).to be_a(Hash)
    end
  end

  describe ".clear_registry!" do
    it "removes all registered adapters" do
      adapter_class = Class.new(Newshound::Warnings::Base)
      described_class.register(:test_adapter, adapter_class)

      described_class.clear_registry!

      expect(described_class.registry).to be_empty
    end
  end
end
