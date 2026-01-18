# frozen_string_literal: true

class EntityMention < EntityKnowledge::EntityMention
  # App-specific association to card
  belongs_to :card

  def excerpt_with_context(context_chars: 50)
    text = case source_field
           when "title" then card.title
           when "description" then card.description
           else nil
           end

    return mention_text unless text && text_offset_start && text_offset_end

    start_pos = [0, text_offset_start - context_chars].max
    end_pos = [text.length, text_offset_end + context_chars].min

    prefix = start_pos > 0 ? "..." : ""
    suffix = end_pos < text.length ? "..." : ""

    "#{prefix}#{text[start_pos...end_pos]}#{suffix}"
  end
end
