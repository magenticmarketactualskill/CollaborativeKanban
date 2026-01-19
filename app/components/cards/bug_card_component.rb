# frozen_string_literal: true

module Cards
  class BugCardComponent < BaseCardComponent
    def severity
      metadata["severity"] || "medium"
    end

    def affected_version
      metadata["affected_version"]
    end

    def browser
      metadata["browser"]
    end

    def severity_badge_classes
      case severity
      when "low" then "bg-blue-100 text-blue-700"
      when "medium" then "bg-yellow-100 text-yellow-700"
      when "high" then "bg-orange-100 text-orange-700"
      when "critical" then "bg-red-100 text-red-700"
      else "bg-gray-100 text-gray-700"
      end
    end

    def severity_icon_classes
      case severity
      when "critical" then "text-red-500 animate-pulse"
      when "high" then "text-orange-500"
      when "medium" then "text-yellow-500"
      else "text-blue-500"
      end
    end

    def critical?
      severity == "critical"
    end
  end
end
