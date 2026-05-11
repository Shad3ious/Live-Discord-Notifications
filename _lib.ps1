# ===================================================================
#  Live Discord Notifications by Shad3ious - _lib.ps1
#  Shared helpers. Dot-sourced by LiveDiscordNotifications.ps1 and LiveDiscordNotificationsCustom.ps1.
#  Do not run this file directly.
# ===================================================================

Add-Type -AssemblyName System.Security -ErrorAction SilentlyContinue

# Sanity-check: DPAPI must be available for webhook encryption to work.
# Surface a clear error at script load if the type is missing.
if (-not ('System.Security.Cryptography.ProtectedData' -as [type])) {
    throw "System.Security.Cryptography.ProtectedData is not available. This usually means System.Security failed to load. The tool needs Windows PowerShell 5.1 on Windows 10 or 11."
}

# --- Path helpers ---

function Get-ShadConfigPath {
    return (Join-Path $PSScriptRoot "channels.json")
}

function Get-ShadCsvPath {
    return (Join-Path $PSScriptRoot "Actionable_Stream_Notification_Messages.csv")
}

function Get-LdnLogPath {
    return (Join-Path $PSScriptRoot "livediscord.log")
}

# --- Logging ---

function Write-LdnLog {
    <#
        Appends a timestamped line to livediscord.log in the script folder.
        Never throws; logging failures are silent.
    #>
    param([string]$Message)
    try {
        $logPath = Get-LdnLogPath
        $stamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        $line = "[$stamp] $Message`r`n"
        # Use .NET directly so we get BOM-less UTF-8 with no encoding surprises.
        [System.IO.File]::AppendAllText($logPath, $line, [System.Text.UTF8Encoding]::new($false))
    } catch {
        # Logging never throws.
    }
}

# --- DPAPI encryption (CurrentUser scope) ---

function Protect-WebhookString {
    param([Parameter(Mandatory)][string]$Plain)
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Plain)
    $protected = [System.Security.Cryptography.ProtectedData]::Protect(
        $bytes,
        $null,
        [System.Security.Cryptography.DataProtectionScope]::CurrentUser
    )
    return [Convert]::ToBase64String($protected)
}

function Unprotect-WebhookString {
    param([Parameter(Mandatory)][string]$Protected)
    # Strip any whitespace that might have crept in (newlines, spaces).
    $clean = ($Protected -replace '\s', '')
    $bytes = [Convert]::FromBase64String($clean)
    $unprotected = [System.Security.Cryptography.ProtectedData]::Unprotect(
        $bytes,
        $null,
        [System.Security.Cryptography.DataProtectionScope]::CurrentUser
    )
    return [System.Text.Encoding]::UTF8.GetString($unprotected)
}

# --- Validation helpers ---

function Test-DiscordWebhookUrl {
    param([string]$Url)
    if (-not $Url) { return $false }
    return ($Url -match '^https://(discord\.com|discordapp\.com)/api/webhooks/\d+/.+')
}

function Test-DiscordRoleId {
    param([string]$RoleId)
    if (-not $RoleId) { return $true }
    return ($RoleId -match '^\d+$')
}

# --- BOM-less UTF-8 file I/O ---
# PS 5.1's Set-Content -Encoding UTF8 writes a BOM, and Get-Content -Encoding UTF8
# is supposed to strip it on read but has had bugs. Use .NET directly with
# explicit BOM-less UTF8Encoding to avoid the whole class of issues.

function Read-LdnTextFile {
    param([Parameter(Mandatory)][string]$Path)
    return [System.IO.File]::ReadAllText($Path, [System.Text.UTF8Encoding]::new($false))
}

function Write-LdnTextFile {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Content
    )
    [System.IO.File]::WriteAllText($Path, $Content, [System.Text.UTF8Encoding]::new($false))
}

# --- Channel storage ---

# Holds the most recent load errors so the UI can surface them.
$script:LdnLastLoadErrors = @()

