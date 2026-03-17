# frozen_string_literal: true

RSpec.describe Newshound::Exceptions::Bugsink do
  let(:config) do
    {
      url: "https://bugs.example.com",
      token: "abc123",
      project_id: 1
    }
  end

  subject(:adapter) { described_class.new(config) }

  describe "#initialize" do
    it "accepts valid config" do
      expect { described_class.new(config) }.not_to raise_error
    end

    it "raises with all missing keys listed" do
      expect { described_class.new({}) }
        .to raise_error(ArgumentError, /requires :url, :token, :project_id/)
    end

    it "raises with only the missing keys" do
      expect { described_class.new(config.except(:token, :project_id)) }
        .to raise_error(ArgumentError, /requires :token, :project_id/)
    end

    it "raises for a single missing key" do
      expect { described_class.new(config.except(:url)) }
        .to raise_error(ArgumentError, /requires :url/)
    end

    it "accepts string keys" do
      string_config = {"url" => "https://bugs.example.com", "token" => "abc123", "project_id" => 1}
      expect { described_class.new(string_config) }.not_to raise_error
    end
  end

  describe "#recent" do
    let(:now) { Time.now.utc }
    let(:recent_issue) do
      {"id" => "uuid-1", "calculated_type" => "ValueError", "calculated_value" => "bad value", "last_seen" => now.iso8601, "transaction" => "/api/users"}
    end
    let(:old_issue) do
      {"id" => "uuid-2", "calculated_type" => "KeyError", "calculated_value" => "missing key", "last_seen" => (now - 48 * 3600).iso8601, "transaction" => "/api/posts"}
    end
    let(:api_response) do
      {"results" => [recent_issue, old_issue]}
    end

    before do
      allow(adapter).to receive(:fetch_issues).and_return(api_response["results"])
    end

    it "filters issues by time range" do
      result = adapter.recent(time_range: 24.hours, limit: 10)

      expect(result).to contain_exactly(recent_issue)
    end

    it "respects the limit" do
      issues = 5.times.map do |i|
        {"id" => "uuid-#{i}", "calculated_type" => "Error", "calculated_value" => "msg", "last_seen" => now.iso8601, "transaction" => ""}
      end
      allow(adapter).to receive(:fetch_issues).and_return(issues)

      result = adapter.recent(time_range: 24.hours, limit: 3)

      expect(result.length).to eq(3)
    end
  end

  describe "#format_for_report" do
    let(:issue) do
      {
        "id" => "uuid-1",
        "calculated_type" => "ValueError",
        "calculated_value" => "bad value",
        "last_seen" => Time.new(2025, 10, 21, 14, 30, 0, "UTC").iso8601,
        "transaction" => "/api/users"
      }
    end

    it "formats issue for report display" do
      result = adapter.format_for_report(issue, 1)

      expect(result).to include("*1. ValueError*")
      expect(result).to include("*Time:*")
      expect(result).to include("*Message:* `bad value`")
    end

    it "handles missing calculated_type" do
      issue["calculated_type"] = nil
      result = adapter.format_for_report(issue, 1)

      expect(result).to include("*1. Unknown*")
    end
  end

  describe "#format_for_banner" do
    let(:issue) do
      {
        "id" => "uuid-1",
        "calculated_type" => "ValueError",
        "calculated_value" => "bad value",
        "last_seen" => Time.new(2025, 10, 21, 14, 30, 0, "UTC").iso8601,
        "transaction" => "/api/users"
      }
    end

    it "formats issue for banner UI" do
      result = adapter.format_for_banner(issue)

      expect(result).to eq({
        id: "uuid-1",
        title: "ValueError",
        message: "bad value",
        location: "/api/users",
        time: "02:30 PM"
      })
    end

    it "handles missing fields gracefully" do
      sparse_issue = {
        "id" => "uuid-2",
        "calculated_type" => nil,
        "calculated_value" => nil,
        "last_seen" => Time.new(2025, 10, 21, 14, 30, 0, "UTC").iso8601,
        "transaction" => nil
      }

      result = adapter.format_for_banner(sparse_issue)

      expect(result[:title]).to eq("Unknown")
      expect(result[:message]).to eq("")
      expect(result[:location]).to eq("")
    end

    it "truncates long messages to 100 characters" do
      issue["calculated_value"] = "a" * 150

      result = adapter.format_for_banner(issue)

      expect(result[:message].length).to be <= 100
    end
  end

  describe "HTTP integration" do
    let(:http) { instance_double(Net::HTTP) }

    before do
      allow(Net::HTTP).to receive(:start).and_yield(http)
    end

    it "raises on API errors" do
      response = Net::HTTPInternalServerError.new("1.1", "500", "Internal Server Error")
      allow(response).to receive(:body).and_return("")
      allow(http).to receive(:request).and_return(response)

      expect { adapter.recent(time_range: 24.hours, limit: 10) }
        .to raise_error(RuntimeError, /Bugsink API error: 500/)
    end

    it "parses successful responses" do
      response = Net::HTTPOK.new("1.1", "200", "OK")
      allow(response).to receive(:body).and_return('{"results": []}')
      allow(http).to receive(:request).and_return(response)

      result = adapter.recent(time_range: 24.hours, limit: 10)

      expect(result).to eq([])
    end
  end
end
