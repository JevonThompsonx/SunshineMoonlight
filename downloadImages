#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Download cover art for Sunshine games using SteamGridDB
.NOTES
    Get your free API key at: https://www.steamgriddb.com/profile/preferences/api
#>

# YOUR API KEY HERE
$STEAMGRIDDB_API_KEY = "YOUR_API_KEY_HERE"

$sunshineConfigPath = "C:\Program Files\Sunshine\config\apps.json"
$coverArtFolder = "C:\Program Files\Sunshine\config\covers"

# Create covers folder
if (-not (Test-Path $coverArtFolder)) {
    New-Item -ItemType Directory -Path $coverArtFolder -Force | Out-Null
}

# Load config
$config = Get-Content $sunshineConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json

$updated = 0

foreach ($app in $config.apps) {
    # Skip if already has image
    if ($app."image-path") { continue }
    
    $gameName = $app.name -replace " \(Steam\)", ""
    Write-Host "Searching for: $gameName" -ForegroundColor Cyan
    
    try {
        # Search for game
        $searchUrl = "https://www.steamgriddb.com/api/v2/search/autocomplete/$([uri]::EscapeDataString($gameName))"
        $headers = @{ "Authorization" = "Bearer $STEAMGRIDDB_API_KEY" }
        
        $searchResult = Invoke-RestMethod -Uri $searchUrl -Headers $headers
        
        if ($searchResult.data -and $searchResult.data.Count -gt 0) {
            $gameId = $searchResult.data[0].id
            
            # Get grid image (cover art)
            $gridUrl = "https://www.steamgriddb.com/api/v2/grids/game/$gameId"
            $gridResult = Invoke-RestMethod -Uri $gridUrl -Headers $headers
            
            if ($gridResult.data -and $gridResult.data.Count -gt 0) {
                $imageUrl = $gridResult.data[0].url
                $imageExt = [System.IO.Path]::GetExtension($imageUrl)
                $imagePath = Join-Path $coverArtFolder "$($gameName -replace '[<>:"/\\|?*]', '_')$imageExt"
                
                # Download image
                Invoke-WebRequest -Uri $imageUrl -OutFile $imagePath
                $app."image-path" = $imagePath
                $updated++
                
                Write-Host "  ✓ Downloaded cover art" -ForegroundColor Green
            }
        }
        
        Start-Sleep -Milliseconds 500  # Rate limiting
    }
    catch {
        Write-Host "  ! Error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Save updated config
if ($updated -gt 0) {
    $config | ConvertTo-Json -Depth 10 | Out-File $sunshineConfigPath -Encoding UTF8 -Force
    Write-Host "`n✓ Updated $updated games with cover art" -ForegroundColor Green
    Write-Host "Restart Sunshine to see the changes" -ForegroundColor Yellow
}
