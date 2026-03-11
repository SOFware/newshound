# frozen_string_literal: true

RSpec.describe Newshound::Configuration do
  subject(:config) { described_class.new }

  describe "link configuration" do
    describe "#exception_links" do
      it "defaults to an empty hash" do
        expect(config.exception_links).to eq({})
      end

      it "accepts index and show keys" do
        config.exception_links = {
          index: "/errors",
          show: "/errors/:id"
        }

        expect(config.exception_links[:index]).to eq("/errors")
        expect(config.exception_links[:show]).to eq("/errors/:id")
      end
    end

    describe "#job_links" do
      it "defaults to an empty hash" do
        expect(config.job_links).to eq({})
      end

      it "accepts index, show, scheduled, failed, and completed keys" do
        config.job_links = {
          index: "/background_jobs",
          show: "/background_jobs/jobs/:id",
          scheduled: "/background_jobs/scheduled",
          failed: "/background_jobs/failed",
          completed: "/background_jobs/completed"
        }

        expect(config.job_links[:index]).to eq("/background_jobs")
        expect(config.job_links[:show]).to eq("/background_jobs/jobs/:id")
        expect(config.job_links[:scheduled]).to eq("/background_jobs/scheduled")
        expect(config.job_links[:failed]).to eq("/background_jobs/failed")
        expect(config.job_links[:completed]).to eq("/background_jobs/completed")
      end
    end

    describe "#warning_links" do
      it "defaults to an empty hash" do
        expect(config.warning_links).to eq({})
      end

      it "accepts index and show keys" do
        config.warning_links = {
          index: "/warnings",
          show: "/warnings/:id"
        }

        expect(config.warning_links[:index]).to eq("/warnings")
        expect(config.warning_links[:show]).to eq("/warnings/:id")
      end
    end
  end
end
