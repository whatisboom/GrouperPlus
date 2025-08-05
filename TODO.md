# GrouperPlus TODO

## Ideas and Future Tasks

### Automatic Group Formation ✅ IMPLEMENTED
- [x] Auto-form groups based on mythic plus rating
- [x] Respect role limits (1 tank, 1 healer, 3 DPS) when auto-forming
- [x] Balance groups by skill level/rating
- [x] Smart role detection for all classes and specializations
- [x] Automatic group formation via slash command `/grouper auto`
- [ ] Consider class composition and synergies when forming groups

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

### Addon User Management ✅ IMPLEMENTED
- [x] Show list of guild members who have GrouperPlus installed
- [x] Add UI panel/window to display connected addon users  
- [x] Integrate addon user list with existing communication system

### Version Management ✅ IMPLEMENTED
- [x] Warn user when newer version of addon is detected in guild
- [x] Display informative message with download/update instructions
- [x] Add version comparison logic to communication system
- [x] Show version warnings in user interface

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

<!-- Add items here as they come up -->
