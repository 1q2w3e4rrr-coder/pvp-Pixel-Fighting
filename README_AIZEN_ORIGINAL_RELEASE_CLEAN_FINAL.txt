BVN Aizen original-release clean final patch

This patch keeps the previously integrated Aizen SWF/XFL-based battle and UI systems, and removes normal-play debug controls that do not exist in the original game.

Original-behavior cleanup:
1. O key remains ignored as requested; assist/swap is not implemented.
2. H hitbox debug toggle is disabled in normal play.
3. T debug full-qi/full-energy key is disabled in normal play.
4. P debug P2 attack key is disabled in normal play.
5. Original attack/hurt rectangles are still kept internally for hit detection, but their colored debug display is hidden by default.
6. No new placeholder UI/effect assets are added in this patch.

If exact pixel-level UI animation restoration is continued after this patch, the next required source-derived step is to export real PNG sequences from the original fight.swf/fight.xfl for qbar_mc, qbar_fzqi_mc, energybar_barmc, hpbar_barmc, hits_mc, score_mc, and time_mc. Do not replace them with generated placeholders.
