Fix for Godot error:
core/io/file_access_memory.cpp:101 - Condition "p_position > length" is true.

Cause:
The previous patch added raw SWF-exported effect wav/mp3 files under assets/sfx/effect.
Some Godot 4.6 builds import those small/old SWF audio streams incorrectly.

How to apply:
1. Close Godot.
2. Extract this patch into the bvn-godot project root.
3. In PowerShell, run:
   cd "D:\学习文件\大三下\软件工程实践\BVN_Godot\bvn-godot"
   powershell -ExecutionPolicy Bypass -File .\FIX_delete_raw_effect_audio.ps1
4. Reopen Godot.

This keeps original SWF sound ids in the logic, but uses re-encoded .ogg files for Godot playback.