function Get-LdnLastLoadErrors {
    if ($null -eq $script:LdnLastLoadErrors) { return @() }
    return $script:LdnLastLoadErrors
}

function Get-Channels {
    <#
        Loads and decrypts channels from channels.json.
        Returns @() if file does not exist or is empty.
        Auto-migrates legacy plaintext entries to encrypted on first read.
        Entries that cannot be decrypted are still returned in the result with
        WebhookUrl=$null so they remain visible in the UI as corrupted. Their
        original encrypted blob is preserved in WebhookUrlProtected so that
        unrelated edits do not destroy their data on the next save.
        Decrypt errors are recorded in $script:LdnLastLoadErrors and written
        to livediscord.log.
    #>
    $script:LdnLastLoadErrors = @()

    $path = Get-ShadConfigPath
    if (-not (Test-Path $path)) { return @() }

    try {
        $raw = Read-LdnTextFile -Path $path
    } catch {
        Write-LdnLog "Get-Channels: could not read channels.json - $($_.Exception.Message)"
        throw "Could not read channels.json: $($_.Exception.Message)"
    }

    if (-not $raw -or -not $raw.Trim()) { return @() }

    try {
        $data = @($raw | ConvertFrom-Json -ErrorAction Stop)
    } catch {
        Write-LdnLog "Get-Channels: JSON parse failed - $($_.Exception.Message)"
        throw "channels.json is corrupted (not valid JSON): $($_.Exception.Message)"
    }

    $needsMigration = $false
    $result = @()

    foreach ($entry in $data) {
        # Use direct property access. PSObject.Properties['x'] indexer returns
        # falsy in some PS 5.1 builds even when the property exists, so read
        # the value directly and check it instead.
        $name = if ($entry.Name) { [string]$entry.Name } else { "" }
        if (-not $name) {
            Write-LdnLog "Get-Channels: skipping entry with no Name (props: $(($entry.PSObject.Properties | ForEach-Object { $_.Name }) -join ','))"
            continue
        }

        $roleId          = if ($entry.RoleId)              { [string]$entry.RoleId              } else { "" }
        $protectedString = if ($entry.WebhookUrlProtected) { [string]$entry.WebhookUrlProtected } else { "" }
        $plaintextString = if ($entry.WebhookUrl)          { [string]$entry.WebhookUrl          } else { "" }
        $hasProtected    = [bool]$protectedString
        $hasPlaintext    = [bool]$plaintextString
        $webhookUrl      = $null

        if ($hasProtected) {
            try {
                $webhookUrl = Unprotect-WebhookString -Protected $protectedString
            } catch {
                $errType = $_.Exception.GetType().FullName
                $errMsg  = $_.Exception.Message
                $script:LdnLastLoadErrors += "Channel '$name': $errType - $errMsg"
                Write-LdnLog "Get-Channels: DECRYPT FAILED for '$name' - $errType - $errMsg"
                # Fall through with $webhookUrl=$null so the entry stays visible as corrupted.
            }
        } elseif ($hasPlaintext) {
            $webhookUrl     = $plaintextString
            $needsMigration = $true
        } else {
            $script:LdnLastLoadErrors += "Channel '$name': no webhook URL field found"
            Write-LdnLog "Get-Channels: '$name' has no webhook URL field"
            continue
        }

        $result += [PSCustomObject]@{
            Name                = $name
            WebhookUrl          = $webhookUrl
            WebhookUrlProtected = $protectedString
            RoleId              = $roleId
        }
    }

    if ($needsMigration) {
        try {
            Save-Channels -Channels $result
        } catch {
            Write-LdnLog "Get-Channels: migration save failed - $($_.Exception.Message)"
        }
    }

    return $result
}

