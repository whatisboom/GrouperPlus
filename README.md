# GrouperPlus

A World of Warcraft addon for enhanced group management and guild member organization.

![grouper](https://github.com/user-attachments/assets/f553b305-568a-417d-9977-a5d525fcb704) 

<img width="944" height="522" alt="image" src="https://github.com/user-attachments/assets/4cf55b62-c612-45bd-b399-248140734dc7" />


## Current Features

### Revolutionary Synchronization
- **Perfect Real-Time Sync** - All addon users see identical member lists and group assignments instantly - no more confusion about "who's in what group"
- **Never Lose Your Work** - Group setups are automatically saved and synced across your entire raid team as you create them
- **Professional Session Management** - Guild officers can control who can edit groups and lock assignments during events to prevent chaos
- **Seamless Cross-Realm Support** - Works flawlessly with players from any realm - automatically handles name normalization and prevents duplicates

### Intelligent Group Formation
- **Instant Balanced Groups** - Create perfectly balanced Mythic+ teams (1T/1H/3D) in seconds instead of spending minutes organizing manually
- **Smart Skill Matching** - Groups are automatically balanced by RaiderIO scores so everyone has a fair chance at success
- **Optimal Utility Coverage** - Auto-formation ensures each group has combat resurrection, bloodlust, and critical raid buffs
- **Visual Buff Indicators** - See at a glance which groups are missing important abilities with color-coded warnings

### Easy to Use
- **Drag & Drop Simplicity** - Move players between groups with simple drag and drop - changes sync instantly to everyone
- **RaiderIO Integration** - See each player's Mythic+ experience and current season rating right in the interface
- **Clean Visual Design** - Class colors, role icons, and intuitive layout make everything clear at a glance

### What This Means for Your Guild
- **End Sync Chaos** - No more "wait, who's in my group?" or conflicting group assignments during raid night
- **Professional Raid Management** - Officers get the control they need while members can still collaborate on group formation
- **Cross-Realm Events Made Easy** - Organize multi-guild events without worrying about realm-specific issues
- **Time Savings** - What used to take 15+ minutes of coordination now happens in under a minute
- **Higher Success Rates** - Balanced groups with optimal utility coverage lead to smoother runs and better outcomes
- **Stress-Free Organization** - Let the addon handle the complexity while you focus on leading your team

### Commands
- `/grouper form` - Auto-form balanced groups with utility distribution
- `/grouper toggle` - Show/hide main window
- `/grouper config` - Open addon settings
- `/grouper minimap` - Show/hide minimap icon
- `/grouper help` - Show command help
- `/grouperopt` - Quick access to options panel

### Visual Buff Indicators
Each group header displays buff availability with clear color coding:
- **Priority 1 (Critical)**: Combat Rez, Bloodlust/Heroism - Red when missing
- **Priority 2 (Important)**: Intellect, Stamina, Attack Power, Versatility, Skyfury - Yellow when missing  
- **Priority 3 (Helpful)**: Mystic Touch, Chaos Brand - Gray when missing
- All buffs turn green when present in the group

### Enterprise-Grade Reliability
- **Perfect Synchronization** - Built on professional-grade communication systems that never lose data
- **Automatic Conflict Resolution** - Smart systems prevent sync conflicts when multiple people edit groups
- **Cross-Realm Compatibility** - Seamlessly handles players from different realms without name conflicts
- **Instant Updates** - See changes the moment they happen with lightning-fast event-driven updates

## How to Use

### Quick Start
1. **Open the main window**: Click the minimap icon or use `/grouper toggle`
2. **Auto-form groups**: Use `/grouper form` to instantly create balanced teams
3. **Make adjustments**: Drag and drop players between groups - changes sync to everyone instantly

### Advanced Features
1. **Session Management**: Guild officers can lock group editing during events to prevent unwanted changes
2. **Cross-Realm Events**: Add players from any realm - names are automatically normalized to prevent conflicts  
3. **Real-Time Coordination**: All addon users see identical group assignments as you make changes
4. **Buff Optimization**: Group headers show which abilities are missing with color-coded indicators:
   - **Red** = Missing critical buffs (combat rez, bloodlust)
   - **Yellow** = Missing important buffs (stats, damage amplification) 
   - **Green** = Buff is present in the group

### Pro Tips
- Use auto-formation first, then make manual adjustments as needed
- RaiderIO scores help you balance group difficulty levels
- Lock sessions during raid nights to prevent accidental changes

## Installation

### Option 1: CurseForge (Recommended)
1. Visit the [GrouperPlus CurseForge page](https://www.curseforge.com/wow/addons/grouperplus)
2. Click "Install" to use with the CurseForge app, or download manually
3. The addon will automatically appear on your minimap after installation

### Option 2: Download from GitHub
1. Go to the [Releases page](https://github.com/whatisboom/GrouperPlus/releases)
2. Download the latest release archive
3. Extract the `GrouperPlus` folder to your `World of Warcraft/_retail_/Interface/AddOns/` directory
4. Restart World of Warcraft or type `/reload` in-game
5. The addon will automatically appear on your minimap

### Option 3: Clone Repository (Development)
1. Clone this repository: `git clone https://github.com/whatisboom/GrouperPlus.git`
2. Place the `GrouperPlus` folder in your `World of Warcraft/_retail_/Interface/AddOns/` directory
3. Restart World of Warcraft or type `/reload` in-game
4. The addon will automatically appear on your minimap

## Planned Features

See [TODO.md](TODO.md) for the complete list of planned features and development roadmap.

## Contributing

### Reporting Issues

We welcome bug reports and feature requests! To ensure we can help you effectively, please use our GitHub issue templates:

1. **[Report a Bug](https://github.com/whatisboom/GrouperPlus/issues/new?template=bug_report.yml)** - For reporting issues, errors, or unexpected behavior
2. **[Request a Feature](https://github.com/whatisboom/GrouperPlus/issues/new?template=feature_request.yml)** - For suggesting new features or improvements

### Issue Guidelines

When reporting issues:
- Search existing issues first to avoid duplicates
- Include your WoW version, addon version, and any error messages
- Provide clear reproduction steps
- Test with other addons disabled when possible

Your feedback helps make GrouperPlus better for everyone!

### Opening a Pull Request

We welcome contributions! When opening a pull request:
- Fork the repository and create a new branch for your changes
- Follow the existing code style and conventions
- Add debug logging for new features (INFO level for user actions, DEBUG for details)
- Test your changes thoroughly in-game
- Fill out the pull request template completely
- Ensure your changes don't break existing functionality
- Check for Lua errors using BugSack/BugGrabber or similar addons

Our pull request template will guide you through providing all necessary information.