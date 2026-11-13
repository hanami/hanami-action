# frozen_string_literal: true

RSpec.describe Hanami::Action::Mime, ".best_q_match" do
  let(:available) { ["text/html", "application/json", "application/vnd.api+json", "image/png"] }

  def match(header) = described_class.best_q_match(header, available)

  it "returns an exactly matching type" do
    expect(match("application/json")).to eq "application/json"
  end

  it "returns nil when nothing matches" do
    expect(match("application/pdf")).to be_nil
  end

  it "returns the first available type for a full wildcard" do
    expect(match("*/*")).to eq "text/html"
  end

  it "returns the first available type matching a subtype wildcard" do
    expect(match("application/*")).to eq "application/json"
  end

  it "prefers the highest quality" do
    expect(match("text/html;q=0.5, image/png;q=0.9")).to eq "image/png"
  end

  it "prefers a specific type over a wildcard of equal quality" do
    expect(match("*/*, image/png")).to eq "image/png"
  end

  it "prefers the earlier of two equally specific types of equal quality" do
    expect(match("image/png, application/json")).to eq "image/png"
  end

  it "skips unavailable types" do
    expect(match("application/pdf, application/vnd.api+json;q=0.1")).to eq "application/vnd.api+json"
  end

  it "resolves a typical browser header" do
    header = "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8"

    expect(match(header)).to eq "text/html"
  end

  it "returns the first available type matching a bare type" do
    expect(match("application")).to eq "application/json"
  end

  it "does not compare full types against each available type" do
    expect(Rack::Mime).not_to receive(:match?)

    match("text/html, application/json;q=0.9, application/pdf;q=0.8")
  end
end
