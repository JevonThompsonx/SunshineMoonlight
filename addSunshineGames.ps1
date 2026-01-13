#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Mass add games to Sunshine for Moonlight streaming
.DESCRIPTION
    Scans multiple drives for games, detects Steam libraries, finds cover art,
    and adds them all to Sunshine's configuration with duplicate detection.
.NOTES
    After running, refresh your Moonlight client by removing and re-adding the host.
#>

# ============================================================================
# CONFIGURATION
# ============================================================================

$sunshineConfigPath = "C:\Program Files\Sunshine\config\apps.json"

# Directories to exclude (non-game folders)
$excludeDirs = @(
    "WindowsApps", "_CommonRedist", "Program Files", "WpSystem", "WUDownloadCache",
    "tmp", "queue", "nzbget", "newslazer", "nextcloud", "rancidity", "Rufus", 
    "backups", "Egnyte Data", "game covers", "games", "NSwitch", "tv",
    "wii u emulator", "Switch", "Wii u", "2ds", "complete", "Anime Stream",
    "Dispatch", "LS", "_Bonus"
)

# Patterns to exclude from exe matching (installers, launchers, utilities)
$excludeExePatterns = @(
    "unins", "uninst", "setup", "install", "crash", "report", "launcher", 
    "redist", "vcredist", "directx", "dx", "updater", "update", "config",
    "settings", "steam", "eac", "battleye", "anti", "cheat", "uplay",
    "origin", "epic", "gog", "unity", "unreal", "support", "tool", "editor"
)

# Image file patterns for game covers
$imageExtensions = @("*.jpg", "*.jpeg", "*.png", "*.bmp", "*.webp")

# Game search paths - ADD OR REMOVE PATHS AS NEEDED
$gamePaths = @(
    "C:\Games",
    "D:\",
    "E:\SteamLibrary",
    "F:\",
    "F:\SteamLibrary"
)

# ============================================================================
# SCRIPT START
# ============================================================================

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Sunshine Game Mass-Add Script" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Backup existing config
if (Test-Path $sunshineConfigPath) {
    $backupPath = "$sunshineConfigPath.backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    Copy-Item $sunshineConfigPath $backupPath
    Write-Host "✓ Backup created: $backupPath" -ForegroundColor Green
} else {
    Write-Host "! No existing config found - will create new one" -ForegroundColor Yellow
}

