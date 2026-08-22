require "rails_helper"

RSpec.describe(SearchClient::SentenceHighlighter) do
  describe ".segments" do
    it "returns the relevant sentence as a plain-text segment with a highlight color" do
      sentences = [{ "sentence" => "The quick brown fox", "rerank_score" => 0.8 }]

      expect(described_class.segments(sentences)).to eq([
                                                          { "text" => "The quick brown fox",
                                                            "color" => described_class.color_for(0.8) }
                                                        ])
    end

    it "replaces a sub-threshold sentence with a cut marker" do
      sentences = [{ "sentence" => "Low relevance", "rerank_score" => 0.1 }]

      expect(described_class.segments(sentences)).to eq([
                                                          { "text" => "[...]", "color" => nil }
                                                        ])
    end

    it "collapses consecutive low-scoring sentences into a single cut marker" do
      sentences = [
        { "sentence" => "Relevant sentence", "rerank_score" => 0.9 },
        { "sentence" => "Noise one", "rerank_score" => 0.1 },
        { "sentence" => "Noise two", "rerank_score" => 0.05 }
      ]

      expect(described_class.segments(sentences)).to eq([
                                                          { "text" => "Relevant sentence",
                                                            "color" => described_class.color_for(0.9) },
                                                          { "text" => "[...]", "color" => nil }
                                                        ])
    end

    it "returns empty array when sentences is nil or empty" do
      expect(described_class.segments(nil)).to eq([])
      expect(described_class.segments([])).to eq([])
    end

    it "handles missing rerank_score by defaulting to 0 (cut marker)" do
      sentences = [{ "sentence" => "Sentence without score" }]

      expect(described_class.segments(sentences)).to eq([
        { "text" => "[...]", "color" => nil }
      ])
    end

    it "keeps untrusted sentence text as raw data, not embedded in markup" do
      sentences = [{ "sentence" => "<script>alert(1)</script>", "rerank_score" => 0.9 }]

      expect(described_class.segments(sentences)).to eq([
                                                          { "text" => "<script>alert(1)</script>",
                                                            "color" => described_class.color_for(0.9) }
                                                        ])
    end
  end

  describe ".color_for" do
    it "returns yellow at the lower bound" do
      expect(described_class.color_for(0.2)).to eq("hsla(60, 100%, 50%, 0.3)")
    end

    it "returns red at the upper bound" do
      expect(described_class.color_for(1.0)).to eq("hsla(0, 100%, 50%, 0.3)")
    end

    it "clamps scores outside the 0.2..1.0 range" do
      expect(described_class.color_for(0.0)).to eq(described_class.color_for(0.2))
      expect(described_class.color_for(1.5)).to eq(described_class.color_for(1.0))
    end
  end
end
