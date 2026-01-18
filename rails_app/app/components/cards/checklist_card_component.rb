# frozen_string_literal: true

module Cards
  class ChecklistCardComponent < BaseCardComponent
    def items
      raw_items = metadata["items"] || []
      raw_items.map do |item|
        if item.is_a?(Hash)
          item.symbolize_keys
        else
          { text: item.to_s, completed: false }
        end
      end
    end

    def completed_items_count
      items.count { |item| item[:completed] }
    end

    def total_items_count
      items.count
    end

    def progress_percentage
      return 0 if total_items_count.zero?

      (completed_items_count.to_f / total_items_count * 100).round
    end

    def show_progress?
      metadata.fetch("show_progress", true) && items.any?
    end

    def all_completed?
      items.any? && items.all? { |item| item[:completed] }
    end

    def visible_items
      items.first(3)
    end

    def remaining_items_count
      [items.count - 3, 0].max
    end
  end
end
