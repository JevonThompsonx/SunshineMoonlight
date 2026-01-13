# Sunshine Game Mass-Add Script

Automatically scan your PC for games and add them all to Sunshine for Moonlight streaming. Includes Steam library detection, cover art finding, and duplicate prevention.

## Features

- ✅ **Mass game detection** - Scans multiple drives automatically
- ✅ **Steam library support** - Parses Steam manifests for proper game names
- ✅ **Duplicate detection** - Won't re-add games you already have
- ✅ **Cover art detection** - Finds existing images in game folders
- ✅ **Smart filtering** - Ignores installers, launchers, and non-game folders
- ✅ **UTF-8 safe** - Handles special characters in game names
- ✅ **Automatic backups** - Creates timestamped backups before changes

## Requirements

- Windows with PowerShell 5.1 or higher
- Sunshine installed at default location (`C:\Program Files\Sunshine`)
- Administrator privileges (required to modify Sunshine config)

## Quick Start

### 1. Download the Script

Save `Add-SunshineGames.ps1` to a location like `C:\Scripts\`

### 2. Configure Your Game Paths

Edit the script and update the `$gamePaths` array with your game locations:
```powershell
$gamePaths = @(
    "C:\Games",
    "D:\",
    "E:\SteamLibrary",
    "F:\",
    "F:\SteamLibrary"
)
```

### 3. Run the Script

Open PowerShell **as Administrator**:
```powershell
# Navigate to script location
cd C:\Scripts

# Allow script execution (first time only)
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process

# Run the script
.\Add-SunshineGames.ps1
```

### 4. Refresh Moonlight Client

**Important:** Moonlight caches the app list!

**To see your new games:**
1. Open Moonlight on your client device
2. **Remove** your Sunshine host (long-press/right-click → Delete)
3. **Re-add** the host (should auto-discover, or manually add IP)
4. Pair if needed
5. Games should now appear!

**Alternative:** Some Moonlight versions have a "Refresh" button in the app list.

## What Gets Added?

### ✅ Included
- Standalone game executables (.exe files)
- Steam library games (properly named)
- Games with or without cover art

### ❌ Excluded
- System folders (WindowsApps, Program Files, etc.)
- Emulator directories (Switch, Wii U, 2DS, etc.)
- Installers and launchers (setup.exe, uninstaller.exe, etc.)
- Utilities (config.exe, updater.exe, etc.)
- Anti-cheat software (EAC, BattleEye, etc.)

## Configuration Options

### Custom Exclusions

Add folders to skip:
```powershell
$excludeDirs = @(
    "WindowsApps", "_CommonRedist", "Program Files",
    "YourCustomFolderToSkip"  # Add your own here
)
```

### Custom Executable Patterns

Exclude specific exe name patterns:
```powershell
$excludeExePatterns = @(
    "unins", "setup", "launcher",
    "mycustompattern"  # Add your own here
)
```

### Sunshine Config Location

If Sunshine is installed elsewhere:
```powershell
$sunshineConfigPath = "D:\Custom\Path\Sunshine\config\apps.json"
```

## Cover Art (Bonus Script)

### Auto-Download Cover Art with SteamGridDB

1. **Get API Key**
   - Sign up at https://www.steamgriddb.com
   - Go to Profile → Preferences → API
   - Generate a free API key

2. **Run the Cover Art Script**

Save `Download-GameCoverArt.ps1` and run:
```powershell
.\Download-GameCoverArt.ps1
```

The script will:
- Search SteamGridDB for each game without cover art
- Download the best matching cover image
- Update Sunshine config with image paths
- Store images in `C:\Program Files\Sunshine\config\covers`

### Manual Cover Art

You can also manually add images:

1. Place image files (PNG, JPG) in your game folders
2. Name them: `cover.png`, `poster.jpg`, `banner.png`, etc.
3. Re-run the main script - it will find them automatically

## Troubleshooting

### "Execution Policy" Error
```powershell
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
```

Then re-run the script.

### Games Not Showing in Moonlight

**Most common cause:** Moonlight caches the app list!

**Solution:**
1. **Remove** the host from Moonlight completely
2. **Re-add** the host
3. Reconnect

### "Could not find a part of the path" Error

The script is trying to write to a location that doesn't exist.

**Solution:** The latest version creates the directory automatically. Make sure you're running as Administrator.

### UTF-8 / Special Character Errors

If you see errors like `ill-formed UTF-8 byte`, a game has special characters causing issues.

**Check Sunshine logs:**
```powershell
Get-Content "C:\Program Files\Sunshine\config\sunshine.log" -Tail 50
```

**Solution:** The script now uses UTF-8 encoding by default. If issues persist, manually remove the problematic game from `apps.json`.

### Games Added But Still Not Visible

**Verify games are in the config:**
```powershell
$config = Get-Content "C:\Program Files\Sunshine\config\apps.json" -Raw | ConvertFrom-Json
$config.apps.Count  # Should show total number of apps
$config.apps | Select-Object -First 10 name  # Show first 10 games
```

**Restart Sunshine service:**
```powershell
Restart-Service -Name "SunshineService" -Force
```

### Connecting via Tailscale/VPN

If you access Sunshine over Tailscale or VPN:
- Make sure you're editing the config on the **actual Sunshine host**
- Verify the web UI shows games at `https://YOUR_TAILSCALE_IP:47990`
- Refresh Moonlight client as described above

