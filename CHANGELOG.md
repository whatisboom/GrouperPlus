# Changelog

All notable changes to GrouperPlus will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Major Features ✨
- **Intelligent Utility Distribution**: Auto-formation now optimizes group compositions for utility coverage
  - Critical utilities (Combat Rez, Bloodlust) are prioritized with heavy penalties for missing coverage
  - Important buffs (Intellect, Stamina, Attack Power, Versatility) receive moderate optimization  
  - Nice-to-have debuffs (Mystic Touch, Chaos Brand) provide small bonuses when present
  - Smart DPS swapping between groups maintains role balance while improving utility distribution
  - Iterative optimization continues until no beneficial swaps are found (max 10 iterations)

### Enhanced Auto-Formation 🎯
- **Two-Phase Algorithm**: Role balancing followed by utility optimization ensures both proper composition and buff coverage
- **Comprehensive Utility Tracking**: All 9 utility types mapped to their respective classes with priority-based scoring
- **Debug Logging**: Detailed logging shows optimization decisions and utility score improvements during auto-formation

### Documentation Updates 📚  
- **Updated README**: Enhanced feature descriptions to include utility distribution capabilities
- **Development Context**: Added utility system documentation to CLAUDE.md with technical implementation details
- **TODO Tracking**: Marked utility distribution as fully implemented in project roadmap

## [0.5.0] - 2025-08-05

### Added 🎯
- **GitHub Issue Templates**: Professional bug report and feature request templates for better community engagement
  - Structured bug report form with WoW version, reproduction steps, and error logging
  - Feature request form with priority levels and use case examples
  - Template chooser for easy issue creation

### Development Improvements 🛠️
- **Standardized Issue Tracking**: YAML-based forms ensure consistent, high-quality issue reports
- **Community Links**: Integrated Discord and CurseForge links in issue templates
- **Better Bug Reporting**: Comprehensive checklist and validation for issue submissions

## [0.4.1] - 2025-08-05

### Major Features ✨
- **RaiderIO Score-Based Visual Feedback**: Dynamic group members now display background colors based on their Mythic+ scores
- **Smart Color System**: Gray (0-500) → White (500-1000) → Green (1000-1500) → Blue (1500-2000) → Purple (2000-2500) → Orange (2500-3000+)
- **2-Column Group Layout**: Groups now display in a clean 2-per-row layout for better organization
- **Group Pruning**: "Clear Groups" now removes all empty groups, keeping interface clean

### Bug Fixes 🐛
- **Fixed Hover Colors**: Player background colors now persist correctly during hover interactions instead of reverting to gray

### Technical Improvements 🔧
- Added comprehensive Utilities module with color interpolation functions
- Added item quality color constants for consistent theming
- Centralized background color logic for better maintainability
- Enhanced group layout system with multi-row support

### Visual Polish 🎨
- Instant skill level recognition at a glance
- Cleaner, more organized group interface
- Consistent color theming throughout the addon
- Professional visual feedback system

## [0.4.0] - 2025-08-04

### Major Features Added
- **Automatic Group Formation**: Auto-form balanced groups based on Mythic+ ratings and role requirements
- **Smart Role Balancing**: Automatically ensures proper group composition (1 tank, 1 healer, 3 DPS)
- **Inter-Addon Communication System**: Share group formations and RaiderIO data between guild members with the addon
- **Role-Based Organization**: Groups automatically organize with tanks first, then healers, then DPS
- **Real-Time Role Detection**: Automatically detects and updates player roles when specializations change

### User Interface Improvements
- **Official WoW Role Icons**: Replaced text indicators [T], [H], [D] with official game role icons
- **RaiderIO Score Display**: Shows Mythic+ scores in both member lists and dynamic groups
- **Enhanced Drag & Drop**: Improved group management with better visual feedback
- **Dynamic Group Management**: Create and manage multiple groups of up to 5 members each

### Commands & Features
- `/grouper auto` or `/grouper autoform` - Automatically form balanced groups
- `/grouper comm` - Check connected GrouperPlus users in guild
- `/grouper broadcast` - Send version check to other addon users
- `/grouper share` - Share RaiderIO data with guild members
- `/grouper role` - Force share current player role with guild

### Technical Improvements
- **Guild-Wide Data Sharing**: Synchronize RaiderIO scores and role information across addon users
- **Comprehensive Debug System**: Multi-level logging (ERROR, WARN, INFO, DEBUG, TRACE)
- **Settings Integration**: Integrated with WoW's interface options panel
- **Performance Optimizations**: Efficient group formation algorithms and data caching

## [0.2.0] - 2025-01-31

### Major Features Added
- **Drag & Drop Group Management** - Seamlessly move guild members between groups with intuitive drag-and-drop interface
- **Dynamic Group Creation** - Groups automatically appear and organize as you add members
- **Inter-Group Transfers** - Move members between different groups to optimize team composition
- **RaiderIO Integration** - View Mythic+ scores directly in the guild member list
- **Enhanced Main Frame** - New resizable window with dual-panel layout for member management

### User Interface Improvements
- **Clean Interface Design** - Removed unnecessary borders and backgrounds for a modern look
- **Class Color Coding** - Guild members displayed with appropriate class colors for easy identification
- **Visual Feedback** - Hover highlighting and drag indicators for intuitive interaction
- **Improved Debug System** - Better troubleshooting tools with adjustable logging levels

### Commands & Settings
- **Multiple Slash Commands** - `/grouper main`, `/grouper toggle`, `/grouperopt` for different functions
- **Settings Integration** - Options panel accessible through WoW's interface settings
- **Persistent Configuration** - Window positions and settings saved between game sessions

### Technical Improvements
- **WoW 11.0.7 Compatibility** - Updated for The War Within expansion
- **Code Organization** - Extracted constants and improved code structure
- **Enhanced Documentation** - Comprehensive user guide and installation instructions

## [0.1.0] - Initial Release

### Added
- Basic addon structure
- Minimap icon with LibDBIcon
- AceDB integration for saved variables
- Basic slash commands