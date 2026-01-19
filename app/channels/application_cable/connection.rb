module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = find_verified_user
    end

    private

    def find_verified_user
      # Support session-based auth
      if (user_id = cookies.encrypted[:user_id])
        return User.find_by(id: user_id)
      end

      # Support token-based auth for MCP connections
      if (token = request.params[:token])
        config = McpServerConfiguration.global.first
        if config&.auth_type == "token" && config.valid_token?(token)
          # Anonymous MCP connection with valid token
          return nil
        end
      end

      # Allow anonymous connections for MCP (authentication handled at channel level)
      nil
    end
  end
end
