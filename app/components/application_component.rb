# frozen_string_literal: true

class ApplicationComponent < ViewComponent::Base
  include Turbo::FramesHelper
  include Turbo::StreamsHelper
end
