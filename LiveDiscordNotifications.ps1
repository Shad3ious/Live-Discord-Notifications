# ===================================================================
#  Live Discord Notifications by Shad3ious - LiveDiscordNotifications.ps1
#  Silent send. Posts a random CSV message to ALL configured channels.
#  Use LiveDiscordNotificationsCustom.ps1 for the popup version with channel selection.
# ===================================================================

$ErrorActionPreference = 'Stop'

try {
    . (Join-Path $PSScriptRoot "_lib.ps1")
} catch {
    Write-Host "Failed to load _lib.ps1: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Make sure _lib.ps1 is in the same folder as this script." -ForegroundColor Yellow
    Start-Sleep -Seconds 5
    exit 1
}

# -------------------------------------------------------------------
# FIRST-TIME SETUP: Replace YOUR_USERNAME below with your actual handle
# on each platform. Remove any lines for platforms you do not use.
# -------------------------------------------------------------------
$linksBlock = @"
Watch From:
[Twitch](<https://www.twitch.tv/YOUR_USERNAME>)
[YouTube](<https://www.youtube.com/@YOUR_USERNAME>)
[Kick](<https://kick.com/YOUR_USERNAME>)
[TikTok](<https://www.tiktok.com/@YOUR_USERNAME/live>)
"@

# --- Load channels ---
try {
    $channels = Get-Channels
} catch {
    Write-Host $_.Exception.Message -ForegroundColor Red
    Start-Sleep -Seconds 5
    exit 1
}

if (-not $channels -or @($channels).Count -eq 0) {
    Write-Host "No channels configured. Run LiveDiscordNotificationsCustom.ps1 and click Channels to add some." -ForegroundColor Yellow
    Start-Sleep -Seconds 5
    exit 0
}

# --- Load CSV ---
$csvPath = Get-ShadCsvPath
if (-not (Test-Path $csvPath)) {
    Write-Host "CSV not found: $csvPath" -ForegroundColor Red
    Start-Sleep -Seconds 5
    exit 1
}

try {
    $messages = Import-Csv -Path $csvPath -ErrorAction Stop
} catch {
    Write-Host "Could not read CSV: $($_.Exception.Message)" -ForegroundColor Red
    Start-Sleep -Seconds 5
    exit 1
}

if (-not $messages) {
    Write-Host "CSV is empty: $csvPath" -ForegroundColor Red
    Start-Sleep -Seconds 5
    exit 1
}

# --- Send to each channel ---
foreach ($channel in $channels) {
    if (-not $channel.WebhookUrl) {
        Write-Host "[$($channel.Name)] Skipped: missing or corrupted webhook URL." -ForegroundColor Yellow
        continue
    }

    $messageBody = ($messages | Get-Random).Message
    if (-not $messageBody) {
        Write-Host "[$($channel.Name)] Skipped: random CSV pick was empty." -ForegroundColor Yellow
        continue
    }

    $rolePing     = ""
    $allowedRoles = @()
    if ($channel.RoleId) {
        $rolePing     = "<@&$($channel.RoleId)>`n"
        $allowedRoles = @($channel.RoleId)
    }

    $textContent = @"
$rolePing$messageBody

$linksBlock
"@

    $result = Send-DiscordWebhookMessage -WebhookUrl $channel.WebhookUrl `
                                         -Content $textContent `
                                         -AllowedRoles $allowedRoles

    if ($result.Success) {
        Write-Host "[$($channel.Name)] Sent successfully." -ForegroundColor Green
    } else {
        Write-Host "[$($channel.Name)] FAILED: $($result.Error)" -ForegroundColor Red
    }
}

Start-Sleep -Seconds 3
