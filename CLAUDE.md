# GrouperPlus Development Context

## Project Overview
GrouperPlus is a World of Warcraft addon that provides group management functionality with a minimap icon and configurable settings.

## Current Architecture

### Unified State Management System (v0.10+)
GrouperPlus now uses a completely redesigned unified state management architecture for perfect synchronization across all connected clients.

#### Core State Modules
- `modules/WoWAPIWrapper.lua` - Abstracts all WoW APIs for future unit testing
- `modules/MemberStateManager.lua` - Single source of truth for all member data and status
- `modules/GroupStateManager.lua` - Manages group compositions and member assignments
- `modules/SessionStateManager.lua` - Handles session permissions, lifecycle, and admin controls
- `modules/MessageProtocol.lua` - Defines message formats, validation, and serialization
- `modules/StateSync.lua` - Unified synchronization system using AceComm-3.0

#### Legacy Modules (Backward Compatibility)
- `modules/AddonComm.lua` - Legacy communication system (maintained for compatibility)
- `modules/SessionManager.lua` - Legacy session management (superseded by SessionStateManager)
- `modules/MemberManager.lua` - Legacy member management (superseded by MemberStateManager)

#### Core Files
- `GrouperPlus.lua` - Main addon file with initialization and unified state system bootstrap
- `GrouperPlus.toc` - Table of contents file listing all addon components
- `modules/MinimapMenu.lua` - Dropdown menu functionality for the minimap icon
- `modules/OptionsPanel.lua` - Integration with WoW's interface options panel using the new Settings API

### Libraries Used
- **Full Ace3 Library Suite** - Complete Ace framework for robust addon development
  - **AceAddon-3.0** - Addon lifecycle and dependency management
  - **AceEvent-3.0** - Event-driven architecture and messaging
  - **AceTimer-3.0** - Reliable timer system for debouncing and throttling
  - **AceComm-3.0** - Automatic message chunking and reliable delivery (with ChatThrottleLib)
  - **AceSerializer-3.0** - Robust serialization for complex data structures
  - **AceDB-3.0** - Database/saved variables management
- **LibDBIcon-1.0** - Minimap button functionality
- **LibStub** - Library versioning
- **CallbackHandler-1.0** - Event handling

### Key Features
1. **Unified State Management** - Single source of truth for all member data, group assignments, and session state
2. **Perfect Visual Synchronization** - All connected clients stay perfectly synced in real-time
3. **Session-Based Administration** - Session owners can control permissions and lock/unlock editing
4. **Cross-Realm Support** - Full support for players from different realms with proper name normalization
5. **Event-Driven Architecture** - Uses Ace3 event system for clean, responsive communication
6. **Debug System** - Multi-level logging (ERROR, WARN, INFO, DEBUG, TRACE)
7. **Minimap Icon** - Draggable icon with left/right-click functionality
8. **Options Panel** - Integrated into WoW's interface options (ESC → Options → AddOns → GrouperPlus)
9. **Auto-Formation with Utility Distribution** - Intelligent group creation that balances roles, skill levels, and utility coverage
10. **Comprehensive Testing** - Built-in test command to verify all systems

## Development Guidelines

### Debug Logging
- **Always add debug logging to new features**, especially:
  - All option changes in the options panel
  - User interactions (clicks, commands)
  - State changes (show/hide, enable/disable)
  - Error conditions
  
- **Debug levels to use**:
  - `TRACE` - For frequent operations like getters
  - `DEBUG` - For detailed operations and initialization
  - `INFO` - For user-initiated changes and important events
  - `WARN` - For potential issues or fallback behavior
  - `ERROR` - For critical failures

### Debugging Memory
- **Do not use warm or error levels for anything debugging related**

### Options Panel
When adding new options to the settings panel:
1. Use `Settings.RegisterProxySetting` to integrate with saved variables
2. Add comprehensive debug logging for both getter and setter functions
3. Log old and new values when settings change
4. Test with the new Settings API (post-Dragonflight)

### Code Style
- Use local variables and functions where possible
- Follow existing naming conventions (camelCase for functions, UPPER_CASE for constants)
- Avoid adding comments unless specifically requested
- **Create small, atomic modules** - Keep modules focused on single responsibilities
- **Abstract WoW APIs** - Use WoWAPIWrapper for all WoW API calls to enable future unit testing
- **Keep methods small** - Break complex functions into smaller, focused methods

