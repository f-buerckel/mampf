class SearchClient
  module SentenceHighlighter
    def self.segments(sentences)
      segments = []
      was_cut = false

      sentences.each do |s|
        score = s["rerank_score"] || 0
        text = s["sentence"].to_s

        if score < 0.2
          unless was_cut
            segments << { "text" => "[...]", "color" => nil }
            was_cut = true
          end
        else
          was_cut = false
          segments << { "text" => text, "color" => color_for(score) }
        end
      end

      segments
    end

    def self.color_for(score)
      # Clamp score between 0.2 and 1.0
      clamped_score = [[score, 0.2].max, 1.0].min

      # Calculate hue: 60 (yellow) at score 0.2, 0 (red) at score 1.0
      normalized = (clamped_score - 0.2) / 0.8
      hue = (60 - (normalized * 60)).round

      "hsla(#{hue}, 100%, 50%, 0.3)"
    end
  end
end
