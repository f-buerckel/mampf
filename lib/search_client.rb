require "http"
require "connection_pool"

class SearchClient
  class MampfSearchError < StandardError; end

  class ServiceUnavailableError < MampfSearchError; end
  class TimeoutError < MampfSearchError; end

  class InvalidQueryError < MampfSearchError; end
  class InvalidResponseError  < MampfSearchError; end

  
  def initialize(base_url: ENV["MAMPFSEARCH_BASE_URL"].presence || "http://host.docker.internal:8000", pool_size: 5, timeout_seconds: 5)
    raise ArgumentError, "base_url is required and cannot be empty" if base_url.to_s.strip.empty?
    @base_url = base_url
    @timeout = timeout_seconds

    @pool = ConnectionPool.new(size: pool_size, timeout: @timeout) do
      HTTP.persistent(@base_url)
          .timeout(connect: @timeout, write: @timeout, read: @timeout)
          .headers(accept: "application/json", content_type: "application/json")
    end
  end

  def list_lessons()
    perform_request do |client|
      client.post("/lesson/list")
    end
  end
  
  def transcribe_lesson(lesson_rails_id, lecture_rails_id, course_rails_id, video_url)
    payload = {
      lesson_rails_id: lesson_rails_id,
      lecture_rails_id: lecture_rails_id,
      course_rails_id: course_rails_id,
      video_url: video_url
    }

    perform_request do |client|
      client.post("/lesson/ingest", params: payload) # use params: as we only deal with primitive types.
    end

  end

  def search_lessons(query)
    payload = {
      query: query,
      filters: {
        additionalProp1: {}
      }
    }

    perform_request do |client|
      client.post("/lesson/search", json: payload)
    end
  end 


  private

  def perform_request
    response = @pool.with { |client| yield client }
    handle_response(response)
  rescue HTTP::TimeoutError
    raise TimeoutError, "The search took too long to complete."
  rescue HTTP::Error, Errno::ECONNREFUSED => e
    raise ServiceUnavailableError, "The search service is currently offline: #{e.message}"
  end

  def handle_response(response)
    case response.status.code
    when 200..299
      JSON.parse(response.body.to_s)
    when 400..422
      raise InvalidQueryError, "Invalid search parameters: #{response.body}"
    when 500..599
      raise InvalidResponseError, "The search engine encountered an internal error."
    else
      raise MampfSearchError, "Unexpected search failure: #{response.status.code}"
    end
  end
end