## File Locations

| Item | Location |
|------|----------|
| Sunshine Config | `C:\Program Files\Sunshine\config\apps.json` |
| Sunshine Logs | `C:\Program Files\Sunshine\config\sunshine.log` |
| Config Backups | `C:\Program Files\Sunshine\config\apps.json.backup_TIMESTAMP` |
| Downloaded Covers | `C:\Program Files\Sunshine\config\covers\` |

## Script Output Example
```
========================================
  Sunshine Game Mass-Add Script
========================================

✓ Backup created: apps.json.backup_20260112_180000
✓ Found 23 existing games in Sunshine config

📁 Scanning: C:\Games
  ✓ Found: Eden-Windows
  ✓ Found: Horizon - Zero Down CE
  ⊘ Skipped (duplicate): Split Fiction

📁 Scanning: D:\
  ✓ Found: Cyberpunk 2077 🖼️
  ✓ Found: God of War Ragnarok 🖼️
  ...

📁 Scanning: F:\SteamLibrary
  ✓ Steam: Overwatch
  ✓ Steam: NARUTO SHIPPUDEN Ultimate Ninja STORM 4

✓ Configuration saved successfully

========================================
📊 SUMMARY
========================================
✓ Added: 89 new games
⊘ Skipped: 14 duplicates
📁 Total in Sunshine: 112 games
💾 Config: C:\Program Files\Sunshine\config\apps.json
========================================

🖼️  Found images for 23/89 games

⚠️  NEXT STEPS:
1. Restart Sunshine service (option below)
2. In Moonlight: Remove and re-add your host to refresh app list
3. Optionally: Add custom cover art (see script comments)

Restart Sunshine service now? (Y/N):
```

## Advanced Usage

### Run Without Prompts
```powershell
.\Add-SunshineGames.ps1
# Answer 'N' to service restart prompt, or modify script to auto-restart
```

### Schedule Automatic Updates

Create a scheduled task to run weekly:
```powershell
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-ExecutionPolicy Bypass -File C:\Scripts\Add-SunshineGames.ps1"
$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At 3am
Register-ScheduledTask -Action $action -Trigger $trigger -TaskName "Sunshine Game Sync" -Description "Auto-add new games to Sunshine" -RunLevel Highest
```

### Export Game List
```powershell
$config = Get-Content "C:\Program Files\Sunshine\config\apps.json" -Raw | ConvertFrom-Json
$config.apps | Select-Object name, cmd | Export-Csv "sunshine_games.csv" -NoTypeInformation
```

## Contributing

Found a bug? Have a suggestion? This script was created to solve a specific problem - feel free to modify it for your needs!

Common improvements you might want:
- Add support for GOG Galaxy libraries
- Add support for Epic Games Store
- Implement better image quality selection
- Add categories/tags for games
- Create Sunshine "collections" automatically

## Credits

- Created for use with [Sunshine](https://github.com/LizardByte/Sunshine) and [Moonlight](https://moonlight-stream.org/)
- Cover art powered by [SteamGridDB](https://www.steamgriddb.com/)

## License

Free to use and modify. No warranty provided. Use at your own risk.

---

**💡 Tip:** After running the script for the first time, you can run it again whenever you install new games. It will only add new ones thanks to duplicate detection!
