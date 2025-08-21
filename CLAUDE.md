# GrouperPlus Development Context

## Project Overview
GrouperPlus is a World of Warcraft addon that provides group management functionality with a minimap icon and configurable settings.

## Current Architecture

### Core Files
- `GrouperPlus.lua` - Main addon file with initialization, debug system, and minimap integration
- `GrouperPlus.toc` - Table of contents file listing all addon components
- `modules/MinimapMenu.lua` - Dropdown menu functionality for the minimap icon
- `modules/OptionsPanel.lua` - Integration with WoW's interface options panel using the new Settings API

### Libraries Used
- **AceDB-3.0** - Database/saved variables management
- **LibDBIcon-1.0** - Minimap button functionality
- **LibStub** - Library versioning
- **CallbackHandler-1.0** - Event handling

### Key Features
1. **Debug System** - Multi-level logging (ERROR, WARN, INFO, DEBUG, TRACE)
2. **Minimap Icon** - Draggable icon with left/right-click functionality
3. **Options Panel** - Integrated into WoW's interface options (ESC → Options → AddOns → GrouperPlus)
4. **Auto-Formation with Utility Distribution** - Intelligent group creation that balances roles, skill levels, and utility coverage
5. **Slash Commands**:
   - `/grouper` - Main command
   - `/grouper show` or `/grouper minimap` - Show minimap icon
   - `/grouper hide` - Hide minimap icon
   - `/grouperopt` or `/grouperptions` - Open options panel

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
- Prefer editing existing files over creating new ones

## Recent Changes
- Migrated from deprecated `InterfaceOptions_AddCategory` to new Settings API
- Added comprehensive debug logging to all options panel functionality
- Simplified button implementation due to API limitations
- Integrated settings with AceDB saved variables using proxy settings
- Implemented intelligent utility distribution in auto-formation algorithm
- Added utility tracking and optimization for combat resurrection, bloodlust, and raid buffs

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

## Testing Commands
```
/reload - Reload the UI
/grouperopt - Open options panel
/grouper show - Show minimap icon
/grouper hide - Hide minimap icon
/grouper auto - Test auto-formation with utility distribution
```

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