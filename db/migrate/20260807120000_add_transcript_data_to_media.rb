class AddTranscriptDataToMedia < ActiveRecord::Migration[8.0]
  def change
    add_column :media, :transcript_data, :text
  end
end
