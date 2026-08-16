require "erb"

class SearchClient
  module SentenceHighlighter
    def self.format(sentences)
      formatted_parts = []
      was_cut = false

      sentences.each do |s|
        score = s["rerank_score"] || 0
        text = s["sentence"]

        if score < 0.2
          unless was_cut
            formatted_parts << "[...]"
            was_cut = true
          end
        else
          was_cut = false

          # Clamp score between 0.2 and 1.0
          clamped_score = score.clamp(0.2, 1.0)

          # Calculate hue: 60 (yellow) at score 0.2, 0 (red) at score 1.0
          normalized = (clamped_score - 0.2) / 0.8
          hue = (60 - (normalized * 60)).round

          color_style = "background-color: hsla(#{hue}, 100%, 50%, 0.3);"
          escaped_text = ERB::Util.html_escape(text)

          formatted_parts << "<span style=\"#{color_style}\">#{escaped_text}</span>"
        end
      end

      formatted_parts.join(" ")
    end
  end
end
