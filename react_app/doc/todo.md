# MagenticFactory TODO

## Database Schema
- [x] Design boards table with multi-level support (Personal, Team, Group, Enterprise)
- [x] Design cards table with task details (title, description, priority, assignee, due date)
- [x] Design columns table for customizable workflow stages
- [x] Design board_members table for team collaboration and roles
- [x] Design card_assignments table for task ownership
- [x] Design board_activity table for real-time collaboration tracking

## Backend API (tRPC Procedures)
- [x] Board management procedures (create, read, update, delete, list by level)
- [x] Card management procedures (create, read, update, delete, move between columns)
- [x] Column management procedures (create, read, update, delete, reorder)
- [x] Board member management procedures (invite, remove, update role)
- [x] Card assignment procedures (assign, unassign users)
- [x] Activity tracking procedures (log views, edits, real-time presence)
- [ ] Search and filter procedures (by priority, assignee, status, date)

## Frontend UI
- [x] Main dashboard layout with multi-level board navigation
- [x] Board list view showing Personal, Team, Group, Enterprise boards
- [x] KanBan board view with drag-and-drop columns and cards
- [x] Card detail side panel with edit functionality
- [ ] Board settings panel for customization
- [x] Team member management interface
- [ ] Visual filters and search interface
- [x] Real-time collaboration indicators (avatars, presence)

## Drag-and-Drop Features
- [x] Implement drag-and-drop for cards between columns
- [x] Visual feedback during drag operations
- [x] Optimistic updates for smooth UX
- [x] Handle drag-and-drop validation and error states

## Real-time Collaboration
- [x] Real-time presence indicators showing active users
- [x] Live updates when cards are moved or edited
- [x] Conflict resolution for concurrent edits
- [x] Visual indicators for who is viewing/editing cards

## Board Customization
- [ ] Create custom columns interface
- [ ] Reorder columns with drag-and-drop
- [ ] Rename and delete columns
- [ ] Set default columns for new boards

## Team Management
- [ ] Invite team members to boards
- [ ] Role management (viewer, editor, admin)
- [ ] Remove team members
- [ ] View team member list with roles

## Testing
- [x] Write vitest tests for board procedures
- [x] Write vitest tests for card procedures
- [x] Write vitest tests for column procedures
- [x] Write vitest tests for member management
- [x] Write vitest tests for activity tracking

## Final Delivery
- [x] Test all features end-to-end
- [x] Create checkpoint
- [x] Deliver to user
