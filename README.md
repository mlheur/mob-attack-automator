# Mob Attack Automator

A mod for Fantasy Grounds that will automate multiple NPC attack rolls against a single target.  Useful for mobs of critters, or squads of archers; instead of using some kind of statistical indexing as suggested elsewhere.


## Installation

 - Download the latest version
```
 cd <fantasy_grounds_data_dir>/extensions
 git clone https://github.com/mlheur/mob-attack-automator
```
 - Enable the extension "mob-attack-automator" when creating or loading a campaign.

## Features

- Designed to speed up implementation of the attack action for groups of creatures, honouring the PHB 189 statement about initiative: `The DM makes one roll for an entire group of identical creatures, so each member of the group acts at
the same time.`

  - Intended Use
    - When combat initiative activates a group of identical creatures, the DM selects one Combat Tracker target for each member of the mob.
      - The entire mob may target a single victim, or
      - groups of mobbers can band together and rough up a few targets.
    - Open the Mob Attack Automator window
    - Review the selected target and quantity of attackers
    - Cycle through the available Attack action, drawn from the NPC record of the Active combatant
    - Review the attack bonus associated with the selected action
    - Click the [Mob Attack!!!] button, the button will be inactive until all rolls are complete, the button will now activate the next combatant in the initiative order
    - If applicable, the Mob Attack Automator will be ready for immediate reuse by the next group of identical creatures that share a common intiative and target

- Developed and tested for 5E ruleset, leveraging CoreRPG managers e.g. CombatManager, ActionManager, ActionAttack and ActionDamage for maximum compatibility
- Keeps all information in memory, nothing saved in db.xml
- Only stays resident while the Mob Attack Automator window is open, game hooks are unregistered after window closure and completion of all rolls
- Uses built-in Effects to skip the turn of creatures that have participated in a mob attack
- Uses each creature's individual attack action, only against the originally selected target; performs that creature's damage action for [HIT] and [CRITICAL HIT] results; applies all game effects and modifiers that are handled by aforementioned game-data managers.
- When the Mob Attack Automator window is open, it will shows instructions until the Combat Tracker has an appropriate Active combatant that is targetting a single creature
- Watches for changes in the game state and updates itself only when appropriate, offers conventient refresh buttons to be sure the displayed content is correct.
- Intuitively handles subsets of NPCs within an Initiative group to collectively target a few different victims; each subset will get its own turn.
- Applies the desktop modifier buttons for ADV/DIS on every attack roll; also applies the +/- 2 and 5 modifiers to both attack and damage rolls so those should be applied with great caution.
- Provides visual feedback to all players when Mob Attack Automator is activating multiple NPCs
  - Clients that connect after Mob Attack Automator has activated the mobbers' tokens, those clients will only see the active mobbers when the server refreshes the Mob Attack Automator window.


## Screenshot
![](NonModData/FirstMockup.png)