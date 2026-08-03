# frozen_string_literal: true

RSpec.describe Newshound::Exceptions::SolidErrors do
  context "when unresolved_only is on" do
    subject(:adapter) { described_class.new }

    let(:mock_error_class) { double("SolidErrors::Error") }
    let(:mock_occurrence_class) { double("SolidErrors::Occurrence") }
    let(:mock_scope) { double("ActiveRecord::Relation") }
    let(:time_range) { 24.hours }
    let(:limit) { 10 }

    let(:error) do
      double(
        "error",
        id: 42,
        exception_class: "ActiveRecord::RecordNotFound",
        message: "Record not found",
        occurrence_count: 3,
        last_occurred_at: Time.new(2025, 10, 21, 14, 30, 0)
      )
    end

    before do
      stub_const("SolidErrors::Error", mock_error_class)
      stub_const("SolidErrors::Occurrence", mock_occurrence_class)

      allow(mock_error_class).to receive(:unresolved).and_return(mock_scope)
      allow(mock_scope).to receive(:joins).and_return(mock_scope)
      allow(mock_scope).to receive(:where).and_return(mock_scope)
      allow(mock_scope).to receive(:group).and_return(mock_scope)
      allow(mock_scope).to receive(:select).and_return(mock_scope)
      allow(mock_scope).to receive(:order).and_return(mock_scope)
      allow(mock_scope).to receive(:limit).and_return([])
    end

    describe "#recent" do
      it "is the default when no config is given" do
        expect(mock_error_class).to receive(:unresolved).and_return(mock_scope)
        expect(mock_occurrence_class).not_to receive(:where)

        adapter.recent(time_range: time_range, limit: limit)
      end

      it "is the default when config is given without the key" do
        expect(mock_error_class).to receive(:unresolved).and_return(mock_scope)

        described_class.new(other: :value).recent(time_range: time_range, limit: limit)
      end

      it "excludes resolved errors" do
        expect(mock_error_class).to receive(:unresolved).and_return(mock_scope)

        adapter.recent(time_range: time_range, limit: limit)
      end

      it "counts only occurrences inside the time range" do
        expect(mock_scope).to receive(:joins).with(:occurrences).and_return(mock_scope)
        expect(mock_scope).to receive(:where)
          .with(solid_errors_occurrences: {created_at: kind_of(Range)})
          .and_return(mock_scope)

        adapter.recent(time_range: time_range, limit: limit)
      end

      it "collapses an error's occurrences into a single counted row" do
        expect(mock_scope).to receive(:group).with(:id).and_return(mock_scope)
        expect(mock_scope).to receive(:select).with(
          "solid_errors.*",
          described_class::LAST_OCCURRED_AT,
          described_class::OCCURRENCE_COUNT
        )
          .and_return(mock_scope)

        adapter.recent(time_range: time_range, limit: limit)
      end

      it "orders by the most recent occurrence and honors the limit" do
        expect(mock_scope).to receive(:order).with("last_occurred_at DESC").and_return(mock_scope)
        expect(mock_scope).to receive(:limit).with(limit).and_return([])

        adapter.recent(time_range: time_range, limit: limit)
      end

      it "returns the query result" do
        errors = [double("error1"), double("error2")]
        allow(mock_scope).to receive(:limit).and_return(errors)

        expect(adapter.recent(time_range: time_range, limit: limit)).to eq(errors)
      end
    end

    describe "#format_for_banner" do
      it "populates title and message from the error record" do
        result = adapter.format_for_banner(error)

        expect(result[:title]).to eq("ActiveRecord::RecordNotFound")
        expect(result[:message]).to eq("Record not found")
      end

      it "uses the error id so the /errors/:id link resolves" do
        expect(adapter.format_for_banner(error)[:id]).to eq(42)
      end

      it "reports the occurrence count in place of a location" do
        expect(adapter.format_for_banner(error)[:location]).to eq("3 occurrences")
      end

      it "singularizes a lone occurrence" do
        allow(error).to receive(:occurrence_count).and_return(1)

        expect(adapter.format_for_banner(error)[:location]).to eq("1 occurrence")
      end

      it "reports the time of the most recent occurrence" do
        expect(adapter.format_for_banner(error)[:time]).to eq("02:30 PM")
      end

      it "truncates long messages to 100 characters" do
        allow(error).to receive(:message).and_return("a" * 150)

        expect(adapter.format_for_banner(error)[:message].length).to be <= 100
      end

      it "falls back to a placeholder title when the class is blank" do
        allow(error).to receive(:exception_class).and_return(nil)

        expect(adapter.format_for_banner(error)[:title]).to eq("Unknown Exception")
      end
    end

    describe "#format_for_report" do
      it "lists the exception class, occurrence count, and message" do
        result = adapter.format_for_report(error, 1)

        expect(result).to include("*1. ActiveRecord::RecordNotFound*")
        expect(result).to include("*Time:* 02:30 PM")
        expect(result).to include("*Occurrences:* 3 occurrences")
        expect(result).to include("*Message:* `Record not found`")
      end
    end
  end

  context "when unresolved_only is off" do
    subject(:adapter) { described_class.new(unresolved_only: false) }

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
        expect(mock_scope).to receive(:order).with(created_at: :desc)
          .and_return(mock_scope)
        expect(mock_scope).to receive(:limit).with(limit).and_return([])

        adapter.recent(time_range: time_range, limit: limit)
      end

      it "accepts the key as a string" do
        adapter = described_class.new("unresolved_only" => false)

        expect(mock_occurrence_class).to receive(:where).and_return(mock_scope)
        allow(mock_scope).to receive(:order).and_return(mock_scope)
        allow(mock_scope).to receive(:limit).and_return([])

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
          id: 99,
          exception_class: "ActiveRecord::RecordNotFound",
          message: "Record not found"
        )
      end

      let(:exception) do
        double(
          "occurrence",
          id: 7,
          created_at: Time.new(2025, 10, 21, 14, 30, 0),
          context: {"controller" => "UsersController", "action" => "show"},
          respond_to?: true,
          error: error_record
        )
      end

      before do
        allow(exception).to receive(:respond_to?).with(:context).and_return(true)
        allow(exception).to receive(:try).with(:error).and_return(error_record)
        allow(exception).to receive(:try).with(:id).and_return(7)
      end

      it "formats exception for banner UI" do
        result = adapter.format_for_banner(exception)

        expect(result).to eq({
          id: 99,
          title: "ActiveRecord::RecordNotFound",
          message: "Record not found",
          location: "UsersController#show",
          time: "02:30 PM"
        })
      end

      it "uses the error record id for linking" do
        result = adapter.format_for_banner(exception)

        expect(result[:id]).to eq(99)
      end

      it "falls back to occurrence id when error has no id" do
        error_without_id = double(
          "error",
          id: nil,
          exception_class: "StandardError",
          message: "msg"
        )

        occurrence = double(
          "occurrence",
          id: 7,
          created_at: Time.new(2025, 10, 21, 14, 30, 0),
          context: {},
          respond_to?: true,
          error: error_without_id
        )
        allow(occurrence).to receive(:respond_to?).with(:context).and_return(true)
        allow(occurrence).to receive(:try).with(:error).and_return(error_without_id)
        allow(occurrence).to receive(:try).with(:id).and_return(7)

        result = adapter.format_for_banner(occurrence)

        expect(result[:id]).to eq(7)
      end

      it "handles exceptions without controller info" do
        error_without_controller = double(
          "error",
          id: 50,
          exception_class: "ArgumentError",
          message: "Invalid argument"
        )

        exception_without_controller = double(
          "occurrence",
          id: 8,
          created_at: Time.new(2025, 10, 21, 14, 30, 0),
          context: {},
          respond_to?: true,
          error: error_without_controller
        )
        allow(exception_without_controller).to receive(:respond_to?).with(:context).and_return(true)
        allow(exception_without_controller).to receive(:try).with(:error).and_return(error_without_controller)
        allow(exception_without_controller).to receive(:try).with(:id).and_return(8)

        result = adapter.format_for_banner(exception_without_controller)

        expect(result[:location]).to eq("")
      end

      it "truncates long messages to 100 characters" do
        long_message = "a" * 150
        long_error = double(
          "error",
          id: 51,
          exception_class: "Error",
          message: long_message
        )

        exception_with_long_message = double(
          "occurrence",
          id: 9,
          created_at: Time.new(2025, 10, 21, 14, 30, 0),
          context: {},
          respond_to?: true,
          error: long_error
        )
        allow(exception_with_long_message).to receive(:respond_to?).with(:context).and_return(true)
        allow(exception_with_long_message).to receive(:try).with(:error).and_return(long_error)
        allow(exception_with_long_message).to receive(:try).with(:id).and_return(9)

        result = adapter.format_for_banner(exception_with_long_message)

        expect(result[:message].length).to be <= 100
      end

      it "handles message from context when exception message is empty" do
        error_with_empty_message = double(
          "error",
          id: 52,
          exception_class: "StandardError",
          message: nil
        )

        exception_with_context_message = double(
          "occurrence",
          id: 10,
          created_at: Time.new(2025, 10, 21, 14, 30, 0),
          context: {"message" => "Error from context"},
          respond_to?: true,
          error: error_with_empty_message
        )
        allow(exception_with_context_message).to receive(:respond_to?).with(:context).and_return(true)
        allow(exception_with_context_message).to receive(:try).with(:error).and_return(error_with_empty_message)
        allow(exception_with_context_message).to receive(:try).with(:id).and_return(10)

        result = adapter.format_for_banner(exception_with_context_message)

        expect(result[:message]).to eq("Error from context")
      end
    end
  end
end