### Unified State Management Guidelines
- **Always use the new state managers** for member, group, and session operations
- **Never bypass the unified state system** - All state changes must go through the appropriate manager
- **Use proper event messaging** - State changes trigger events that other modules can listen to
- **Cross-realm name normalization** - Always use WoWAPIWrapper:NormalizePlayerName() for player names
- **Session permissions** - Check SessionStateManager:CanEditMembers() and CanEditGroups() before modifications

## Recent Changes (v0.10+ Major Refactor)
- **BREAKING**: Complete architectural overhaul to unified state management system
- **NEW**: Six new core state modules (WoWAPIWrapper, MemberStateManager, GroupStateManager, SessionStateManager, MessageProtocol, StateSync)
- **NEW**: Full Ace3 library suite integration for robust event-driven architecture
- **NEW**: Perfect visual synchronization across all connected clients
- **NEW**: Session-based administration with permission controls
- **NEW**: Comprehensive test command `/grouper test-unified` to verify all systems
- **IMPROVED**: Cross-realm support with proper name normalization throughout
- **IMPROVED**: Event-driven communication using AceEvent-3.0 messaging
- **LEGACY**: Previous modules maintained for backward compatibility during transition

## Known Issues/Limitations
- Button controls in the Settings API have strict requirements and may need workarounds
- The new Settings API requires different approaches than the legacy interface options

## Utility Distribution System

### Overview
The auto-formation algorithm includes intelligent utility distribution that ensures each group has optimal coverage of critical abilities.

### Utility Priorities
- **Priority 1 (Critical)**: Combat Rez, Bloodlust - Heavy penalties if missing (-200), large bonuses if present (+100)
- **Priority 2 (Important)**: Intellect, Stamina, Attack Power, Versatility, Skyfury - Moderate penalties if missing (-75), medium bonuses if present (+50)  
- **Priority 3 (Nice-to-have)**: Mystic Touch, Chaos Brand - Small bonuses if present (+25), no penalty if missing

### Algorithm Phases
1. **Phase 1**: Create role-balanced groups (1T/1H/3D) sorted by RaiderIO scores
2. **Phase 2**: Optimize utility distribution by swapping DPS members between groups
   - Only swaps members of the same role to maintain balance
   - Iteratively improves until no beneficial swaps are found
   - Maximum 10 iterations to prevent infinite loops

### Class Utility Mapping
Defined in `constants.lua` with `CLASS_UTILITIES` and `UTILITY_INFO` tables:
- Death Knight: Combat Rez
- Druid: Combat Rez, Versatility
- Evoker: Bloodlust
- Hunter: Bloodlust
- Mage: Bloodlust, Intellect
- Monk: Mystic Touch
- Paladin: Combat Rez
- Priest: Stamina
- Shaman: Bloodlust, Skyfury
- Warlock: Combat Rez
- Warrior: Attack Power
- Demon Hunter: Chaos Brand

### Development Notes
- All utility functions are in `modules/AutoFormation.lua`
- Comprehensive debug logging tracks optimization decisions
- Visual indicators in MainFrame show utility coverage per group
- System integrates seamlessly with existing role balancing

## Commands

### User Commands
Primary commands for everyday use:
```
/grouper form - Auto-form balanced groups with utility distribution
/grouper toggle - Show/hide main window
/grouper config - Open addon settings
/grouper minimap - Show/hide minimap icon
/grouper help - Show command help
/grouperopt - Quick access to options panel
```

### Developer Commands
Access advanced debugging and testing features with `/grouper dev` or use directly:
```
/grouper test-unified - Comprehensive test of all state management systems
/grouper test-state - Alias for test-unified
/grouper dev - Show all developer commands
```

### System Commands
```
/reload - Reload the UI (WoW built-in)
```

### State Management Test Coverage
The `/grouper test-unified` command verifies:
1. **WoWAPIWrapper** - API abstraction and player info retrieval
2. **MemberStateManager** - Member addition, removal, and state management
3. **GroupStateManager** - Group creation, member assignment, and composition tracking
4. **SessionStateManager** - Session creation, permissions, and lifecycle
5. **MessageProtocol** - Message creation, serialization, and validation
6. **StateSync** - Sync initialization, history tracking, and communication
7. **Integration Test** - How all systems work together (session permissions affecting group edits)

### Cross-Realm Testing
To properly test cross-realm functionality:
1. Form parties/raids with players from different realms
2. Run `/grouper test-unified` on all clients
3. Test member list synchronization across realms
4. Verify group assignment synchronization
5. Test session creation and permission propagation

