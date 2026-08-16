require "rails_helper"
RSpec.describe(LecturesController, type: :controller) do
  let(:teacher) { FactoryBot.create(:confirmed_user) }
  let(:generic_user) { FactoryBot.create(:confirmed_user) }
  let(:lecture) { FactoryBot.create(:lecture, teacher: teacher) }
  let(:admin) { FactoryBot.create(:confirmed_user, admin: true) }
  let(:editor) { FactoryBot.create(:confirmed_user, edited_lectures: [lecture]) }

  def expect_lecture_update_fail(lecture, new_teacher)
    expect do
      post(:update, params: { id: lecture.id,
                              lecture: { teacher_id: new_teacher.id } })
    end.to(raise_error do |error|
      expect(error).to be_a(ActionController::ParameterMissing)
      expect(error.message).to include("invalid")
      expect(error.message).to include("lecture")
    end)
  end

  context "As a teacher" do
    before do
      sign_in teacher
    end

    describe "POST #update" do
      it "fails trying to update the teacher" do
        new_teacher = FactoryBot.create(:confirmed_user)
        expect_lecture_update_fail(lecture, new_teacher)
      end
    end
  end

  context "As an editor" do
    before do
      sign_in editor
    end

    describe "POST #update" do
      it "does not update the teacher" do
        edited_lecture = editor.edited_lectures.first
        new_teacher = FactoryBot.create(:confirmed_user)
        expect_lecture_update_fail(edited_lecture, new_teacher)
      end
    end
  end

  context "As an admin" do
    before do
      sign_in admin
    end

    describe "POST #update" do
      it "updates the teacher" do
        new_teacher = FactoryBot.create(:confirmed_user)
        post(:update, params: { id: lecture.id,
                                lecture: { teacher_id: new_teacher.id } })
        lecture.reload
        expect(lecture.teacher).to eq(new_teacher)
      end
    end
  end

  describe "GET #search_content_results" do
    let(:searched_lecture) { create(:lecture, :released_for_all) }
    let(:user) { create(:confirmed_user) }
    let(:visible_medium) { create(:lecture_medium, teachable: searched_lecture, released: "all") }
    let(:hidden_medium) { create(:lecture_medium, teachable: searched_lecture) }
    let(:foreign_lecture) { create(:lecture, :released_for_all) }
    let(:foreign_medium) { create(:lecture_medium, teachable: foreign_lecture, released: "all") }
    let(:search_client) { instance_double(SearchClient) }

    before do
      sign_in user
      create(:lecture_user_join, lecture: searched_lecture, user: user)
      allow(SearchClient).to receive(:instance).and_return(search_client)
      allow(search_client)
        .to receive(:search_with_sentence_scoring)
        .with("searching", whitelist_lecture_ids: [searched_lecture.id])
        .and_return([
                      { "media_rails_id" => visible_medium.id,
                        "text" => "visible result", "start_time" => 1,
                        "highlight_segments" => [{ "text" => "visible result", "color" => nil }] },
                      { "media_rails_id" => hidden_medium.id,
                        "text" => "hidden result", "start_time" => 2,
                        "highlight_segments" => [{ "text" => "hidden result", "color" => nil }] },
                      { "media_rails_id" => foreign_medium.id,
                        "text" => "foreign result", "start_time" => 3,
                        "highlight_segments" => [{ "text" => "foreign result", "color" => nil }] }
                    ])
    end

    it "only returns results whose media belong to the lecture and are visible to the user" do
      get :search_content_results, params: { id: searched_lecture.id, search: "searching" }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["results"].pluck("media_id"))
        .to contain_exactly(visible_medium.id)
    end

    it "returns an empty result list for a blank query" do
      get :search_content_results, params: { id: searched_lecture.id, search: "" }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["results"]).to eq([])
    end

    it "returns an error when MampfSearch is unavailable" do
      allow(search_client)
        .to receive(:search_with_sentence_scoring)
        .and_raise(SearchClient::ServiceUnavailableError, "down")

      get :search_content_results, params: { id: searched_lecture.id, search: "searching" }

      expect(response).to have_http_status(:service_unavailable)
      expect(response.parsed_body["error"]).to eq(I18n.t("search.mampfsearch_unavailable"))
    end
  end
end
