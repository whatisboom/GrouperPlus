# Group Synergy and Class Composition System

## Current State Analysis

GrouperPlus already has a sophisticated auto-formation system with:
- **Utility distribution system** - optimizes for critical abilities like Combat Rez, Bloodlust
- **Role balancing** - ensures 1 tank, 1 healer, 3 DPS per group
- **Score-based sorting** - uses RaiderIO scores for skill balancing
- **Keystone tracking** - detects player keystones but doesn't use them for formation

## Suggested Improvements for Class Composition & Synergies

### 1. Dungeon-Specific Optimization

Create class preference matrices for each dungeon based on:

#### High Interrupt Requirement Dungeons
- **Spires of Ascension**: Favor classes with multiple interrupts (DH, Warrior, Rogue)
- **Theater of Pain**: Prioritize ranged interrupts and dispels
- **Halls of Atonement**: Mobile classes with good interrupt uptime

#### Damage Profile Optimization
- **AoE-heavy dungeons** (Plaguefall, Mists): Favor Fire Mage, Havoc DH, Unholy DK
- **Single-target dungeons** (Sanguine Depths): Prioritize Assassination Rogue, Frost DK, Arcane Mage
- **Cleave-focused dungeons**: Enhancement Shaman, Arms Warrior, Outlaw Rogue

#### Mobility Requirements
- **High mobility dungeons** (Halls of Atonement, Mists): Favor mobile classes
- **Stationary burn phases**: Prefer classes with strong stationary DPS

#### Defensive Utility Needs
- **High damage dungeons**: Stack defensive utilities and immunities
- **Magic damage heavy**: Prioritize magic damage reduction
- **Physical damage heavy**: Favor armor and physical mitigation

### 2. Class Synergy System

#### DPS Synergies (Enhance existing utility system)
- **Chaos Brand synergy**: Demon Hunter + caster DPS (Mage, Warlock, Balance Druid)
- **Mystic Touch synergy**: Monk + physical DPS (Warrior, Rogue, Enhancement Shaman)
- **Physical debuff synergy**: Death Knight/Warrior debuffs + melee DPS
- **Magic debuff synergy**: Elemental Shaman/Mage + caster DPS

#### Defensive Synergies
- **Immunity stacking**: Multiple immunity classes for specific mechanics
- **Healing/damage reduction combinations**: 
  - Death Knight AMZ + Priest barrier
  - Warrior Rally + Shaman Spirit Walk
- **Crowd control combinations**: Multiple CC types for different situations

#### Utility Coverage Synergies
- **Movement abilities**: Death Grip, Ring of Peace, Typhoon for positioning
- **Group mobility**: Warlock gateway + movement abilities
- **Dispel coverage**: Magic and disease dispels across the team

### 3. Keystone-Aware Formation

#### Level-based Composition
- **Low keys (+2 to +7)**: More flexible, experimental compositions
- **Medium keys (+8 to +14)**: Balanced approach with good synergies
- **High keys (+15+)**: Favor meta, reliable class combinations

#### Dungeon-specific Preferences
- **Atal'Dazar**: Favor classes with good dinosaur handling (ranged, mobile)
- **Freehold**: Prioritize AoE and interrupt coverage
- **The MOTHERLODE!!**: Mobile classes for mining cart mechanics
- **Waycrest Manor**: Classes good at handling adds and positioning

#### Keystone Distribution Logic
- **Avoid duplicate keystones**: Ensure groups can actually run together
- **Level matching**: Group similar keystone levels when possible
- **Progression consideration**: Higher keystones get priority for best compositions

### 4. Advanced Scoring Algorithm

Extend the current utility scoring to include:

#### Class Meta Rankings
- **S-tier classes**: High bonus for current season's strongest performers
- **A-tier classes**: Moderate bonus for solid, reliable classes
- **B-tier classes**: Neutral scoring
- **C-tier classes**: Small penalty for underperforming classes

#### Dungeon-specific Class Performance Weights
- Each dungeon has multipliers for different classes based on performance data
- **Example**: Fire Mage gets +50 points in AoE-heavy dungeons, -25 in single-target

#### Synergy Bonuses
- **Perfect synergies**: +100 points (Chaos Brand + 2 casters)
- **Good synergies**: +50 points (Mystic Touch + 2 physical)
- **Minor synergies**: +25 points (complementary utilities)

#### Anti-synergy Penalties
- **Too many ranged**: -50 points if 3+ ranged DPS
- **Missing key interrupts**: -100 points if insufficient interrupt coverage
- **Damage type overlap**: -25 points for too much of same damage type