## Documentation Guidelines
- **Focus on user value, not implementation details** - Users care about what the addon does for them, not how it's built
- **Technical features should be user-facing benefits** - Include technical details only if they directly benefit users (e.g., debug logging for troubleshooting)
- **Be specific about valuable features** - Instead of generic descriptions, highlight specific benefits (e.g., "RaiderIO score integration" vs "third-party integration")
- **Remove redundant information** - Don't repeat the same functionality in multiple sections
- **Prioritize end-user documentation over developer details** - Save technical architecture details for separate developer documentation

## Commit Guidelines
- **Never include Claude/AI references in commit messages**
- Do not add "Generated with Claude Code" or "Co-Authored-By: Claude" lines
- Keep commit messages clean and professional
- Always use commit message format "type(scope): description"
- **Don't have uninformative commit messages like bumping the version when there were significant changes involved**

## Future Considerations
- When adding new features, always consider the debug logging requirements
- Test thoroughly with different debug levels to ensure logging is appropriate
- Maintain compatibility with the new Settings API introduced in Dragonflight

## Release Preparation
- Before creating a release or tag, update appropriate files (toc, etc) to mirror the new version
- **Release Workflow**:
  - Before building, update the version number in the repository in all applicable places, following semantic versioning rules
  - Include all the changes in the release
  - Afterwards, tag, push, and release on GitHub as well
- **Important Note**: When creating a release, publish the full release on GitHub, not just create a tag

## Security Guidelines
- Never execute 'lua' on the command line as this repository contains WoW client specific code
- **Never run lua directly since these files contained wow specific client code**

## Code Development Warnings
- Never put character specific debug code

## Memory Notes
- Keep the readme as user-focused as you can
- the CURSEFORGE_API_TOKEN is set in env

## Development Reminders
- Update the version in the issue configs when we update it in the toc and other places

## Release Process Memory
- When asked to do a release, you will update the version, prompting for major/minor/patch increments if you are not sure based on the changes, update the changelog, commit the change to git, create a git tag, push to origin, and then publish a release on github, and then using ./deploy-full.sh you will publish a release to curseforge

## Unified State Management Architecture

### State Manager Responsibilities
- **MemberStateManager** - Single source of truth for all member data (roles, ratings, online status, group assignments)
- **GroupStateManager** - Manages group compositions, member assignments, and group metadata
- **SessionStateManager** - Handles session lifecycle, permissions, admin controls, and locked/unlocked states
- **StateSync** - Coordinates synchronization between all connected clients using AceComm-3.0
- **MessageProtocol** - Ensures message format consistency, validation, and version compatibility
- **WoWAPIWrapper** - Abstracts all WoW API calls for consistent behavior and future unit testing

### Event-Driven Communication
All state changes trigger events using AceEvent-3.0 messaging:
- `GROUPERPLUS_MEMBER_ADDED` - New member discovered or added
- `GROUPERPLUS_MEMBER_UPDATED` - Member data changed (role, rating, etc.)
- `GROUPERPLUS_MEMBER_REMOVED` - Member removed from system
- `GROUPERPLUS_GROUP_CREATED` - New group created
- `GROUPERPLUS_MEMBER_ADDED_TO_GROUP` - Member assigned to group
- `GROUPERPLUS_MEMBER_REMOVED_FROM_GROUP` - Member removed from group
- `GROUPERPLUS_SESSION_CREATED` - New session started
- `GROUPERPLUS_SESSION_ENDED` - Session terminated

### Cross-Realm Support (Built-In)
The unified system handles cross-realm functionality automatically:
- **Automatic name normalization** via WoWAPIWrapper:NormalizePlayerName()
- **Cross-realm message routing** through proper AceComm distribution channels
- **Consistent player identification** using full PlayerName-RealmName format throughout
- **Cross-realm group assignments** with proper synchronization across different realms

### Session-Based Administration
- **Session owners** have full administrative control over member lists and group assignments
- **Locked sessions** prevent non-admin modifications to maintain group stability
- **Permission system** allows granular control over who can edit members vs groups
- **Admin delegation** enables multiple administrators per session for large groups

### Perfect Synchronization Guarantee
The unified state system ensures:
- **Single source of truth** - All clients reference the same authoritative state
- **Real-time updates** - State changes immediately propagate to all connected clients
- **Conflict resolution** - Admin permissions and session locks prevent conflicting edits
- **Visual consistency** - All clients display identical member lists and group assignments
- when running lua check, fix any and all warnings and errors and issues
- instead of using a fallback if a global isn't defined use a local to redefine the global