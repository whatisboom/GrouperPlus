# GrouperPlus

A World of Warcraft addon for enhanced group management and guild member organization.

![grouper](https://github.com/user-attachments/assets/f553b305-568a-417d-9977-a5d525fcb704) 
<img width="931" height="510" alt="image" src="https://github.com/user-attachments/assets/54ec0c71-a3a9-46a9-ad0b-6f7c50740da7" />

## Current Features

### Core Functionality
- **Guild Member Display** - Shows online max-level guild members in an organized interface
- **Dynamic Group Management** - Create and manage multiple groups of up to 5 members each
- **Drag & Drop Interface** - Seamlessly move members between groups or from the member list to groups
- **RaiderIO Integration** - Displays Mythic+ scores for guild members when available
- **Settings Panel** - Integrated with WoW's interface options (ESC → Options → AddOns → GrouperPlus)

### Group Management
- **Multiple Dynamic Groups** - Automatically creates empty groups as needed
- **Inter-Group Transfers** - Drag members between different groups to reorganize teams
- **Member Tracking** - Smart tracking prevents members from appearing in multiple locations
- **Visual Feedback** - Hover highlighting and drag indicators for intuitive interaction
- **Group Removal** - Remove members from groups to return them to the available member list

### User Interface
- **Main Frame** - Resizable and movable window for guild member management
- **Dual-Panel Layout** - Member list on the left, dynamic groups on the right
- **Member Filtering** - Automatically filters to show only online, max-level characters
- **Class Color Coding** - Guild members displayed with appropriate class colors
- **Persistent Settings** - Window size and position saved between sessions

### Commands
- `/grouper` - Show available commands
- `/grouper main` or `/grouper toggle` - Open/close the main group management window
- `/grouper show` or `/grouper minimap` - Show minimap icon
- `/grouper hide` - Hide minimap icon
- `/grouperopt` or `/grouperptions` - Open options panel

### Technical Features
- **Debug System** - Built-in troubleshooting tools to help diagnose issues

## How to Use

### Getting Started
1. **Open the main window**: Click the minimap icon or use `/grouper main`
2. **View guild members**: Online max-level guild members appear in the left panel
3. **Create groups**: Empty groups are automatically created as needed

### Managing Groups
1. **Add to groups**: Drag members from the left panel to any empty group slot
2. **Move between groups**: Drag any member from one group to an empty slot in another group
3. **Remove from groups**: Click the red minus button next to any group member
4. **Reorganize**: Freely drag and drop members to optimize group composition

### Tips
- Members show their class colors and RaiderIO scores (when available)
- Groups automatically resize and reposition based on window size
- All changes are automatically saved and persist between sessions

## Installation

### Option 1: Download Release (Recommended)
1. Go to the [Releases page](https://github.com/whatisboom/GrouperPlus/releases)
2. Download the latest release archive
3. Extract the `GrouperPlus` folder to your `World of Warcraft/_retail_/Interface/AddOns/` directory
4. Restart World of Warcraft or type `/reload` in-game
5. The addon will automatically appear on your minimap

### Option 2: Clone Repository (Development)
1. Clone this repository: `git clone https://github.com/whatisboom/GrouperPlus.git`
2. Place the `GrouperPlus` folder in your `World of Warcraft/_retail_/Interface/AddOns/` directory
3. Restart World of Warcraft or type `/reload` in-game
4. The addon will automatically appear on your minimap

## Planned Features

See [TODO.md](TODO.md) for the complete list of planned features and development roadmap.

## Requirements

- World of Warcraft (Retail)
- Interface version 110107 or higher