function Save-Channels {
    <#
        Writes the array to channels.json atomically (write to .tmp then rename).
        For each entry, if WebhookUrl (plaintext) is set, it is encrypted to
        WebhookUrlProtected. If WebhookUrl is empty but WebhookUrlProtected is
        set, the existing encrypted blob is preserved verbatim so that entries
        loaded as corrupted are not silently destroyed by an unrelated save.
    #>
    param([Parameter(Mandatory)][AllowEmptyCollection()][array]$Channels)

    $path = Get-ShadConfigPath

    $output = @()
    foreach ($ch in $Channels) {
        if (-not $ch -or -not $ch.Name) { continue }

        $protected = ""
        if ($ch.WebhookUrl) {
            try {
                $protected = Protect-WebhookString -Plain $ch.WebhookUrl
                Write-LdnLog "Save-Channels: encrypted '$($ch.Name)' (blob len $($protected.Length))"
            } catch {
                Write-LdnLog "Save-Channels: ENCRYPT FAILED for '$($ch.Name)' - $($_.Exception.Message)"
                throw "Could not encrypt webhook for '$($ch.Name)': $($_.Exception.Message)"
            }
        } elseif ($ch.WebhookUrlProtected) {
            # Preserve existing encrypted blob (corrupted-on-load entry).
            $protected = [string]$ch.WebhookUrlProtected
            Write-LdnLog "Save-Channels: preserved existing blob for '$($ch.Name)' (could not decrypt earlier)"
        }

        $output += [PSCustomObject]@{
            Name                = [string]$ch.Name
            WebhookUrlProtected = $protected
            RoleId              = [string]$ch.RoleId
        }
    }

    if ($output.Count -eq 0) {
        $json = "[]"
    } else {
        # Force array context. ConvertTo-Json in PS 5.1 sometimes drops the
        # array wrapper for single-item arrays.
        $json = ConvertTo-Json -InputObject @($output) -Depth 4
        if (-not $json -or $json.TrimStart()[0] -ne '[') {
            $json = "[$json]"
        }
    }

    $tempPath = "$path.tmp"
    try {
        Write-LdnTextFile -Path $tempPath -Content $json
        Move-Item -Path $tempPath -Destination $path -Force -ErrorAction Stop
        Write-LdnLog "Save-Channels: wrote $($output.Count) entries to $path"
    } catch {
        if (Test-Path $tempPath) {
            Remove-Item $tempPath -Force -ErrorAction SilentlyContinue
        }
        Write-LdnLog "Save-Channels: file write failed - $($_.Exception.Message)"
        throw "Could not save channels.json at '$path': $($_.Exception.Message)"
    }
}

# --- Discord webhook send ---

function Send-DiscordWebhookMessage {
    <#
        Posts a content-only message to a Discord webhook.
        Returns @{ Success = $true/$false; Error = $string }.
        Never throws; failures are returned as Success=$false.
        AllowedRoles limits role pings; pass @() to ping nothing,
        @($roleId) to ping exactly that role and nothing else.
    #>
    param(
        [Parameter(Mandatory)][string]$WebhookUrl,
        [Parameter(Mandatory)][string]$Content,
        [string[]]$AllowedRoles = @()
    )

    $payload = @{
        content          = $Content
        allowed_mentions = @{
            parse = @()
            roles = @($AllowedRoles)
        }
    }
    $jsonPayload = $payload | ConvertTo-Json -Depth 4
    $bodyBytes   = [System.Text.Encoding]::UTF8.GetBytes($jsonPayload)

    try {
        Invoke-RestMethod -Uri $WebhookUrl `
                          -Method Post `
                          -Body $bodyBytes `
                          -ContentType 'application/json; charset=utf-8' `
                          -ErrorAction Stop | Out-Null
        return @{ Success = $true; Error = $null }
    } catch {
        $errMsg = $_.Exception.Message
        if ($_.ErrorDetails -and $_.ErrorDetails.Message) {
            $errMsg += " | $($_.ErrorDetails.Message)"
        }
        return @{ Success = $false; Error = $errMsg }
    }
}
