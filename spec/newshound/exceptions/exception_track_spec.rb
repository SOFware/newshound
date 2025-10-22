# frozen_string_literal: true

RSpec.describe Newshound::Exceptions::ExceptionTrack do
  subject(:adapter) { described_class.new }

  describe "#recent" do
    let(:mock_log_class) { double("ExceptionTrack::Log") }
    let(:mock_scope) { double("ActiveRecord::Relation") }
    let(:time_range) { 24.hours }
    let(:limit) { 10 }

    before do
      stub_const("ExceptionTrack::Log", mock_log_class)
    end

    it "queries ExceptionTrack::Log with correct parameters" do
      expect(mock_log_class).to receive(:where)
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
      mock_result = [double("exception1"), double("exception2")]

      allow(mock_log_class).to receive(:where).and_return(mock_scope)
      allow(mock_scope).to receive(:order).and_return(mock_scope)
      allow(mock_scope).to receive(:limit).and_return(mock_result)

      result = adapter.recent(time_range: time_range, limit: limit)
      expect(result).to eq(mock_result)
    end
  end

  describe "#format_for_report" do
    let(:exception) do
      double(
        "exception",
        title: "ActiveRecord::RecordNotFound",
        created_at: Time.new(2025, 10, 21, 14, 30, 0),
        body: '{"controller_name":"UsersController","action_name":"show","message":"Record not found"}',
        respond_to?: true
      )
    end

    before do
      allow(exception).to receive(:respond_to?).with(:title).and_return(true)
      allow(exception).to receive(:respond_to?).with(:body).and_return(true)
      allow(exception).to receive(:respond_to?).with(:message).and_return(false)
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
        "exception",
        title: "ArgumentError",
        created_at: Time.new(2025, 10, 21, 14, 30, 0),
        body: '{"message":"Invalid argument"}',
        respond_to?: true
      )
      allow(exception_without_controller).to receive(:respond_to?).with(:title).and_return(true)
      allow(exception_without_controller).to receive(:respond_to?).with(:body).and_return(true)

      result = adapter.format_for_report(exception_without_controller, 2)

      expect(result).to include("*2. ArgumentError*")
      expect(result).not_to include("*Controller:*")
      expect(result).to include("*Message:* `Invalid argument`")
    end
  end

  describe "#format_for_banner" do
    let(:exception) do
      double(
        "exception",
        title: "ActiveRecord::RecordNotFound",
        created_at: Time.new(2025, 10, 21, 14, 30, 0),
        body: '{"controller_name":"UsersController","action_name":"show","message":"Record not found"}',
        respond_to?: true
      )
    end

    before do
      allow(exception).to receive(:respond_to?).with(:title).and_return(true)
      allow(exception).to receive(:respond_to?).with(:body).and_return(true)
      allow(exception).to receive(:respond_to?).with(:message).and_return(false)
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
        "exception",
        title: "ArgumentError",
        created_at: Time.new(2025, 10, 21, 14, 30, 0),
        body: '{"message":"Invalid argument"}',
        respond_to?: true
      )
      allow(exception_without_controller).to receive(:respond_to?).with(:title).and_return(true)
      allow(exception_without_controller).to receive(:respond_to?).with(:body).and_return(true)

      result = adapter.format_for_banner(exception_without_controller)

      expect(result[:location]).to eq("")
    end

    it "truncates long messages to 100 characters" do
      long_message = "a" * 150
      exception_with_long_message = double(
        "exception",
        title: "Error",
        created_at: Time.new(2025, 10, 21, 14, 30, 0),
        body: "{\"message\":\"#{long_message}\"}",
        respond_to?: true
      )
      allow(exception_with_long_message).to receive(:respond_to?).with(:title).and_return(true)
      allow(exception_with_long_message).to receive(:respond_to?).with(:body).and_return(true)

      result = adapter.format_for_banner(exception_with_long_message)

      expect(result[:message].length).to be <= 100
    end
  end
end
