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
    let(:error_record) do
      double(
        "error",
        exception_class: "ActiveRecord::RecordNotFound",
        message: "Record not found"
      )
    end

    let(:exception) do
      double(
        "occurrence",
        created_at: Time.new(2025, 10, 21, 14, 30, 0),
        context: {"controller" => "UsersController", "action" => "show"},
        respond_to?: true,
        error: error_record
      )
    end

    before do
      allow(exception).to receive(:respond_to?).with(:context).and_return(true)
      allow(exception).to receive(:try).with(:error).and_return(error_record)
    end

    it "formats exception for report display" do
      result = adapter.format_for_report(exception, 1)

      expect(result).to include("*1. ActiveRecord::RecordNotFound*")
      expect(result).to include("*Time:* 02:30 PM")
      expect(result).to include("*Controller:* UsersController#show")
      expect(result).to include("*Message:* `Record not found`")
    end

    it "handles exceptions without controller info" do
      error_without_controller = double(
        "error",
        exception_class: "ArgumentError",
        message: "Invalid argument"
      )

      exception_without_controller = double(
        "occurrence",
        created_at: Time.new(2025, 10, 21, 14, 30, 0),
        context: {},
        respond_to?: true,
        error: error_without_controller
      )
      allow(exception_without_controller).to receive(:respond_to?).with(:context).and_return(true)
      allow(exception_without_controller).to receive(:try).with(:error).and_return(error_without_controller)

      result = adapter.format_for_report(exception_without_controller, 2)

      expect(result).to include("*2. ArgumentError*")
      expect(result).not_to include("*Controller:*")
      expect(result).to include("*Message:* `Invalid argument`")
    end

    it "handles context as JSON string" do
      error_with_json = double(
        "error",
        exception_class: "StandardError",
        message: "Something went wrong"
      )

      exception_with_json_context = double(
        "occurrence",
        created_at: Time.new(2025, 10, 21, 14, 30, 0),
        context: '{"controller":"PostsController","action":"create"}',
        respond_to?: true,
        error: error_with_json
      )
      allow(exception_with_json_context).to receive(:respond_to?).with(:context).and_return(true)
      allow(exception_with_json_context).to receive(:try).with(:error).and_return(error_with_json)

      result = adapter.format_for_report(exception_with_json_context, 1)

      expect(result).to include("*Controller:* PostsController#create")
    end
  end

  describe "#format_for_banner" do
    let(:error_record) do
      double(
        "error",
        exception_class: "ActiveRecord::RecordNotFound",
        message: "Record not found"
      )
    end

    let(:exception) do
      double(
        "occurrence",
        created_at: Time.new(2025, 10, 21, 14, 30, 0),
        context: {"controller" => "UsersController", "action" => "show"},
        respond_to?: true,
        error: error_record
      )
    end

    before do
      allow(exception).to receive(:respond_to?).with(:context).and_return(true)
      allow(exception).to receive(:try).with(:error).and_return(error_record)
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
      error_without_controller = double(
        "error",
        exception_class: "ArgumentError",
        message: "Invalid argument"
      )

      exception_without_controller = double(
        "occurrence",
        created_at: Time.new(2025, 10, 21, 14, 30, 0),
        context: {},
        respond_to?: true,
        error: error_without_controller
      )
      allow(exception_without_controller).to receive(:respond_to?).with(:context).and_return(true)
      allow(exception_without_controller).to receive(:try).with(:error).and_return(error_without_controller)

      result = adapter.format_for_banner(exception_without_controller)

      expect(result[:location]).to eq("")
    end

    it "truncates long messages to 100 characters" do
      long_message = "a" * 150
      long_error = double(
        "error",
        exception_class: "Error",
        message: long_message
      )

      exception_with_long_message = double(
        "occurrence",
        created_at: Time.new(2025, 10, 21, 14, 30, 0),
        context: {},
        respond_to?: true,
        error: long_error
      )
      allow(exception_with_long_message).to receive(:respond_to?).with(:context).and_return(true)
      allow(exception_with_long_message).to receive(:try).with(:error).and_return(long_error)

      result = adapter.format_for_banner(exception_with_long_message)

      expect(result[:message].length).to be <= 100
    end

    it "handles message from context when exception message is empty" do
      error_with_empty_message = double(
        "error",
        exception_class: "StandardError",
        message: nil
      )

      exception_with_context_message = double(
        "occurrence",
        created_at: Time.new(2025, 10, 21, 14, 30, 0),
        context: {"message" => "Error from context"},
        respond_to?: true,
        error: error_with_empty_message
      )
      allow(exception_with_context_message).to receive(:respond_to?).with(:context).and_return(true)
      allow(exception_with_context_message).to receive(:try).with(:error).and_return(error_with_empty_message)

      result = adapter.format_for_banner(exception_with_context_message)

      expect(result[:message]).to eq("Error from context")
    end
  end
end
