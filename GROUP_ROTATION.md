# Group Rotation System Implementation Plan

## Overview
Implement a rotation system that tracks player pairings and actively discourages repeated group formations, encouraging players to interact with different guild members over time.

## Phase 1: Data Structure & Tracking (modules/GroupRotation.lua)

**Create rotation tracking system:**
- **Pairing History**: Track every player pair that has been in a group together with timestamps
- **Rotation Scores**: Calculate "rotation scores" between players based on frequency and recency of groupings
- **Database Integration**: Add rotation data to saved variables with automatic cleanup of old data

**Key Features:**
- Track pairings across all group formations (not just successful runs)
- Weight recent pairings more heavily than older ones
- Automatic cleanup of pairing data older than X weeks (configurable)
- Guild-specific tracking (different guilds maintain separate rotation histories)

## Phase 2: Rotation Algorithm Integration

**Modify AutoFormation.lua:**
- Add rotation scoring to the existing group formation algorithm
- **New sorting criteria**: After RaiderIO score, apply rotation penalties to discourage repeated pairings
- **Balancing logic**: Maintain role composition and utility coverage while maximizing player diversity

**Algorithm Enhancement:**
1. Calculate base groups using existing logic (role balance + RaiderIO scores)
2. Apply rotation penalties: increase "cost" of putting frequently-paired players together
3. Use iterative swapping (similar to utility optimization) to improve rotation diversity
4. Ensure rotation never overrides critical factors (role requirements, massive skill gaps)

## Phase 3: User Interface & Controls

**Settings Integration:**
- Add rotation options to the existing options panel
- **Rotation Weight**: Slider to control how heavily rotation factors into group formation (0-100%)
- **History Duration**: How many weeks of pairing history to consider
- **Reset Options**: Clear rotation history, reset for new season/expansion

**Visual Feedback:**
- Show "freshness" indicators in the main frame (green = haven't played together recently, yellow = played together a few times, red = frequently paired)
- Tooltip information showing last time players were grouped together
- Optional chat notifications when groups are intentionally mixed for rotation

## Phase 4: Smart Features & Polish

**Intelligent Rotation Logic:**
- **Friend Preference**: Allow players to mark "preferred partners" who won't be rotated away
- **Role Scarcity Handling**: When there's only 1 tank/healer, don't penalize their repeated use
- **New Player Integration**: Automatically prioritize pairing new guild members with different people
- **Seasonal Reset**: Automatically clear rotation history at expansion/major patch releases

**Performance Optimization:**
- Efficient data structures to handle large guild rosters
- Batch processing for rotation calculations
- Memory management for rotation history

## Implementation Benefits

**For Guild Leaders:**
- Encourages guild cohesion and prevents cliques
- Helps new members integrate with existing groups
- Reduces politics around "favorite groups"

**For Players:**
- Discover compatible players they might not normally group with
- Learn different playstyles and strategies
- Build broader social connections within the guild

**Technical Integration:**
- Builds on existing auto-formation architecture
- Uses established utilities for role detection and scoring
- Integrates with saved variables system
- Maintains performance through optimized algorithms

## Configuration Options

**Rotation Intensity Levels:**
- **Off**: No rotation tracking (current behavior)
- **Light**: Minor preference for mixing, easily overridden by skill/role needs
- **Medium**: Balanced approach - mix players but respect skill gaps
- **High**: Aggressive mixing, only overridden by role requirements
- **Maximum**: Force maximum diversity (for guild events focused on mixing)

## Safeguards & Fallbacks

**Prevent Poor Groups:**
- Never sacrifice role composition for rotation
- Maintain minimum skill thresholds (configurable RaiderIO gaps)
- Override rotation for critical progression content
- Fallback to standard formation if rotation creates invalid groups

## Data Structure Design

### Pairing History Table
```lua
rotationHistory = {
    ["Player1-Player2"] = {
        count = 5,              -- Number of times grouped together
        lastGrouped = timestamp, -- Last time they were in a group
        avgPerformance = 0.85,  -- Optional: track success rate
    }
}
```

### Player Rotation Profile
```lua
playerRotationData = {
    ["PlayerName"] = {
        recentPartners = {},      -- List of recent partners (last N groups)
        preferredPartners = {},   -- Players they want to play with
        avoidList = {},          -- Players to avoid grouping with
        rotationScore = 0,       -- Overall rotation health score
        lastRotated = timestamp  -- Last time they were in a mixed group
    }
}
```

### Rotation Scoring Algorithm
```
RotationScore = BaseScore 
    - (FrequencyPenalty * TimesGrouped)
    - (RecencyBonus * DaysSinceLastGrouped)
    + (DiversityBonus * UniquePartnersCount)
    + (NewPlayerBonus * IsNewGuildMember)
```

## Implementation Priority

1. **Core Tracking System** - Track who groups with whom
2. **Basic Rotation Logic** - Simple mixing based on history
3. **UI Integration** - Settings and visual feedback
4. **Advanced Features** - Preferences, smart handling, optimization
5. **Polish & Testing** - Performance tuning, edge cases

This system would transform GrouperPlus from a pure optimization tool into a community-building platform while maintaining all existing functionality and performance.