# Setup LLM configurations
puts "Setting up LLM configurations..."
LlmConfig::Setup.call
puts "Created #{LlmConfiguration.count} LLM configurations"

# Create sample users
puts "Creating users..."

demo_user = User.find_or_create_by!(email: 'demo@example.com') do |u|
  u.open_id = 'demo-user-001'
  u.name = 'Demo User'
  u.login_method = 'email'
  u.role = 'user'
end

alice = User.find_or_create_by!(email: 'alice@example.com') do |u|
  u.open_id = 'alice-user-002'
  u.name = 'Alice Smith'
  u.login_method = 'email'
  u.role = 'user'
end

bob = User.find_or_create_by!(email: 'bob@example.com') do |u|
  u.open_id = 'bob-user-003'
  u.name = 'Bob Johnson'
  u.login_method = 'email'
  u.role = 'user'
end

carol = User.find_or_create_by!(email: 'carol@example.com') do |u|
  u.open_id = 'carol-user-004'
  u.name = 'Carol Williams'
  u.login_method = 'email'
  u.role = 'admin'
end

puts "Created #{User.count} users"

# Create sample boards
puts "Creating boards..."

personal_board = Board.find_or_create_by!(name: 'My Tasks', owner: demo_user) do |b|
  b.description = 'Personal task tracking'
  b.level = 'personal'
end

team_board = Board.find_or_create_by!(name: 'Team Sprint', owner: demo_user) do |b|
  b.description = 'Current sprint tasks for the development team'
  b.level = 'team'
end

group_board = Board.find_or_create_by!(name: 'Q1 Projects', owner: demo_user) do |b|
  b.description = 'Cross-team project tracking for Q1'
  b.level = 'group'
end

puts "Created #{Board.count} boards"

# Add members to team board
BoardMember.find_or_create_by!(board: team_board, user: alice) do |m|
  m.role = 'editor'
end

BoardMember.find_or_create_by!(board: team_board, user: bob) do |m|
  m.role = 'viewer'
end

BoardMember.find_or_create_by!(board: group_board, user: alice) do |m|
  m.role = 'admin'
end

BoardMember.find_or_create_by!(board: group_board, user: carol) do |m|
  m.role = 'editor'
end

puts "Added board members"

# Create sample cards for personal board
puts "Creating cards..."

if personal_board.cards.empty?
  todo_column = personal_board.columns.find_by(name: 'To Do')
  in_progress_column = personal_board.columns.find_by(name: 'In Progress')
  done_column = personal_board.columns.find_by(name: 'Done')

  Card.create!([
    {
      board: personal_board,
      column: todo_column,
      title: 'Review quarterly report',
      description: 'Go through the quarterly performance metrics and prepare summary',
      priority: 'high',
      due_date: 3.days.from_now,
      created_by: demo_user,
      position: 0
    },
    {
      board: personal_board,
      column: todo_column,
      title: 'Update documentation',
      description: 'Add new API endpoints to the developer documentation',
      priority: 'medium',
      created_by: demo_user,
      position: 1
    },
    {
      board: personal_board,
      column: in_progress_column,
      title: 'Fix login bug',
      description: 'Users are experiencing intermittent login failures',
      priority: 'urgent',
      due_date: 1.day.from_now,
      created_by: demo_user,
      position: 0
    },
    {
      board: personal_board,
      column: done_column,
      title: 'Setup development environment',
      priority: 'low',
      created_by: demo_user,
      position: 0
    }
  ])
end

# Create sample cards for team board
if team_board.cards.empty?
  todo_column = team_board.columns.find_by(name: 'To Do')
  in_progress_column = team_board.columns.find_by(name: 'In Progress')
  done_column = team_board.columns.find_by(name: 'Done')

  card1 = Card.create!(
    board: team_board,
    column: todo_column,
    title: 'Implement user authentication',
    description: 'Add OAuth2 support for Google and GitHub login',
    priority: 'high',
    due_date: 1.week.from_now,
    created_by: demo_user,
    position: 0
  )
  card1.assignees << alice

  card2 = Card.create!(
    board: team_board,
    column: todo_column,
    title: 'Design new dashboard',
    description: 'Create mockups for the analytics dashboard redesign',
    priority: 'medium',
    created_by: demo_user,
    position: 1
  )
  card2.assignees << bob

  card3 = Card.create!(
    board: team_board,
    column: in_progress_column,
    title: 'API rate limiting',
    description: 'Implement rate limiting for public API endpoints',
    priority: 'high',
    due_date: 5.days.from_now,
    created_by: alice,
    position: 0
  )
  card3.assignees << [demo_user, alice]

  Card.create!(
    board: team_board,
    column: done_column,
    title: 'Database migration',
    description: 'Migrate user data to new schema',
    priority: 'urgent',
    created_by: demo_user,
    position: 0
  )
end

puts "Created #{Card.count} cards"
puts "Seed data created successfully!"
puts ""
puts "Login with: demo@example.com"
