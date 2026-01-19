# MCP Server/Client Configuration
#
# This initializer sets up the Model Context Protocol (MCP) registries
# for tools and resources.

Rails.application.config.after_initialize do
  # Register default MCP server tools
  Mcp::Server::ToolRegistry.instance.register_defaults!

  # Register default MCP server resources
  Mcp::Server::ResourceRegistry.instance.register_defaults!

  Rails.logger.info "MCP Server initialized with #{Mcp::Server::ToolRegistry.instance.all.size} tools"
end
