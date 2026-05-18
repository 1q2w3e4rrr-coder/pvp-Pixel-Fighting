# Run this from the Godot project root: bvn-godot
# It removes raw SWF-exported effect wav/mp3 files that can trigger
# Godot 4.6 FileAccessMemory "p_position > length" import errors.

$ErrorActionPreference = "Continue"

$effectDir = Join-Path $PSScriptRoot "assets\sfx\effect"
if (Test-Path $effectDir) {
    Get-ChildItem $effectDir -File -Include *.wav,*.mp3,*.import -Recurse | Remove-Item -Force
}

$importedDir = Join-Path $PSScriptRoot ".godot\imported"
if (Test-Path $importedDir) {
    Get-ChildItem $importedDir -File | Where-Object {
        $_.Name -like "snd_*" -or $_.Name -like "*.wav-*" -or $_.Name -like "*.mp3-*"
    } | Remove-Item -Force
}

Write-Host "BVN fix done: raw effect wav/mp3 imports removed. Reopen Godot and let it import the .ogg files."