### 5. Flexible Group Templates

#### Meta Template
- Prioritize current season's strongest combinations
- Focus on proven, high-performance class synergies
- Ideal for players pushing high keys

#### Coverage Template
- Maximize utility and interrupt coverage
- Ensure all important abilities are represented
- Good for consistent, safe runs

#### Synergy Template
- Optimize for class damage and utility synergies
- Focus on maximizing class interactions
- Best for coordinated groups

#### Safe Template
- Reliable, proven combinations for high keys
- Conservative approach with minimal risk
- Prioritize survivability and consistency

## Implementation Phases

### Phase 1: Dungeon-Specific Data Framework
1. Create `DungeonData.lua` module with:
   - Dungeon-specific class preferences
   - Interrupt requirements per dungeon
   - Damage type preferences
   - Utility needs mapping

2. Integrate with existing keystone system:
   - Map keystone mapIDs to dungeon data
   - Add dungeon context to formation decisions

### Phase 2: Enhanced Synergy System
1. Extend `AutoFormation.lua` utility system:
   - Add damage synergy tracking
   - Implement class combination scoring
   - Create anti-synergy detection

2. Enhance `CLASS_UTILITIES` and `UTILITY_INFO`:
   - Add damage type classifications
   - Include synergy relationship data
   - Expand utility priority system

### Phase 3: Smart Keystone Integration
1. Modify `CreateBalancedGroups` function:
   - Consider available keystones in formation
   - Implement dungeon-specific optimization
   - Add keystone level scaling

2. Enhance keystone data structure:
   - Add dungeon preference metadata
   - Include optimal class recommendations
   - Track keystone difficulty scaling

### Phase 4: Advanced Scoring Algorithm
1. Create weighted scoring system:
   - Combine utility coverage, class synergies, dungeon optimization
   - Maintain existing RaiderIO score integration
   - Add configurable weight preferences

2. Enhance `OptimizeGroupUtilities`:
   - Include new synergy scoring
   - Add template-based optimization
   - Implement smart swapping logic

### Phase 5: UI Integration
1. Add formation strategy selector to MainFrame:
   - Template selection dropdown
   - Real-time synergy indicators
   - Dungeon optimization display

2. Enhance group display:
   - Show synergy information in tooltips
   - Display dungeon optimization indicators
   - Add formation quality metrics

## Configuration Options

### User Preferences
- **Formation Strategy**: Meta/Coverage/Synergy/Safe templates
- **Synergy Weight**: How much to prioritize class synergies vs raw score
- **Dungeon Optimization**: Enable/disable dungeon-specific preferences
- **Meta Following**: How closely to follow current season meta

### Advanced Settings
- **Custom Class Weights**: Allow users to set personal class preferences
- **Synergy Overrides**: Manual synergy bonus/penalty adjustments
- **Keystone Preferences**: Priority for certain dungeons or levels
- **Risk Tolerance**: Conservative vs experimental composition choices

## Data Sources and Updates

### Static Data
- Class utility mappings (already implemented)
- Base synergy relationships
- Dungeon mechanical requirements

### Dynamic Data Integration
- Current season meta rankings (could integrate with community data)
- Personal performance tracking
- Group success rate statistics
- Keystone timing data

### Community Integration
- Optional integration with ranking websites
- Guild-specific performance data
- Personal historical success rates
- Seasonal meta updates

## Benefits for Players

### Immediate Benefits
- **Better group success rates**: Optimized compositions perform better
- **Reduced friction**: Auto-formation considers group viability
- **Educational value**: Shows why certain combinations work
- **Flexibility**: Multiple templates for different goals

### Long-term Benefits
- **Improved player understanding**: Learn optimal class combinations
- **Better guild coordination**: More strategic group planning
- **Higher key success rates**: Better compositions lead to better outcomes
- **Community building**: Shared understanding of effective strategies

## Technical Considerations

### Performance
- Pre-calculate dungeon preferences to avoid runtime computation
- Cache synergy calculations for repeated evaluations
- Optimize the group formation algorithm for large guild rosters

### Compatibility
- Maintain backward compatibility with existing formation system
- Ensure graceful degradation when keystone data unavailable
- Support for players without RaiderIO scores

### Extensibility
- Modular design for easy addition of new synergies
- Configurable weights for future meta changes
- Plugin system for custom composition strategies

This enhancement builds upon GrouperPlus's existing sophisticated utility system while adding the strategic depth that competitive M+ requires, making it an invaluable tool for guild group coordination and optimization.