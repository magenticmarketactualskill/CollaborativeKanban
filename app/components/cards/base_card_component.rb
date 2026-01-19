# frozen_string_literal: true

module Cards
  class BaseCardComponent < ApplicationComponent
    attr_reader :card, :board, :schema

    def initialize(card:, board:)
      @card = card
      @board = board
      @schema = CardSchemas::Registry.instance.schema_for_card(card)
    end

    def card_type_icon
      schema&.icon || "document"
    end

    def card_type_color
      schema&.color || "gray"
    end

    def card_type_display_name
      schema&.display_name || card.card_type.titleize
    end

    def priority_classes
      case card.priority
      when "low" then "bg-blue-100 text-blue-700"
      when "medium" then "bg-yellow-100 text-yellow-700"
      when "high" then "bg-orange-100 text-orange-700"
      when "urgent" then "bg-red-100 text-red-700"
      else "bg-gray-100 text-gray-700"
      end
    end

    def metadata
      card.card_metadata || {}
    end

    def dom_id
      "card-#{card.id}"
    end

    def border_color_class
      "border-#{card_type_color}-500"
    end

    def due_date_classes
      if card.overdue?
        "text-red-600"
      elsif card.due_soon?
        "text-orange-600"
      else
        "text-gray-500"
      end
    end

    def render_assignees
      return unless card.assignees.any?

      render "cards/shared/assignees", card: card
    end

    # Override in subclasses for type-specific content
    def type_specific_content
      nil
    end

    def render_icon(icon_name, classes: "h-4 w-4")
      case icon_name
      when "check-circle"
        content_tag(:svg, class: classes, viewBox: "0 0 20 20", fill: "currentColor") do
          content_tag(:path, "", fill_rule: "evenodd", d: "M10 18a8 8 0 100-16 8 8 0 000 16zm3.857-9.809a.75.75 0 00-1.214-.882l-3.483 4.79-1.88-1.88a.75.75 0 10-1.06 1.061l2.5 2.5a.75.75 0 001.137-.089l4-5.5z", clip_rule: "evenodd")
        end
      when "clipboard-list"
        content_tag(:svg, class: classes, viewBox: "0 0 20 20", fill: "currentColor") do
          content_tag(:path, "", fill_rule: "evenodd", d: "M15.988 3.012A2.25 2.25 0 0118 5.25v6.5A2.25 2.25 0 0115.75 14H13.5v-3.379a3 3 0 00-.879-2.121l-3.12-3.121a3 3 0 00-1.402-.791 2.252 2.252 0 011.913-1.576A2.25 2.25 0 0112.25 1h1.5a2.25 2.25 0 012.238 2.012zM11.5 3.25a.75.75 0 01.75-.75h1.5a.75.75 0 01.75.75v.25h-3v-.25z", clip_rule: "evenodd") +
          content_tag(:path, "", d: "M3.5 6A1.5 1.5 0 002 7.5v9A1.5 1.5 0 003.5 18h7a1.5 1.5 0 001.5-1.5v-5.879a1.5 1.5 0 00-.44-1.06L8.44 6.439A1.5 1.5 0 007.378 6H3.5z")
        end
      when "bug"
        content_tag(:svg, class: classes, viewBox: "0 0 20 20", fill: "currentColor") do
          content_tag(:path, "", fill_rule: "evenodd", d: "M6.56 1.14a.75.75 0 01.177 1.045 3.989 3.989 0 00-.464.86c.185.17.382.329.59.473A3.993 3.993 0 0110 2c1.272 0 2.405.594 3.137 1.518.208-.144.405-.302.59-.473a3.989 3.989 0 00-.464-.86.75.75 0 011.222-.869c.369.519.65 1.105.822 1.736a.75.75 0 01-.174.707 7.03 7.03 0 01-1.299 1.098A4 4 0 0114 6c0 .52-.301.963-.723 1.187a6.961 6.961 0 01-.635 3.044.75.75 0 11-1.357-.638c.271-.576.437-1.21.473-1.877-.467.02-.972.02-1.516.02-.544 0-1.049 0-1.516-.02.036.666.202 1.3.473 1.877a.75.75 0 11-1.357.638 6.961 6.961 0 01-.635-3.044C6.301 6.963 6 6.52 6 6c0-.22.036-.432.104-.627A7.029 7.029 0 014.805 4.275a.75.75 0 01-.174-.707c.172-.631.453-1.217.822-1.736a.75.75 0 011.045-.177L6.56 1.14zM10 7.5a2.5 2.5 0 100-5 2.5 2.5 0 000 5z", clip_rule: "evenodd") +
          content_tag(:path, "", d: "M5.23 7.482A4.988 4.988 0 005 9c0 1.213.431 2.326 1.149 3.194a.75.75 0 11-1.168.946A6.477 6.477 0 013.5 9a6.49 6.49 0 01.297-1.945.75.75 0 011.432.427zM14.77 7.482a.75.75 0 011.432-.427c.193.619.298 1.274.298 1.945 0 1.59-.572 3.046-1.521 4.173a.75.75 0 11-1.148-.98A4.988 4.988 0 0015 9c0-.534-.084-1.048-.23-1.518z") +
          content_tag(:path, "", d: "M6.543 15.048a6.97 6.97 0 003.399.952h.116a6.97 6.97 0 003.399-.952.75.75 0 01.757 1.295 8.47 8.47 0 01-4.156 1.157h-.116a8.47 8.47 0 01-4.156-1.157.75.75 0 01.757-1.295z")
        end
      when "flag"
        content_tag(:svg, class: classes, viewBox: "0 0 20 20", fill: "currentColor") do
          content_tag(:path, "", d: "M3.5 2.75a.75.75 0 00-1.5 0v14.5a.75.75 0 001.5 0v-4.392l1.657-.348a6.449 6.449 0 014.271.572 7.948 7.948 0 005.965.524l2.078-.64A.75.75 0 0018 12.25v-8.5a.75.75 0 00-.904-.734l-2.38.501a7.25 7.25 0 01-4.186-.363l-.502-.2a8.75 8.75 0 00-5.053-.439l-1.475.31V2.75z")
        end
      when "calendar"
        content_tag(:svg, class: classes, viewBox: "0 0 20 20", fill: "currentColor") do
          content_tag(:path, "", fill_rule: "evenodd", d: "M5.75 2a.75.75 0 01.75.75V4h7V2.75a.75.75 0 011.5 0V4h.25A2.75 2.75 0 0118 6.75v8.5A2.75 2.75 0 0115.25 18H4.75A2.75 2.75 0 012 15.25v-8.5A2.75 2.75 0 014.75 4H5V2.75A.75.75 0 015.75 2zm-1 5.5c-.69 0-1.25.56-1.25 1.25v6.5c0 .69.56 1.25 1.25 1.25h10.5c.69 0 1.25-.56 1.25-1.25v-6.5c0-.69-.56-1.25-1.25-1.25H4.75z", clip_rule: "evenodd")
        end
      else
        content_tag(:svg, class: classes, viewBox: "0 0 20 20", fill: "currentColor") do
          content_tag(:path, "", fill_rule: "evenodd", d: "M3 3.5A1.5 1.5 0 014.5 2h6.879a1.5 1.5 0 011.06.44l4.122 4.12A1.5 1.5 0 0117 7.622V16.5a1.5 1.5 0 01-1.5 1.5h-11A1.5 1.5 0 013 16.5v-13z", clip_rule: "evenodd")
        end
      end
    end
  end
end
