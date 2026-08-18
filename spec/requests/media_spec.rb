require "rails_helper"

RSpec.describe("Media", type: :request) do
  # Use an admin to bypass visibility filters for simplicity
  let(:user) do
    create(:confirmed_user, admin: true)
  end
  let!(:medium_ruby) { create(:valid_medium, description: "An introduction to Ruby") }
  let!(:medium_python) { create(:valid_medium, description: "A guide to Python") }

  before do
    sign_in user
  end

  describe "GET /media" do
    let(:lecture) { create(:lecture, :released_for_all) }
    let!(:medium_in_lecture) do
      create(:lecture_medium, teachable: lecture, sort: "LessonMaterial",
                              description: "Content for this lecture")
    end
    let!(:medium_elsewhere) do
      create(:lecture_medium, sort: "LessonMaterial", description: "Content from another source")
    end

    it "returns a successful response" do
      # The media#index action requires a :project parameter to scope the search.
      get media_path(id: lecture.id, project: "lesson_material")
      expect(response).to have_http_status(:ok)
    end

    it "returns only the media associated with the specified lecture" do
      get media_path(id: lecture.id, project: "lesson_material")
      expect(response.body).to include(medium_in_lecture.description)
      expect(response.body).not_to include(medium_elsewhere.description)
    end
  end

  describe "GET /media/search" do
    it "returns a successful response" do
      get search_media_path, params: { search: { fulltext: "Ruby" } }, xhr: true
      expect(response).to have_http_status(:ok)
    end

    it "returns the correct media in the response body" do
      get search_media_path, params: { search: { fulltext: "Ruby" } }, xhr: true
      expect(response.body).to include(medium_ruby.description)
      expect(response.body).not_to include(medium_python.description)
    end
  end

  describe "GET /media/:id/play" do
    let(:restricted_medium) { create(:lecture_medium, :with_video) }

    it "renders the thyme player with Rails-served media sources" do
      get play_medium_path(restricted_medium)

      expect(response).to have_http_status(:ok)
      expect(response.body)
        .to include("src=\"#{stream_video_medium_path(restricted_medium)}\"")
      expect(response.body)
        .to include("src=\"#{chapters_vtt_medium_path(restricted_medium)}\"")
      expect(response.body)
        .to include("src=\"#{references_vtt_medium_path(restricted_medium)}\"")
    end
  end

  describe "GET /media/:id/screenshot/:sort" do
    let(:restricted_medium) { create(:lecture_medium) }
    let(:free_medium) { create(:lecture_medium, :released) }
    let(:fake_screenshot) do
      instance_double(
        "Shrine::UploadedFile",
        to_io: File.open(File.join(SPEC_FILES, "image.png")),
        storage: double("storage"),
        metadata: {
          "filename" => "preview.png",
          "mime_type" => "image/png"
        }
      )
    end

    before do
      allow_any_instance_of(Medium).to receive(:video_screenshot_file)
        .and_return(fake_screenshot)
      allow_any_instance_of(Medium).to receive(:manuscript_screenshot_file)
        .and_return(fake_screenshot)
      allow_any_instance_of(Medium).to receive(:geogebra_screenshot_file)
        .and_return(fake_screenshot)
    end

    it "serves a screenshot preview inline through Rails" do
      get screenshot_medium_path(restricted_medium, sort: "video")

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("image/png")
      expect(response.headers["Content-Disposition"]).to include("inline")
      expect(response.headers["Cache-Control"]).to eq("no-cache, no-store")
      expect(response.headers["Pragma"]).to eq("no-cache")
    end

    it "allows guest access to free screenshot previews" do
      sign_out user

      get screenshot_medium_path(free_medium, sort: "video")

      expect(response).to have_http_status(:ok)
      expect(response.headers["Content-Disposition"]).to include("inline")
      expect(response.headers["Cache-Control"]).not_to eq("no-cache, no-store")
    end

    it "returns not found for missing previews" do
      allow_any_instance_of(Medium).to receive(:video_screenshot_file)
        .and_return(nil)

      get screenshot_medium_path(restricted_medium, sort: "video")

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /media/:id/inspect" do
    let(:restricted_medium) do
      create(:lecture_medium, :with_manuscript).tap do |medium|
        medium.update!(screenshot: File.open(File.join(SPEC_FILES, "image.png"), "rb"))
      end
    end
    let(:fake_screenshot) do
      instance_double(
        "Shrine::UploadedFile",
        to_io: File.open(File.join(SPEC_FILES, "image.png")),
        storage: double("storage"),
        metadata: {
          "filename" => "preview.png",
          "mime_type" => "image/png"
        }
      )
    end

    before do
      allow_any_instance_of(Medium).to receive(:manuscript_screenshot_file)
        .and_return(fake_screenshot)
    end

    it "renders video and manuscript previews through Rails routes" do
      get inspect_medium_path(restricted_medium)

      expect(response).to have_http_status(:ok)
      expect(response.body)
        .to include("src=\"#{screenshot_medium_path(restricted_medium, sort: "video")}\"")
      expect(response.body)
        .to include("src=\"#{screenshot_medium_path(restricted_medium, sort: "manuscript")}\"")
    end
  end

  describe "GET /media/:id/edit" do
    let(:restricted_medium) { create(:lecture_medium) }
    let(:fake_screenshot) do
      instance_double(
        "Shrine::UploadedFile",
        to_io: File.open(File.join(SPEC_FILES, "image.png")),
        storage: double("storage"),
        metadata: {
          "filename" => "preview.png",
          "mime_type" => "image/png"
        }
      )
    end

    before do
      allow_any_instance_of(Medium).to receive(:geogebra_screenshot_file)
        .and_return(fake_screenshot)
    end

    it "renders the geogebra preview through a Rails route" do
      get edit_medium_path(restricted_medium)

      expect(response).to have_http_status(:ok)
      expect(response.body)
        .to include("src=\"#{screenshot_medium_path(restricted_medium, sort: "geogebra")}\"")
    end
  end

  describe "GET /media/:id/vtt/chapters" do
    let(:free_medium) { create(:lecture_medium, :with_video, :with_toc_item, :released) }

    it "serves chapters as VTT through Rails" do
      sign_out user

      get chapters_vtt_medium_path(free_medium)

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/vtt")
      expect(response.body).to include("WEBVTT")
      expect(response.body).to include("Test Remark")
    end
  end

  describe "GET /media/:id/vtt/references" do
    let(:lecture) { create(:lecture, :released_for_all) }
    let(:free_medium) do
      create(:lecture_medium, :with_video, teachable: lecture,
                                           released: "all", released_at: Time.zone.now)
    end
    let(:restricted_reference_medium) do
      create(:lecture_medium, :with_video, teachable: lecture,
                                           released: "subscribers",
                                           released_at: Time.zone.now)
    end
    let!(:referral) do
      create(:referral,
             medium: free_medium,
             item: restricted_reference_medium.items.find_by(sort: "self"),
             start_time: TimeStamp.new(total_seconds: 5),
             end_time: TimeStamp.new(total_seconds: 10))
    end

    it "includes visible references for the current viewer" do
      get references_vtt_medium_path(free_medium)

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/vtt")
      expect(response.body).to include(play_medium_path(restricted_reference_medium))
      expect(response.headers["Cache-Control"]).to include("no-store")
      expect(response.headers["Pragma"]).to eq("no-cache")
    end

    it "filters restricted references for guests" do
      sign_out user

      get references_vtt_medium_path(free_medium)

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/vtt")
      expect(response.body).to include("WEBVTT")
      expect(response.body).not_to include(play_medium_path(restricted_reference_medium))
      expect(response.headers["Cache-Control"]).to include("no-store")
      expect(response.headers["Pragma"]).to eq("no-cache")
    end
  end

  describe "GET /media/:id/video/stream" do
    let(:restricted_medium) { create(:lecture_medium, :with_video) }
    let(:free_medium) { create(:lecture_medium, :with_video, :released) }

    it "serves a video inline through Rails" do
      get stream_video_medium_path(restricted_medium)

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("video/mp4")
      expect(response.headers["Content-Disposition"]).to include("inline")
      expect(response.headers["Content-Disposition"])
        .to include(restricted_medium.video_filename)
      expect(response.headers["Cache-Control"]).to eq("no-cache, no-store")
      expect(response.headers["Pragma"]).to eq("no-cache")
      expect(response.headers["Expires"])
        .to eq("Mon, 01 Jan 1990 00:00:00 GMT")
    end

    it "allows guest access for free videos" do
      sign_out user

      get stream_video_medium_path(free_medium)

      expect(response).to have_http_status(:ok)
      expect(response.headers["Content-Disposition"]).to include("inline")
      expect(response.headers["Cache-Control"]).not_to eq("no-cache, no-store")
    end
  end

  describe "GET /media/:id/video/transcription_stream" do
    let(:medium) { create(:lecture_medium, :with_video) }

    it "serves a video with a valid transcription token" do
      token = TranscriptionToken.generate(
        medium_id: medium.id,
        purpose: :video,
        ttl: 5.minutes
      )

      get transcription_stream_video_medium_path(medium), params: { token: token }

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("video/mp4")
      expect(response.headers["Cache-Control"]).to eq("no-cache, no-store")
    end

    it "rejects a missing token" do
      get transcription_stream_video_medium_path(medium)

      expect(response).to have_http_status(:forbidden)
    end

    it "rejects a token for another medium" do
      token = TranscriptionToken.generate(
        medium_id: medium.id + 1,
        purpose: :video,
        ttl: 5.minutes
      )

      get transcription_stream_video_medium_path(medium), params: { token: token }

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "POST /media/:id/transcribe" do
    let(:medium) { create(:lecture_medium, :with_video) }
    let(:search_client) { instance_double(SearchClient) }

    before do
      allow(SearchClient).to receive(:instance).and_return(search_client)
      allow(search_client).to receive(:transcribe_lesson)
    end

    it "passes signed video and callback URLs to MampfSearch" do
      expect(search_client).to receive(:transcribe_lesson) do |payload|
        expect(payload[:video_url]).to include(
          "/media/#{medium.id}/video/transcription_stream?token="
        )
        expect(payload[:transcript_upload_url]).to include(
          "/api/webhooks/media/#{medium.id}/transcripts?token="
        )
      end

      post transcribe_medium_path(medium)

      expect(response).to have_http_status(:accepted)
    end

    it "redirects with an alert when MampfSearch is unavailable" do
      allow(search_client)
        .to receive(:transcribe_lesson)
        .and_raise(SearchClient::ServiceUnavailableError, "down")

      post transcribe_medium_path(medium)

      expect(response).to have_http_status(:redirect)
      expect(flash[:alert]).to eq(I18n.t("search.mampfsearch_unavailable"))
    end
  end

  describe "POST /api/webhooks/media/:id/transcripts" do
    let(:medium) { create(:lecture_medium, :with_video) }

    it "rejects a callback without a valid token" do
      post add_transcript_path(medium), params: { transcript: "WEBVTT" }

      expect(response).to have_http_status(:forbidden)
    end

    it "rejects a video token" do
      token = TranscriptionToken.generate(
        medium_id: medium.id,
        purpose: :video,
        ttl: 5.minutes
      )

      post add_transcript_path(medium), params: {
        token: token,
        transcript: "WEBVTT"
      }

      expect(response).to have_http_status(:forbidden)
    end

    it "accepts a valid vtt upload with a valid token" do
      token = TranscriptionToken.generate(
        medium_id: medium.id,
        purpose: :transcript,
        ttl: 5.minutes
      )
      file = Rack::Test::UploadedFile.new(File.join(SPEC_FILES, "toc.vtt"),
                                          "text/vtt")

      post add_transcript_path(medium), params: { token: token, transcript: file }

      expect(response).to have_http_status(:ok)
    end

    it "accepts a valid vtt upload with an Authorization Bearer header" do
      token = TranscriptionToken.generate(
        medium_id: medium.id,
        purpose: :transcript,
        ttl: 5.minutes
      )
      file = Rack::Test::UploadedFile.new(File.join(SPEC_FILES, "toc.vtt"),
                                          "text/vtt")

      post add_transcript_path(medium),
           params: { transcript: file },
           headers: { "Authorization" => "Bearer #{token}" }

      expect(response).to have_http_status(:ok)
    end

    it "rejects an upload that is not a valid vtt" do
      token = TranscriptionToken.generate(
        medium_id: medium.id,
        purpose: :transcript,
        ttl: 5.minutes
      )
      file = Rack::Test::UploadedFile.new(File.join(SPEC_FILES, "manuscript.pdf"),
                                          "text/vtt")

      post add_transcript_path(medium), params: { token: token, transcript: file }

      expect(response).to have_http_status(:unprocessable_content)
      expect(JSON.parse(response.body)["errors"]).to include(
        "Transcript #{I18n.t("submission.invalid_transcript")}"
      )
    end
  end

  describe "GET /media/:id/download/:sort" do
    let(:restricted_medium) { create(:lecture_medium, :with_manuscript) }
    let(:free_medium) { create(:lecture_medium, :with_manuscript, :released) }
    let(:video_medium) { create(:lecture_medium, :with_video) }

    it "serves a manuscript attachment through Rails" do
      get download_medium_path(restricted_medium, sort: "manuscript")

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("application/pdf")
      expect(response.headers["Content-Disposition"])
        .to include("attachment")
      expect(response.headers["Content-Disposition"])
        .to include(restricted_medium.manuscript_filename)
      expect(response.headers["Cache-Control"]).to eq("no-cache, no-store")
      expect(response.headers["Pragma"]).to eq("no-cache")
      expect(response.headers["Expires"])
        .to eq("Mon, 01 Jan 1990 00:00:00 GMT")
    end

    it "still serves the download when consumption enqueue fails" do
      expect(Rails.logger).to receive(:error).with(include(
                                                     "medium_id=#{restricted_medium.id}",
                                                     "mode=download",
                                                     "sort=manuscript",
                                                     "redis down"
                                                   ))
      allow(ConsumptionSaver).to receive(:perform_async)
        .and_raise(StandardError, "redis down")

      get download_medium_path(restricted_medium, sort: "manuscript")

      expect(response).to have_http_status(:ok)
      expect(response.headers["Content-Disposition"])
        .to include(restricted_medium.manuscript_filename)
    end

    it "sanitizes the attachment filename from uploaded metadata" do
      allow_any_instance_of(PdfUploader::UploadedFile).to receive(:metadata)
        .and_wrap_original do |original, *args|
          original.call(*args).merge("filename" => "../evil\r\nname.pdf")
        end

      get download_medium_path(restricted_medium, sort: "manuscript")
      content_disposition = response.headers["Content-Disposition"]

      expect(response).to have_http_status(:ok)
      expect(content_disposition).to include("attachment")
      expect(content_disposition).to include("evil")
      expect(content_disposition).to include("name.pdf")
      expect(content_disposition).not_to include("../")
      expect(content_disposition).not_to match(/[\r\n]/)
    end

    it "allows guest downloads for free media" do
      sign_out user

      get download_medium_path(free_medium, sort: "manuscript")

      expect(response).to have_http_status(:ok)
      expect(response.headers["Content-Disposition"])
        .to include(free_medium.manuscript_filename)
      expect(response.headers["Cache-Control"]).not_to eq("no-cache, no-store")
    end

    it "serves a video attachment through Rails" do
      get download_medium_path(video_medium, sort: "video")

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("video/mp4")
      expect(response.headers["Content-Disposition"])
        .to include("attachment")
      expect(response.headers["Content-Disposition"])
        .to include(video_medium.video_filename)
    end

    it "rejects guest downloads for restricted media" do
      sign_out user

      get download_medium_path(restricted_medium, sort: "manuscript")

      expect(response).to redirect_to(root_url)
    end

    it "redirects invalid download sorts with a specific alert" do
      get download_medium_path(restricted_medium, sort: "invalid")

      expect(response).to redirect_to(root_url)
      expect(flash[:alert]).to eq(I18n.t("controllers.invalid_download"))
    end
  end

  describe "GET /media/:id/display" do
    let(:restricted_medium) { create(:lecture_medium, :with_manuscript) }
    let(:free_medium) { create(:lecture_medium, :with_manuscript, :released) }

    it "renders a compatibility page that points to the inline manuscript" do
      get display_medium_path(restricted_medium), params: { page: "17" }

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/html")
      expect(response.body)
        .to include(
          "src=\"#{inline_manuscript_medium_path(restricted_medium)}#page=17\""
        )
      expect(response.body)
        .to include("title=\"#{restricted_medium.manuscript_filename}\"")
      expect(response.headers["Cache-Control"]).to include("no-store")
      expect(response.headers["Pragma"]).to eq("no-cache")
      expect(response.headers["Expires"])
        .to eq("Mon, 01 Jan 1990 00:00:00 GMT")
    end

    it "preserves named destinations in the inline manuscript fragment" do
      get display_medium_path(restricted_medium), params: { destination: "Theorem 1" }

      expect(response.body)
        .to include(
          "src=\"#{inline_manuscript_medium_path(restricted_medium)}#Theorem%201\""
        )
    end

    it "allows guest access to the compatibility page for free media" do
      sign_out user

      get display_medium_path(free_medium), params: { page: "3" }

      expect(response).to have_http_status(:ok)
      expect(response.body)
        .to include(
          "src=\"#{inline_manuscript_medium_path(free_medium)}#page=3\""
        )
      expect(response.headers["Cache-Control"]).not_to eq("no-cache, no-store")
    end
  end

  describe "GET /media/:id/manuscript/inline" do
    let(:restricted_medium) { create(:lecture_medium, :with_manuscript) }
    let(:free_medium) { create(:lecture_medium, :with_manuscript, :released) }

    it "serves the manuscript inline through Rails" do
      get inline_manuscript_medium_path(restricted_medium)

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("application/pdf")
      expect(response.headers["Content-Disposition"]).to include("inline")
      expect(response.headers["Content-Disposition"])
        .to include(restricted_medium.manuscript_filename)
      expect(response.headers["Cache-Control"]).to eq("no-cache, no-store")
    end

    it "sanitizes the inline filename from uploaded metadata" do
      allow_any_instance_of(PdfUploader::UploadedFile).to receive(:metadata)
        .and_wrap_original do |original, *args|
          original.call(*args).merge("filename" => "../evil\r\nname.pdf")
        end

      get inline_manuscript_medium_path(restricted_medium)

      content_disposition = response.headers["Content-Disposition"]

      expect(response).to have_http_status(:ok)
      expect(content_disposition).to include("inline")
      expect(content_disposition).to include("evil")
      expect(content_disposition).to include("name.pdf")
      expect(content_disposition).not_to include("../")
      expect(content_disposition).not_to match(/[\r\n]/)
    end

    it "allows guest inline access for free media" do
      sign_out user

      get inline_manuscript_medium_path(free_medium)

      expect(response).to have_http_status(:ok)
      expect(response.headers["Content-Disposition"]).to include("inline")
      expect(response.headers["Cache-Control"]).not_to eq("no-cache, no-store")
    end
  end

  describe "GET /media/:id/geogebra" do
    let(:restricted_medium) do
      create(:lecture_medium, geogebra_app_name: "classic")
    end
    let(:free_medium) do
      create(:lecture_medium, :released, geogebra_app_name: "classic")
    end
    let(:fake_geogebra) do
      instance_double(
        "Shrine::UploadedFile",
        to_io: File.open(File.join(SPEC_FILES, "manuscript.pdf")),
        storage: double("storage"),
        metadata: {
          "filename" => "demo.ggb",
          "mime_type" => "application/zip"
        }
      )
    end

    before do
      allow_any_instance_of(Medium).to receive(:geogebra).and_return(fake_geogebra)
    end

    it "renders the geogebra page with a Rails-served inline asset" do
      get geogebra_medium_path(restricted_medium)

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/html")
      expect(response.body)
        .to include("data-filename=\"#{inline_geogebra_medium_path(restricted_medium)}\"")
      expect(response.headers["Cache-Control"]).to include("no-store")
      expect(response.headers["Pragma"]).to eq("no-cache")
      expect(response.headers["Expires"])
        .to eq("Mon, 01 Jan 1990 00:00:00 GMT")
    end

    it "allows guest access to the geogebra page for free media" do
      sign_out user

      get geogebra_medium_path(free_medium)

      expect(response).to have_http_status(:ok)
      expect(response.body)
        .to include("data-filename=\"#{inline_geogebra_medium_path(free_medium)}\"")
      expect(response.headers["Cache-Control"]).not_to eq("no-cache, no-store")
    end
  end

  describe "GET /media/:id/geogebra/inline" do
    let(:restricted_medium) { create(:lecture_medium) }
    let(:free_medium) { create(:lecture_medium, :released) }
    let(:fake_geogebra) do
      instance_double(
        "Shrine::UploadedFile",
        to_io: File.open(File.join(SPEC_FILES, "manuscript.pdf")),
        storage: double("storage"),
        metadata: {
          "filename" => "demo.ggb",
          "mime_type" => "application/zip"
        }
      )
    end

    before do
      allow_any_instance_of(Medium).to receive(:geogebra).and_return(fake_geogebra)
    end

    it "serves the geogebra file inline through Rails" do
      get inline_geogebra_medium_path(restricted_medium)

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("application/zip")
      expect(response.headers["Content-Disposition"]).to include("inline")
      expect(response.headers["Content-Disposition"]).to include("demo.ggb")
      expect(response.headers["Cache-Control"]).to eq("no-cache, no-store")
    end

    it "sanitizes the inline geogebra filename from uploaded metadata" do
      hostile_geogebra = instance_double(
        "Shrine::UploadedFile",
        to_io: File.open(File.join(SPEC_FILES, "manuscript.pdf")),
        storage: double("storage"),
        metadata: {
          "filename" => "../demo\r\nfile.ggb",
          "mime_type" => "application/zip"
        }
      )
      allow_any_instance_of(Medium).to receive(:geogebra)
        .and_return(hostile_geogebra)

      get inline_geogebra_medium_path(restricted_medium)

      content_disposition = response.headers["Content-Disposition"]

      expect(response).to have_http_status(:ok)
      expect(content_disposition).to include("inline")
      expect(content_disposition).to include("demo")
      expect(content_disposition).to include("file.ggb")
      expect(content_disposition).not_to include("../")
      expect(content_disposition).not_to match(/[\r\n]/)
    end

    it "allows guest inline geogebra access for free media" do
      sign_out user

      get inline_geogebra_medium_path(free_medium)

      expect(response).to have_http_status(:ok)
      expect(response.headers["Content-Disposition"]).to include("inline")
      expect(response.headers["Cache-Control"]).not_to eq("no-cache, no-store")
    end
  end

  describe "GET /media/:id/check_annotation_visibility" do
    # SER-05 was a false positive: set_medium (a before_action that also runs for
    # this action) redirects on a missing medium, so the action never sees nil and
    # cannot 500. These lock in that safe behavior.
    it "redirects a bogus medium id instead of erroring" do
      get check_annotation_visibility_path(id: 0)

      expect(response).to have_http_status(:found)
      expect(response).to redirect_to(:root)
    end

    it "returns the visibility flag for an existing medium" do
      get check_annotation_visibility_path(id: medium_ruby.id)

      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /media/:id/search_content" do
    let(:search_client) { instance_double(SearchClient) }
    let(:free_medium) { create(:lecture_medium, :released) }

    before do
      sign_out user
      allow(SearchClient).to receive(:instance).and_return(search_client)
    end

    it "returns an empty array for a blank query" do
      get media_search_content_path(free_medium), params: { query: "" }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq([])
    end

    it "returns a 422 for a query exceeding the length limit" do
      long_query = "a" * (SearchClient::QUERY_MAX_LENGTH + 1)

      get media_search_content_path(free_medium), params: { query: long_query }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["error"]).to eq(I18n.t("search.query_too_long"))
    end

    it "delegates to SearchClient for valid queries" do
      expect(search_client).to receive(:search_with_sentence_scoring)
        .with("functional", whitelist_media_ids: [free_medium.id])
        .and_return([
                      { "media_rails_id" => free_medium.id, "text" => "result",
                        "start_time" => 0, "rrf_score" => 0.5,
                        "highlight_segments" => [{ "text" => "result", "color" => nil }] }
                    ])

      get media_search_content_path(free_medium), params: { query: "functional" }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.first["text"]).to eq("result")
    end

    it "rate-limits search requests beyond the per-minute threshold" do
      Rails.cache.clear
      allow(search_client).to receive(:search_with_sentence_scoring)
        .with("test", whitelist_media_ids: [free_medium.id])
        .and_return([])

      (SearchClient::RATE_LIMIT + 1).times do
        get media_search_content_path(free_medium), params: { query: "test" }
      end

      expect(response).to have_http_status(:too_many_requests)
      expect(response.parsed_body["error"]).to eq(I18n.t("search.too_many_requests"))
    ensure
      Rails.cache.clear
    end
  end
end
