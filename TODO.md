# GrouperPlus TODO

## Ideas and Future Tasks

### Session Participation Notifications
- [ ] Add unobtrusive notification system when grouping sessions start
  - [ ] Small popup notification with auto-dismiss after 15-20 seconds
  - [ ] Action buttons: "Join Session", "Snooze for Session", "Snooze Until Tomorrow", "Disable Notifications"
  - [ ] Minimap icon visual indicator (pulsing/glowing) when session is available
  - [ ] Different minimap icon overlay for snoozed state (Zzz or moon icon)
- [ ] Implement snooze system
  - [ ] Snooze for current session only (session ID-based)
  - [ ] Snooze until tomorrow (resets at midnight server time)
  - [ ] Permanently disable notifications option
  - [ ] Un-snooze/re-enable via minimap right-click menu
  - [ ] Save snooze state and preferences in saved variables
- [ ] Create NotificationManager module to handle prompt display and snooze logic
- [ ] Extend SessionManager to trigger notifications on session create
- [ ] Add snooze management options to minimap dropdown menu
- [ ] Configuration options in settings panel
  - [ ] Re-enable notifications if disabled
  - [ ] Notification style preference (popup, chat only, minimap only)
  - [ ] Auto-join whitelist for trusted session owners

### Advanced Filtering
- [ ] Search and filter members by class
- [ ] Filter by specialization
- [ ] Filter by item level

### Activity Scheduling
- [ ] Calendar integration for planning guild events
- [ ] Schedule and track guild activities

### Export Functionality
- [ ] Export group compositions to various formats
- [ ] Export member availability data
- [ ] Share group setups with others

### Integrations
- [ ] Expand data sources beyond RaiderIO
- [ ] Additional third-party addon integrations

### Post-Session Actions
- [ ] Auto-invite finalized group members
- [ ] Session history and restoration

### Automatic Group Formation
- [ ] Consider class composition and synergies when forming groups
  - See [GROUP_SYNERGY.md](GROUP_SYNERGY.md) for detailed implementation plan
  - Includes dungeon-specific optimization, class synergy scoring, and keystone-aware formation
- [ ] Implement group rotation system to encourage player diversity
  - See [GROUP_ROTATION.md](GROUP_ROTATION.md) for rotation tracking and pairing history
  - Prevents repeated pairings and encourages guild members to play with different people

### Keystone Management ✅ PARTIALLY IMPLEMENTED
- [x] Detect and display player's current mythic+ keystone
- [x] Share keystone information between addon users in guild
- [x] Show keystone tooltips on character frames
- [ ] Assign keystones to groups based on member keystones
- [ ] Display which keystone each formed group will run
- [ ] Smart group formation considering available keystones
  - [ ] Keystone distribution analysis - avoid duplicate keystones in same group
  - [ ] Keystone level matching - group similar difficulty levels together
  - [ ] Dungeon-specific class composition optimization
  - [ ] Ensure each group has at least one keystone to run
  - [ ] Flag groups without keystones as support/backup groups
  - [ ] Prioritize higher keystones for higher-rated player groups

### Automatic Group Formation ✅ IMPLEMENTED
- [x] Auto-form groups based on mythic plus rating
- [x] Respect role limits (1 tank, 1 healer, 3 DPS) when auto-forming
- [x] Balance groups by skill level/rating
- [x] Smart role detection for all classes and specializations
- [x] Automatic group formation via slash command `/grouper auto`

### Role Management ✅ IMPLEMENTED
- [x] Add role limits per group (1 tank, 1 healer, 3 DPS per group)
- [x] Automatic role detection based on player specialization
- [x] Role-based positioning within groups (tanks first, healers, then DPS)
- [x] Real-time role change detection and UI updates

### Inter-Addon Communication ✅ IMPLEMENTED
- [x] Implement addon communication protocol for data sharing
- [x] Sync group formations between users with the addon installed
- [x] Share player data and group assignments across addon users
- [x] Share RaiderIO information so only one person needs both addons installed
- [x] Guild-wide version checking and user detection
- [x] Automatic role sharing between guild members with the addon
- [x] RaiderIO data synchronization across addon users

### Group Utility Tracking ✅ IMPLEMENTED
- [x] Track group buffs and utilities (bloodlust, battle rez, powerful abilities)
- [x] Display utility coverage per group
- [x] Consider utility distribution when forming groups

### Display Control ✅ IMPLEMENTED
- [x] Control player position/ordering within dynamic group display
- [x] Role-based positioning (tanks first, healers, then DPS)
- [x] Update dynamic lists to show user rating text
- [x] Class color coding for guild members
- [x] RaiderIO score display integration

### Addon User Management ✅ IMPLEMENTED
- [x] Show list of guild members who have GrouperPlus installed
- [x] Add UI panel/window to display connected addon users  
- [x] Integrate addon user list with existing communication system

### Version Management ✅ IMPLEMENTED
- [x] Warn user when newer version of addon is detected in guild
- [x] Display informative message with download/update instructions
- [x] Add version comparison logic to communication system
- [x] Show version warnings in user interface

### Grouping Session Management ✅ IMPLEMENTED
- [x] Add "Start Session" button to main frame
  - [x] When clicked, initiates a grouping session that locks editing to authorized users
  - [x] Session owner (person who started) has full control
  - [x] Other players see groups in read-only mode by default
- [x] Implement whitelist system for collaboration permissions
  - [x] Allow session owner to grant edit permissions to specific players
  - [x] Whitelist persists during the session
  - [x] Visual indicator showing who has edit permissions (use raid assist icon)
  - [x] Session owner shown with raid leader icon
  - [x] Quick add/remove buttons for managing whitelist
- [x] Add "Finalize Groups" button
  - [x] Locks in the current group composition
  - [x] Prevents any further edits
  - [x] Broadcasts final groups to all addon users
- [x] Session state synchronization
  - [x] Sync session state across all addon users
  - [x] Show current session status (open/locked/finalized)
  - [x] Display who started the session and who has permissions

<!-- Add items here as they come up -->
