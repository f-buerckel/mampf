require "http"
require "connection_pool"
require "singleton"
require_relative "search_client/sentence_highlighter"

class SearchClient
  include Singleton

  class MampfSearchError < StandardError; end

  class ServiceUnavailableError < MampfSearchError; end
  class TimeoutError < MampfSearchError; end

  class InvalidQueryError < MampfSearchError; end
  class InvalidResponseError < MampfSearchError; end

  def initialize(base_url: ENV["MAMPFSEARCH_BASE_URL"].presence, pool_size: 5, timeout_seconds: 5)
    @base_url = base_url
    @timeout = timeout_seconds

    return if @base_url.blank?

    @pool = ConnectionPool.new(size: pool_size, timeout: @timeout) do
      HTTP.persistent(@base_url)
          .timeout(connect: @timeout, write: @timeout, read: @timeout)
          .headers(accept: "application/json", content_type: "application/json")
    end
  end

  def transcribe_lesson(media_rails_id:, lecture_rails_id:, course_rails_id:, video_url:,
                        transcript_upload_url:, lesson_rails_id: nil)
    payload = {
      media_rails_id: media_rails_id,
      lecture_rails_id: lecture_rails_id,
      course_rails_id: course_rails_id,
      video_url: video_url,
      transcript_upload_url: transcript_upload_url
    }

    payload[:lesson_rails_id] = lesson_rails_id if lesson_rails_id.present?

    perform_request do |client|
      client.post("/lesson/ingest", params: payload)
    end
  end

  def health
    perform_request do |client|
      client.get("/ready")
    end
  end

  def search_media(query, whitelist_lecture_ids: nil, whitelist_lesson_ids: nil,
                   whitelist_media_ids: nil, exclude_media_ids: nil)
    filters = {}
    filters[:whitelist_lecture_ids] = Array(whitelist_lecture_ids) if whitelist_lecture_ids
    filters[:whitelist_lesson_ids] = Array(whitelist_lesson_ids) if whitelist_lesson_ids
    filters[:whitelist_media_ids] = Array(whitelist_media_ids) if whitelist_media_ids
    filters[:exclude_media_ids] = Array(exclude_media_ids) if exclude_media_ids

    payload = {
      query: query,
      filters: filters
    }

    results = perform_request do |client|
      client.post("/lesson/search", json: payload)
    end

    normalize_results(results)
  end

  def score_sentences(query, chunk_ids)
    perform_request do |client|
      client.post("/lesson/score-sentences", params: { query: query }, json: chunk_ids)
    end
  end

  def search_with_sentence_scoring(query, top_k: 4, **filters)
    results = search_media(query, **filters)
    return results if results.blank?

    top_results = results.first(top_k)
    chunk_ids = top_results.pluck("chunk_id")

    if chunk_ids.present?
      begin
        scores = score_sentences(query, chunk_ids)

        top_results.each_with_index do |result, index|
          next unless scores[index] && scores[index]["sentences"]

          result["highlight_segments"] = SentenceHighlighter.segments(scores[index]["sentences"])
        end
      rescue MampfSearchError => e
        Rails.logger.error("Sentence scoring failed: #{e.message}") if defined?(Rails)
      end
    end

    results.each do |result|
      segments = result["highlight_segments"]
      segments = [{ "text" => result["text"], "color" => nil }] if segments.blank?
      result["highlight_segments"] = segments
    end

    results
  end

  private

    def perform_request(&)
      unless @pool
        raise(ServiceUnavailableError,
              "MampfSearch is not configured (MAMPFSEARCH_BASE_URL is missing)")
      end

      response = @pool.with(&)
      handle_response(response)
    rescue HTTP::TimeoutError
      raise(TimeoutError, "The search took too long to complete.")
    rescue HTTP::Error, Errno::ECONNREFUSED => e
      raise(ServiceUnavailableError, "The search service is currently offline: #{e.message}")
    rescue JSON::ParserError => e
      raise(InvalidResponseError, "The search service returned a non-JSON response: #{e.message}")
    end

    def normalize_results(results)
      unless results.is_a?(Array)
        raise(InvalidResponseError, "search service returned an unexpected response format")
      end

      results.each_with_index do |result, index|
        validate_field!(result, index, "media_rails_id", Integer)
        validate_field!(result, index, "start_time", Numeric)
        validate_field!(result, index, "text", String)
        validate_field!(result, index, "rrf_score", Numeric)
      end

      results
    end

    def validate_field!(result, index, field, type)
      value = result.is_a?(Hash) ? result[field] : nil
      return if value.is_a?(type)

      raise(InvalidResponseError,
            "search service returned a malformed result at index #{index}: " \
            "#{field.inspect} is missing or has the wrong type")
    end

    def handle_response(response)
      case response.status.code
      when 200..299
        JSON.parse(response.body.to_s)
      when 400..422
        raise(InvalidQueryError, "Invalid search parameters: #{response.body}")
      when 500..599
        raise(InvalidResponseError, "The search engine encountered an internal error.")
      else
        raise(MampfSearchError, "Unexpected search failure: #{response.status.code}")
      end
    end
end
