BVN Aizen v18 restore HP UI + qbar facemc gradient front fix

Base:
- Based on bvn_aizen_v18_qibar_color_order_swf_logic_fix.zip, not the stale qibar_facemc patch.

Fix:
1. Restores the correct top HP UI logic from the previous working version:
   - original green HP bar resource / layering
   - white HP number style and position
   - time_mc top layer and center join slash logic
   - SPIRITUAL matrix-based placement
2. Adds the qbar_facemc gradient front frame without reverting HP UI:
   - qibar_face_front.png remains visible as the qbar_facemc front layer
   - does not generate or add new images
   - uses existing assets/ui/fight/qibar_face_front.png

Modified file:
- scripts/ui/FightHud.gd
