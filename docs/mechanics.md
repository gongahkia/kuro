# Legacy Mechanic Reference

Kuro originally shipped as a terminal survival roguelike. The implementation is gone, but the design intent carried into the Love2D rewrite is:

- The game is about surviving pressure, not clearing rooms.
- Darkness is an active system that limits vision and creates tension.
- Runs are seeded and deterministic.
- A run spans three floors with increasing difficulty.
- Floors one and two require recovering every torch before the exit unlocks.
- Floor three replaces the exit with a boss ritual: carry fire to anchors while surviving Umbra.
- Shrines heal the player and restore light stability.
- Encounter rooms trigger one-shot hostile or beneficial events.
- Enemy roles are asymmetric:
  - Stalkers pressure from pursuit.
  - Rushers punish straight lines and distance mistakes.
  - Sentries alarm nearby threats.
  - Leeches dim the player's light.
  - Umbra controls space with summons and hazards.
- The new version keeps those beats but translates them into a real-time first-person game with light as the primary weapon.
- Sprint mode now treats those same systems as route-mastery surfaces instead of side content:
  - official packs use curated seeds and authored shortcuts
  - time saves come from minimum-torch routing, dark sanity dives, flare checkpoints, Burn Dash gates, and pillar-route choices
  - official boss routing is soft deterministic: the authored line is fastest, but off-order clears still work
  - every official finish writes a replay plus paired text and JSON export locally
  - practice targets support both full-floor starts and focused drill starts on authored route nodes
