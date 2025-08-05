# GrouperPlus

A World of Warcraft addon for enhanced group management and guild member organization.

![grouper](https://github.com/user-attachments/assets/f553b305-568a-417d-9977-a5d525fcb704) 
<img width="931" height="510" alt="image" src="https://github.com/user-attachments/assets/54ec0c71-a3a9-46a9-ad0b-6f7c50740da7" />

## Current Features

### Key Features
- **Instant Group Creation** - Automatically create balanced Mythic+ groups in seconds instead of spending minutes forming teams manually
- **Smart Role Balancing** - Never worry about group composition again - always get the perfect 1 tank, 1 healer, 3 DPS setup
- **Skill-Based Matching** - Groups are balanced by player experience and ratings so everyone has a fair chance at success
- **See Player Strength at a Glance** - RaiderIO scores displayed right in the interface so you know each player's Mythic+ experience
- **Drag & Drop Flexibility** - Easy reorganization when you want to make manual adjustments to the automated groups
- **Guild-Wide Coordination** - Share group setups instantly with other guild members who have the addon

### How It Helps You
- **Save Time on Group Formation** - What used to take 10+ minutes of manual organization now happens instantly
- **Reduce Group Formation Stress** - No more guessing at player skill levels or trying to remember who plays what role
- **Improve Success Rates** - Balanced groups based on actual player experience lead to better dungeon runs
- **Easy Adjustments** - Simple drag-and-drop when you want to swap players between groups or make changes
- **Never Lose Track of Players** - Clear visual organization prevents accidentally putting the same player in multiple groups
- **Consistent Group Structure** - Every group follows the optimal dungeon composition automatically

### Simple to Use
- **Clean, Intuitive Interface** - Everything you need is visible at a glance with no clutter
- **Only Shows Relevant Players** - Automatically filters to online, max-level guild members ready for content
- **Recognizable Class Colors** - Instantly identify each player's class with familiar WoW color coding
- **Remembers Your Preferences** - Window size and position stay exactly how you left them
- **Works Anywhere** - Drag the window wherever it's most convenient on your screen

### Commands
- `/grouper` - Show available commands
- `/grouper main` or `/grouper toggle` - Open/close the main group management window
- `/grouper show` or `/grouper minimap` - Show minimap icon
- `/grouper hide` - Hide minimap icon
- `/grouper auto` or `/grouper autoform` - Automatically form balanced groups based on player roles and ratings
- `/grouper comm` - Check connected GrouperPlus users in guild
- `/grouper broadcast` - Send version check to other addon users
- `/grouper share` - Share RaiderIO data with guild members
- `/grouper role` - Force share current player role with guild
- `/grouper test` - Test RaiderIO integration functionality
- `/grouperopt` or `/grouperptions` - Open options panel

### Reliability & Support
- **Built-in Troubleshooting** - Comprehensive logging helps identify and resolve any issues quickly
- **Works with Guild Members** - Share your group setups with other guild members who have the addon installed
- **Automatic Updates** - Player roles and specs are detected automatically, even when they change characters

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

