# frozen_string_literal: true

RSpec.describe Newshound::Exceptions::SolidErrors do
  subject(:adapter) { described_class.new }

  describe "#recent" do
    let(:mock_occurrence_class) { double("SolidErrors::Occurrence") }
    let(:mock_scope) { double("ActiveRecord::Relation") }
    let(:time_range) { 24.hours }
    let(:limit) { 10 }

    before do
      stub_const("SolidErrors::Occurrence", mock_occurrence_class)
    end

    it "queries SolidErrors::Occurrence with correct parameters" do
      expect(mock_occurrence_class).to receive(:where)
        .with("created_at >= ?", kind_of(Time))
        .and_return(mock_scope)
      expect(mock_scope).to receive(:order)
        .with(created_at: :desc)
        .and_return(mock_scope)
      expect(mock_scope).to receive(:limit)
        .with(limit)
        .and_return([])

      adapter.recent(time_range: time_range, limit: limit)
    end

    it "returns the query result" do
      mock_result = [double("occurrence1"), double("occurrence2")]

      allow(mock_occurrence_class).to receive(:where).and_return(mock_scope)
      allow(mock_scope).to receive(:order).and_return(mock_scope)
      allow(mock_scope).to receive(:limit).and_return(mock_result)

      result = adapter.recent(time_range: time_range, limit: limit)
      expect(result).to eq(mock_result)
    end
  end

  describe "#format_for_report" do
    let(:exception) do
      double(
        "occurrence",
        error_class: "ActiveRecord::RecordNotFound",
        created_at: Time.new(2025, 10, 21, 14, 30, 0),
        message: "Record not found",
        context: {"controller" => "UsersController", "action" => "show"},
        respond_to?: true
      )
    end

    before do
      allow(exception).to receive(:respond_to?).with(:error_class).and_return(true)
      allow(exception).to receive(:respond_to?).with(:message).and_return(true)
      allow(exception).to receive(:respond_to?).with(:context).and_return(true)
    end

    it "formats exception for report display" do
      result = adapter.format_for_report(exception, 1)

      expect(result).to include("*1. ActiveRecord::RecordNotFound*")
      expect(result).to include("*Time:* 02:30 PM")
      expect(result).to include("*Controller:* UsersController#show")
      expect(result).to include("*Message:* `Record not found`")
    end

    it "handles exceptions without controller info" do
      exception_without_controller = double(
        "occurrence",
        error_class: "ArgumentError",
        created_at: Time.new(2025, 10, 21, 14, 30, 0),
        message: "Invalid argument",
        context: {},
        respond_to?: true
      )
      allow(exception_without_controller).to receive(:respond_to?).with(:error_class).and_return(true)
      allow(exception_without_controller).to receive(:respond_to?).with(:message).and_return(true)
      allow(exception_without_controller).to receive(:respond_to?).with(:context).and_return(true)

      result = adapter.format_for_report(exception_without_controller, 2)

      expect(result).to include("*2. ArgumentError*")
      expect(result).not_to include("*Controller:*")
      expect(result).to include("*Message:* `Invalid argument`")
    end

    it "handles context as JSON string" do
      exception_with_json_context = double(
        "occurrence",
        error_class: "StandardError",
        created_at: Time.new(2025, 10, 21, 14, 30, 0),
        message: "Something went wrong",
        context: '{"controller":"PostsController","action":"create"}',
        respond_to?: true
      )
      allow(exception_with_json_context).to receive(:respond_to?).with(:error_class).and_return(true)
      allow(exception_with_json_context).to receive(:respond_to?).with(:message).and_return(true)
      allow(exception_with_json_context).to receive(:respond_to?).with(:context).and_return(true)

      result = adapter.format_for_report(exception_with_json_context, 1)

      expect(result).to include("*Controller:* PostsController#create")
    end
  end

  describe "#format_for_banner" do
    let(:exception) do
      double(
        "occurrence",
        error_class: "ActiveRecord::RecordNotFound",
        created_at: Time.new(2025, 10, 21, 14, 30, 0),
        message: "Record not found",
        context: {"controller" => "UsersController", "action" => "show"},
        respond_to?: true
      )
    end

    before do
      allow(exception).to receive(:respond_to?).with(:error_class).and_return(true)
      allow(exception).to receive(:respond_to?).with(:message).and_return(true)
      allow(exception).to receive(:respond_to?).with(:context).and_return(true)
    end

    it "formats exception for banner UI" do
      result = adapter.format_for_banner(exception)

      expect(result).to eq({
        title: "ActiveRecord::RecordNotFound",
        message: "Record not found",
        location: "UsersController#show",
        time: "02:30 PM"
      })
    end

    it "handles exceptions without controller info" do
      exception_without_controller = double(
        "occurrence",
        error_class: "ArgumentError",
        created_at: Time.new(2025, 10, 21, 14, 30, 0),
        message: "Invalid argument",
        context: {},
        respond_to?: true
      )
      allow(exception_without_controller).to receive(:respond_to?).with(:error_class).and_return(true)
      allow(exception_without_controller).to receive(:respond_to?).with(:message).and_return(true)
      allow(exception_without_controller).to receive(:respond_to?).with(:context).and_return(true)

      result = adapter.format_for_banner(exception_without_controller)

      expect(result[:location]).to eq("")
    end

    it "truncates long messages to 100 characters" do
      long_message = "a" * 150
      exception_with_long_message = double(
        "occurrence",
        error_class: "Error",
        created_at: Time.new(2025, 10, 21, 14, 30, 0),
        message: long_message,
        context: {},
        respond_to?: true
      )
      allow(exception_with_long_message).to receive(:respond_to?).with(:error_class).and_return(true)
      allow(exception_with_long_message).to receive(:respond_to?).with(:message).and_return(true)
      allow(exception_with_long_message).to receive(:respond_to?).with(:context).and_return(true)

      result = adapter.format_for_banner(exception_with_long_message)

      expect(result[:message].length).to be <= 100
    end

    it "handles message from context when exception message is empty" do
      exception_with_context_message = double(
        "occurrence",
        error_class: "StandardError",
        created_at: Time.new(2025, 10, 21, 14, 30, 0),
        message: nil,
        context: {"message" => "Error from context"},
        respond_to?: true
      )
      allow(exception_with_context_message).to receive(:respond_to?).with(:error_class).and_return(true)
      allow(exception_with_context_message).to receive(:respond_to?).with(:message).and_return(true)
      allow(exception_with_context_message).to receive(:respond_to?).with(:context).and_return(true)

      result = adapter.format_for_banner(exception_with_context_message)

      expect(result[:message]).to eq("Error from context")
    end
  end
end
