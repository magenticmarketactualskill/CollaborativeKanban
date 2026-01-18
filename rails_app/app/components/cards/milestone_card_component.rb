# frozen_string_literal: true

module Cards
  class MilestoneCardComponent < BaseCardComponent
    def target_date
      date_str = metadata["target_date"]
      return nil unless date_str.present?

      Date.parse(date_str)
    rescue Date::Error
      nil
    end

    def progress_percentage
      metadata["progress_percentage"]&.to_i || 0
    end

    def linked_cards_count
      (metadata["linked_cards"] || []).count
    end

    def success_criteria
      metadata["success_criteria"]
    end

    def target_date_status
      return nil unless target_date

      if target_date < Date.current
        :overdue
      elsif target_date <= Date.current + 7.days
        :due_soon
      else
        :on_track
      end
    end

    def target_date_classes
      case target_date_status
      when :overdue then "text-red-600"
      when :due_soon then "text-orange-600"
      else "text-gray-500"
      end
    end

    def progress_color
      case progress_percentage
      when 0..25 then "bg-red-400"
      when 26..50 then "bg-orange-400"
      when 51..75 then "bg-yellow-400"
      when 76..99 then "bg-blue-400"
      else "bg-green-500"
      end
    end

    def completed?
      progress_percentage >= 100
    end
  end
end
