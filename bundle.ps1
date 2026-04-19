# Source - https://stackoverflow.com/a
# Posted by Roman Kuzmin, modified by community. See post 'Timeline' for change history
# Retrieved 2025-11-06, License - CC BY-SA 2.5

function Write-ColorOutput($ForegroundColor)
{
    # save the current color
    $fc = $host.UI.RawUI.ForegroundColor

    # set the new color
    $host.UI.RawUI.ForegroundColor = $ForegroundColor

    # output
    if ($args) {
        Write-Output $args
    }
    else {
        $input | Write-Output
    }

    # restore the original color
    $host.UI.RawUI.ForegroundColor = $fc
}

# This script bundles the Lua files for the project into a single file.

# Ensure luabundler is installed: npm install -g luabundler

# Find and print TODO comments
Write-ColorOutput yellow "Searching for TODO comments..."
Get-ChildItem -Path src -Recurse -Filter *.lua | ForEach-Object {
    $file = $_
    Select-String -Path $file.FullName -Pattern '--.*TODO' | ForEach-Object {
        $line = $_.Line
        Write-ColorOutput yellow "TODO found in $($file.FullName) on line $($_.LineNumber): $line"
    }
}

# Define search paths
$searchPaths = "?.lua"

# Define entry files
$entryFiles = @(
    "src/core/main.lua",
    "src/modules/npc_commander.lua"
    "src/modules/player_injector.lua"
    "src/modules/clever_notecard.lua",
    "src/modules/monster_ui.lua"
)

Write-ColorOutput green "Bundling files..."

foreach ($entryFile in $entryFiles) {
    $outputFile = "dist/" + [System.IO.Path]::GetFileNameWithoutExtension($entryFile) + ".bundle.lua"
    luabundler bundle $entryFile -o $outputFile -p $searchPaths
    Write-ColorOutput green "Bundling complete. Output file: $outputFile"
}
