# frozen_string_literal: true

module Cards
  class TaskCardComponent < BaseCardComponent
    def status
      metadata["status"] || "pending"
    end

    def estimated_hours
      metadata["estimated_hours"]
    end

    def actual_hours
      metadata["actual_hours"]
    end

    def tags
      metadata["tags"] || []
    end

    def status_badge_classes
      case status
      when "pending" then "bg-gray-100 text-gray-700"
      when "in_progress" then "bg-blue-100 text-blue-700"
      when "blocked" then "bg-red-100 text-red-700"
      when "completed" then "bg-green-100 text-green-700"
      else "bg-gray-100 text-gray-700"
      end
    end

    def progress_percentage
      return nil unless estimated_hours && actual_hours && estimated_hours.to_i > 0

      [(actual_hours.to_f / estimated_hours * 100).round, 100].min
    end

    def show_time_tracking?
      estimated_hours.present? || actual_hours.present?
    end

    def show_tags?
      tags.any?
    end
  end
end