# Load existing games to check for duplicates
$existingGames = @{}
$existingGameCount = 0
if (Test-Path $sunshineConfigPath) {
    try {
        $existingConfig = Get-Content $sunshineConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($existingConfig.apps) {
            $existingGameCount = $existingConfig.apps.Count
            foreach ($app in $existingConfig.apps) {
                if ($app.name) {
                    $existingGames[$app.name.ToLower()] = $true
                }
                if ($app.cmd) {
                    $existingGames[$app.cmd.ToLower()] = $true
                }
            }
            Write-Host "✓ Found $existingGameCount existing games in Sunshine config`n" -ForegroundColor Cyan
        }
    }
    catch {
        Write-Host "! Warning: Could not parse existing config - $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

$games = @()
$skippedCount = 0

# ============================================================================
# FUNCTIONS
# ============================================================================

function Test-GameExists {
    param(
        [string]$Name,
        [string]$ExePath
    )
    return $existingGames.ContainsKey($Name.ToLower()) -or 
           $existingGames.ContainsKey($ExePath.ToLower())
}

function Find-GameExecutable {
    param([string]$Path)
    
    $exes = Get-ChildItem -Path $Path -Filter "*.exe" -Recurse -ErrorAction SilentlyContinue -Depth 3 |
        Where-Object { 
            $name = $_.Name.ToLower()
            $excluded = $false
            foreach ($pattern in $excludeExePatterns) {
                if ($name -match $pattern) {
                    $excluded = $true
                    break
                }
            }
            -not $excluded
        } |
        Sort-Object { $_.DirectoryName.Length } |
        Select-Object -First 1
    
    return $exes
}

function Find-GameImage {
    param([string]$Path, [string]$GameName)
    
    foreach ($ext in $imageExtensions) {
        $images = Get-ChildItem -Path $Path -Filter $ext -Recurse -ErrorAction SilentlyContinue -Depth 2 |
            Where-Object { 
                $name = $_.Name.ToLower()
                $name -match "cover|poster|box|art|banner|logo|icon" -or 
                $name -match ($GameName.ToLower() -replace '[^a-z0-9]', '')
            } |
            Select-Object -First 1
        
        if ($images) {
            return $images.FullName
        }
    }
    return ""
}

function Get-SteamGames {
    param([string]$LibraryPath)
    
    $steamAppsPath = Join-Path $LibraryPath "steamapps"
    if (-not (Test-Path $steamAppsPath)) { return @() }
    
    $manifestFiles = Get-ChildItem -Path $steamAppsPath -Filter "appmanifest_*.acf" -ErrorAction SilentlyContinue
    
    $steamGames = @()
    foreach ($manifest in $manifestFiles) {
        try {
            $content = Get-Content $manifest.FullName -Raw
            
            if ($content -match '"name"\s+"([^"]+)"' -and $content -match '"installdir"\s+"([^"]+)"') {
                $gameName = $matches[1]
                $installDir = $matches[2]
                $gamePath = Join-Path (Join-Path $steamAppsPath "common") $installDir
                
                if (Test-Path $gamePath) {
                    $exe = Find-GameExecutable -Path $gamePath
                    if ($exe) {
                        $fullGameName = "$gameName (Steam)"
                        
                        if (Test-GameExists -Name $fullGameName -ExePath $exe.FullName) {
                            Write-Host "  ⊘ Skipped (duplicate): $fullGameName" -ForegroundColor DarkGray
                            $script:skippedCount++
                            continue
                        }
                        
                        $image = Find-GameImage -Path $gamePath -GameName $gameName
                        
                        $steamGames += @{
                            "name" = $fullGameName
                            "cmd" = $exe.FullName
                            "working-dir" = $exe.DirectoryName
                            "image-path" = $image
                        }
                        
                        $imageStatus = if ($image) { "🖼️" } else { "" }
                        Write-Host "  ✓ Steam: $gameName $imageStatus" -ForegroundColor Cyan
                    }
                }
            }
        }
        catch {
            Write-Host "  ! Error processing Steam manifest: $($manifest.Name)" -ForegroundColor Red
        }
    }
    return $steamGames
}

# ============================================================================
# SCAN FOR GAMES
# ============================================================================

foreach ($basePath in $gamePaths) {
    if (-not (Test-Path $basePath)) {
        Write-Host "⊘ Skipping missing path: $basePath" -ForegroundColor Yellow
        continue
    }
    
    Write-Host "`n📁 Scanning: $basePath" -ForegroundColor Magenta
    
    # Handle Steam libraries
    if ($basePath -like "*SteamLibrary*") {
        $games += Get-SteamGames -LibraryPath $basePath
        continue
    }
    
    # Get game directories
    $gameDirs = Get-ChildItem -Path $basePath -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notin $excludeDirs }
    
    foreach ($dir in $gameDirs) {
        try {
            $exe = Find-GameExecutable -Path $dir.FullName
            
            if ($exe) {
                $gameName = $dir.Name
                
                if (Test-GameExists -Name $gameName -ExePath $exe.FullName) {
                    Write-Host "  ⊘ Skipped (duplicate): $gameName" -ForegroundColor DarkGray
                    $skippedCount++
                    continue
                }
                
                $image = Find-GameImage -Path $dir.FullName -GameName $gameName
                
                # Sanitize paths to avoid UTF-8 issues
                $cleanCmd = $exe.FullName
                $cleanWorkingDir = $exe.DirectoryName
                $cleanImage = $image
                
                $games += @{
                    "name" = $gameName
                    "cmd" = $cleanCmd
                    "working-dir" = $cleanWorkingDir
                    "image-path" = $cleanImage
                }
                
                $imageStatus = if ($image) { "🖼️" } else { "" }
                Write-Host "  ✓ Found: $gameName $imageStatus" -ForegroundColor Green
            }
        }
        catch {
            Write-Host "  ! Error processing: $($dir.Name) - $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

# ============================================================================
# SAVE CONFIGURATION
# ============================================================================

if ($games.Count -eq 0) {
    Write-Host "`n! No new games found to add" -ForegroundColor Yellow
    exit
}

# Create or update Sunshine config
if (Test-Path $sunshineConfigPath) {
    $config = Get-Content $sunshineConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if (-not $config.apps) {
        $config | Add-Member -MemberType NoteProperty -Name "apps" -Value @()
    }
    $config.apps += $games
} else {
    $config = @{ "apps" = $games }
}

# Save config with UTF-8 encoding to avoid special character issues
try {
    $config | ConvertTo-Json -Depth 10 | Out-File $sunshineConfigPath -Encoding UTF8 -Force
    Write-Host "`n✓ Configuration saved successfully" -ForegroundColor Green
}
catch {
    Write-Host "`n! Error saving configuration: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Calculate total count
$totalCount = $existingGameCount + $games.Count

# ============================================================================
# SUMMARY
# ============================================================================

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "📊 SUMMARY" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "✓ Added: $($games.Count) new games" -ForegroundColor Green
Write-Host "⊘ Skipped: $skippedCount duplicates" -ForegroundColor Yellow
Write-Host "📁 Total in Sunshine: $totalCount games" -ForegroundColor Cyan
Write-Host "💾 Config: $sunshineConfigPath" -ForegroundColor Gray
Write-Host "========================================`n" -ForegroundColor Cyan

# Count games with images
$gamesWithImages = ($games | Where-Object { $_."image-path" -ne "" }).Count
if ($gamesWithImages -gt 0) {
    Write-Host "🖼️  Found images for $gamesWithImages/$($games.Count) games" -ForegroundColor Magenta
}

Write-Host "`n⚠️  NEXT STEPS:" -ForegroundColor Yellow
Write-Host "1. Restart Sunshine service (option below)" -ForegroundColor White
Write-Host "2. In Moonlight: Remove and re-add your host to refresh app list" -ForegroundColor White
Write-Host "3. Optionally: Add custom cover art (see script comments)" -ForegroundColor White

# ============================================================================
# SERVICE RESTART
# ============================================================================

$sunshineService = Get-Service -Name "SunshineService" -ErrorAction SilentlyContinue
if ($sunshineService) {
    Write-Host ""
    $restart = Read-Host "Restart Sunshine service now? (Y/N)"
    if ($restart -eq "Y" -or $restart -eq "y") {
        try {
            Restart-Service -Name "SunshineService" -Force
            Start-Sleep -Seconds 3
            Write-Host "✓ Sunshine service restarted" -ForegroundColor Green
        }
        catch {
            Write-Host "! Error restarting service: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
} else {
    Write-Host "`n! Sunshine service not found - restart manually" -ForegroundColor Yellow
}

Write-Host "`n========================================`n" -ForegroundColor Cyan