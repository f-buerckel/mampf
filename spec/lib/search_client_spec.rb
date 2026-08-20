require "rails_helper"

RSpec.describe(SearchClient) do
  let(:client) { described_class.send(:new, base_url: "http://example.test") }

  describe "result normalization" do
    it "accepts well-formed search results" do
      results = [
        { "media_rails_id" => 1, "start_time" => 12.5, "text" => "snippet",
          "rrf_score" => 0.4, "chunk_id" => 7, "rerank_score" => 0.8 }
      ]

      expect(client.send(:normalize_results, results)).to eq(results)
    end

    it "raises InvalidResponseError when a required field is missing" do
      results = [{ "media_rails_id" => 1, "text" => "snippet" }]

      expect do
        client.send(:normalize_results, results)
      end.to raise_error(SearchClient::InvalidResponseError, /start_time/)
    end

    it "raises InvalidResponseError when a required field has the wrong type" do
      results = [{ "media_rails_id" => 1, "start_time" => 1.0, "text" => "snippet",
                   "rrf_score" => "high" }]

      expect do
        client.send(:normalize_results, results)
      end.to raise_error(SearchClient::InvalidResponseError, /rrf_score/)
    end

    it "raises InvalidResponseError when the response is not an array" do
      expect do
        client.send(:normalize_results, { "error" => "boom" })
      end.to raise_error(SearchClient::InvalidResponseError, /unexpected response format/)
    end
  end

  describe "#search_with_sentence_scoring" do
    let(:results) do
      [
        { "media_rails_id" => 1, "start_time" => 1.0, "text" => "chunk one",
          "rrf_score" => 0.5, "chunk_id" => 10 },
        { "media_rails_id" => 2, "start_time" => 2.0, "text" => "chunk two",
          "rrf_score" => 0.4, "chunk_id" => 11 }
      ]
    end

    it "wraps unscored results in a single plain segment" do
      allow(client).to receive(:search_media).and_return(results)
      allow(client).to receive(:score_sentences).and_return([])

      scored = client.search_with_sentence_scoring("query")

      expect(scored).to all(have_key("highlight_segments"))
      expect(scored.first["highlight_segments"]).to eq([
                                                         { "text" => "chunk one", "color" => nil }
                                                       ])
    end

    it "uses sentence segments when scoring succeeds" do
      allow(client).to receive(:search_media).and_return(results)
      allow(client).to receive(:score_sentences)
        .and_return([{ "sentences" => [{ "sentence" => "relevant line", "rerank_score" => 0.9 }] }])

      scored = client.search_with_sentence_scoring("query")

      expect(scored.first["highlight_segments"]).to eq([
                                                         { "text" => "relevant line",
                                                           "color" => SearchClient::SentenceHighlighter.color_for(0.9) }
                                                       ])
      expect(scored.last["highlight_segments"]).to eq([
                                                        { "text" => "chunk two", "color" => nil }
                                                      ])
    end

    it "falls back to a plain segment when scoring fails" do
      allow(client).to receive(:search_media).and_return(results)
      allow(client).to receive(:score_sentences)
        .and_raise(SearchClient::MampfSearchError, "boom")

      scored = client.search_with_sentence_scoring("query")

      expect(scored).to all(have_key("highlight_segments"))
      expect(scored.first["highlight_segments"]).to eq([
                                                         { "text" => "chunk one", "color" => nil }
                                                       ])
    end
  end

  describe "#health" do
    let(:pool) { client.instance_variable_get(:@pool) }

    def fake_response(code, body)
      status = double("status", code: code)
      double("response", status: status, body: double("body", to_s: body))
    end

    it "returns the parsed readiness payload" do
      payload = '{"status":"ok","capabilities":{"search":true,"ingest":true}}'
      fake_client = double("client", get: fake_response(200, payload))
      allow(pool).to receive(:with) { |&block| block.call(fake_client) }

      health = client.health

      expect(health).to eq("status" => "ok",
                           "capabilities" => { "search" => true, "ingest" => true })
    end

    it "raises InvalidResponseError on a non-JSON response" do
      fake_client = double("client", get: fake_response(200, "<html>error</html>"))
      allow(pool).to receive(:with) { |&block| block.call(fake_client) }

      expect { client.health }
        .to raise_error(SearchClient::InvalidResponseError, /non-JSON/)
    end
  end

  describe "authentication headers" do
    let(:pool) { client.instance_variable_get(:@pool) }
    let(:secret) { "test-secret-key-at-least-32-characters-long" }

    around do |example|
      original = ENV["MAMPFSEARCH_API_SECRET"]
      ENV["MAMPFSEARCH_API_SECRET"] = secret
      example.run
    ensure
      ENV["MAMPFSEARCH_API_SECRET"] = original
    end

    def fake_response(code, body)
      status = double("status", code: code)
      double("response", status: status, body: double("body", to_s: body))
    end

    it "attaches Authorization header with /lesson/search scope for search_media" do
      fake_http = double("http")
      expect(fake_http).to receive(:headers) do |headers|
        auth = headers[:authorization]
        expect(auth).to start_with("Bearer ")
        token = auth.delete_prefix("Bearer ")
        payload = SearchApiToken.verify!(token, scope: "/lesson/search")
        expect(payload["scope"]).to eq("/lesson/search")
        fake_http
      end
      expect(fake_http).to receive(:post).with("/lesson/search", json: anything)
        .and_return(fake_response(200, "[]"))

      allow(pool).to receive(:with) { |&block| block.call(fake_http) }

      client.search_media("query")
    end

    it "attaches Authorization header with /lesson/ingest scope for transcribe_lesson" do
      fake_http = double("http")
      expect(fake_http).to receive(:headers) do |headers|
        auth = headers[:authorization]
        expect(auth).to start_with("Bearer ")
        token = auth.delete_prefix("Bearer ")
        payload = SearchApiToken.verify!(token, scope: "/lesson/ingest")
        expect(payload["scope"]).to eq("/lesson/ingest")
        fake_http
      end
      expect(fake_http).to receive(:post).with("/lesson/ingest", params: anything)
        .and_return(fake_response(200, '{"status":"queued"}'))

      allow(pool).to receive(:with) { |&block| block.call(fake_http) }

      client.transcribe_lesson(
        media_rails_id: 1, lecture_rails_id: 2, course_rails_id: 3,
        video_url: "http://video.url", transcript_upload_url: "http://upload.url"
      )
    end

    it "attaches Authorization header with /lesson/score-sentences scope for score_sentences" do
      fake_http = double("http")
      expect(fake_http).to receive(:headers) do |headers|
        auth = headers[:authorization]
        expect(auth).to start_with("Bearer ")
        token = auth.delete_prefix("Bearer ")
        payload = SearchApiToken.verify!(token, scope: "/lesson/score-sentences")
        expect(payload["scope"]).to eq("/lesson/score-sentences")
        fake_http
      end
      expect(fake_http).to receive(:post).with("/lesson/score-sentences", params: anything, json: anything)
        .and_return(fake_response(200, "[]"))

      allow(pool).to receive(:with) { |&block| block.call(fake_http) }

      client.score_sentences("query", [1, 2])
    end

    it "attaches Authorization header with /lesson/media/:id scope for delete_media" do
      fake_http = double("http")
      expect(fake_http).to receive(:headers) do |headers|
        auth = headers[:authorization]
        expect(auth).to start_with("Bearer ")
        token = auth.delete_prefix("Bearer ")
        payload = SearchApiToken.verify!(token, scope: "/lesson/media/42")
        expect(payload["scope"]).to eq("/lesson/media/42")
        fake_http
      end
      expect(fake_http).to receive(:delete).with("/lesson/media/42")
        .and_return(fake_response(200, '{"status":"deleted","media_rails_id":42}'))

      allow(pool).to receive(:with) { |&block| block.call(fake_http) }

      client.delete_media(42)
    end

    it "attaches Authorization header with /lesson/list scope for list_media_rails_ids" do
      fake_http = double("http")
      expect(fake_http).to receive(:headers) do |headers|
        auth = headers[:authorization]
        expect(auth).to start_with("Bearer ")
        token = auth.delete_prefix("Bearer ")
        payload = SearchApiToken.verify!(token, scope: "/lesson/list")
        expect(payload["scope"]).to eq("/lesson/list")
        fake_http
      end
      expect(fake_http).to receive(:post).with("/lesson/list")
        .and_return(fake_response(200, '{"media_rails_ids":[1,2,3]}'))

      allow(pool).to receive(:with) { |&block| block.call(fake_http) }

      expect(client.list_media_rails_ids).to eq([1, 2, 3])
    end

    it "does not attach Authorization header for health" do
      fake_http = double("http")
      expect(fake_http).not_to receive(:headers)
      expect(fake_http).to receive(:get).with("/ready")
        .and_return(fake_response(200, '{"status":"ok"}'))

      allow(pool).to receive(:with) { |&block| block.call(fake_http) }

      client.health
    end

  end

  describe "when not configured" do
    let(:unconfigured) { described_class.send(:new, base_url: "") }

    it "raises ServiceUnavailableError on a request instead of ArgumentError" do
      expect { unconfigured.health }
        .to raise_error(SearchClient::ServiceUnavailableError, /not configured/)
    end
  end
end
