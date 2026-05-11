# ===================================================================
#  Live Discord Notifications by Shad3ious - LiveDiscordNotificationsCustom.ps1
#  Main popup. Custom message, CSV toggle, per-send channel selection.
#  Channels button opens a management dialog (add, update, delete, test).
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

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
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

# ===================================================================
#  Channels management window
# ===================================================================

function Show-ChannelsWindow {

$chanXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Manage Channels - Live Discord Notifications by Shad3ious"
        Height="660" Width="580"
        WindowStartupLocation="CenterScreen"
        ResizeMode="NoResize"
        Background="#1e1e1e"
        Topmost="True">
    <Window.Resources>
        <Style TargetType="TextBlock">
            <Setter Property="Foreground" Value="#cccccc"/>
            <Setter Property="FontSize" Value="12"/>
        </Style>
        <Style TargetType="TextBox">
            <Setter Property="Background" Value="#2d2d2d"/>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="BorderBrush" Value="#444444"/>
            <Setter Property="CaretBrush" Value="White"/>
            <Setter Property="Padding" Value="5"/>
            <Setter Property="FontSize" Value="12"/>
        </Style>
        <Style TargetType="CheckBox">
            <Setter Property="Foreground" Value="#cccccc"/>
            <Setter Property="FontSize" Value="12"/>
        </Style>
        <Style TargetType="Button">
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Padding" Value="0,5"/>
            <Setter Property="FontSize" Value="12"/>
            <Setter Property="Cursor" Value="Hand"/>
        </Style>
        <Style TargetType="ListBox">
            <Setter Property="Background" Value="#2d2d2d"/>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="BorderBrush" Value="#444444"/>
        </Style>
    </Window.Resources>
    <Grid Margin="16">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <TextBlock Grid.Row="0" Text="Add new Channel:" FontWeight="Bold" Margin="0,0,0,8"/>

        <Grid Grid.Row="1" Margin="0,0,0,4">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="160"/>
                <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>
            <TextBlock Grid.Row="0" Grid.Column="0" Text="Discord Server Name:" VerticalAlignment="Center" Margin="0,4,8,4"/>
            <TextBox   Grid.Row="0" Grid.Column="1" x:Name="txtName"    Margin="0,4,0,4"/>
            <TextBlock Grid.Row="1" Grid.Column="0" Text="Webhook URL:"          VerticalAlignment="Center" Margin="0,4,8,4"/>
            <TextBox   Grid.Row="1" Grid.Column="1" x:Name="txtWebhook" Margin="0,4,0,4"/>
            <TextBlock Grid.Row="2" Grid.Column="0" Text="Role ID (optional):"   VerticalAlignment="Center" Margin="0,4,8,4"/>
            <TextBox   Grid.Row="2" Grid.Column="1" x:Name="txtRoleId"  Margin="0,4,0,4"/>
        </Grid>

        <StackPanel Grid.Row="2" Orientation="Horizontal" Margin="0,10,0,16">
            <Button   x:Name="btnAddSave"      Content="Add Channel" Width="120" Background="#5865F2"/>
            <Button   x:Name="btnTest"         Content="Test"        Width="70"  Background="#3a3a3a" Margin="8,0,0,0"/>
            <CheckBox x:Name="chkTestWithRole" Content="With role ping" VerticalAlignment="Center" Margin="10,0,0,0"/>
            <Button   x:Name="btnClearForm"    Content="Clear Form"  Width="100" Background="#3a3a3a" Margin="14,0,0,0"/>
        </StackPanel>

        <TextBlock Grid.Row="3" Text="Configured Discord Channels:" FontWeight="Bold" Margin="0,0,0,6"/>
        <ListBox   Grid.Row="4" x:Name="lstChannels" Margin="0,0,0,10"/>

        <Border Grid.Row="5" BorderBrush="#444" BorderThickness="1" Padding="10" Margin="0,0,0,12">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="160"/>
                    <ColumnDefinition Width="*"/>
                </Grid.ColumnDefinitions>
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                </Grid.RowDefinitions>
                <TextBlock Grid.Row="0" Grid.ColumnSpan="2" Text="Information:" FontWeight="Bold" Margin="0,0,0,4"/>
                <TextBlock Grid.Row="1" Grid.Column="0" Text="Discord Server Name:" Margin="0,2"/>
                <TextBlock Grid.Row="1" Grid.Column="1" x:Name="infoName"    Margin="0,2" TextWrapping="Wrap"/>
                <TextBlock Grid.Row="2" Grid.Column="0" Text="Webhook URL:"          Margin="0,2"/>
                <TextBlock Grid.Row="2" Grid.Column="1" x:Name="infoWebhook" Margin="0,2" TextWrapping="Wrap"/>
                <TextBlock Grid.Row="3" Grid.Column="0" Text="Role ID:"              Margin="0,2"/>
                <TextBlock Grid.Row="3" Grid.Column="1" x:Name="infoRoleId"  Margin="0,2"/>
            </Grid>
        </Border>

        <Grid Grid.Row="6">
            <Button x:Name="btnBack"   Content="Back"   Width="80" HorizontalAlignment="Left"  Background="#3a3a3a"/>
            <Button x:Name="btnDelete" Content="Delete" Width="80" HorizontalAlignment="Right" Background="#a33a3a"/>
        </Grid>
    </Grid>
</Window>
"@

    $chanReader = [System.Xml.XmlReader]::Create([System.IO.StringReader]$chanXaml)
    $script:chanWin = [System.Windows.Markup.XamlReader]::Load($chanReader)

    $script:txtName          = $script:chanWin.FindName("txtName")
    $script:txtWebhook       = $script:chanWin.FindName("txtWebhook")
    $script:txtRoleId        = $script:chanWin.FindName("txtRoleId")
    $script:btnAddSave       = $script:chanWin.FindName("btnAddSave")
    $script:btnTest          = $script:chanWin.FindName("btnTest")
    $script:chkTestWithRole  = $script:chanWin.FindName("chkTestWithRole")
    $script:btnClearForm     = $script:chanWin.FindName("btnClearForm")
    $script:lstChannels      = $script:chanWin.FindName("lstChannels")
    $script:infoName         = $script:chanWin.FindName("infoName")
    $script:infoWebhook      = $script:chanWin.FindName("infoWebhook")
    $script:infoRoleId       = $script:chanWin.FindName("infoRoleId")
    $script:btnBack          = $script:chanWin.FindName("btnBack")
    $script:btnDelete        = $script:chanWin.FindName("btnDelete")

    # Edit state: null = Add mode, string = Update mode (holds original name)
    $script:editingOriginalName = $null

    $script:refreshList = {
        $script:lstChannels.Items.Clear()
        try {
            $channels = @(Get-Channels)
        } catch {
            Write-LdnLog "refreshList: Get-Channels threw - $($_.Exception.Message)"
            [System.Windows.MessageBox]::Show(
                $_.Exception.Message,
                "Failed to load channels",
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Error) | Out-Null
            return
        }
        foreach ($ch in $channels) {
            $label = $ch.Name
            if (-not $ch.WebhookUrl) {
                $label = "$($ch.Name)  [corrupted]"
            }
            $script:lstChannels.Items.Add($label) | Out-Null
        }

        $loadErrors = Get-LdnLastLoadErrors
        if ($loadErrors.Count -gt 0) {
            $logPath = Get-LdnLogPath
            $msg = "Some channels could not be decrypted and are shown as [corrupted]:`n`n"
            foreach ($e in $loadErrors) { $msg += "- $e`n" }
            $msg += "`nFull details written to:`n$logPath"
            [System.Windows.MessageBox]::Show(
                $msg,
                "Decryption Errors",
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Warning) | Out-Null
        }
    }

    $script:clearForm = {
        $script:txtName.Text             = ""
        $script:txtWebhook.Text          = ""
        $script:txtRoleId.Text           = ""
        $script:chkTestWithRole.IsChecked = $false
        $script:editingOriginalName       = $null
        $script:btnAddSave.Content        = "Add Channel"
        $script:lstChannels.SelectedIndex = -1
        $script:infoName.Text             = ""
        $script:infoWebhook.Text          = ""
        $script:infoRoleId.Text           = ""
    }

    & $script:refreshList

    $script:lstChannels.Add_SelectionChanged({
        $selectedLabel = $script:lstChannels.SelectedItem
        if (-not $selectedLabel) { return }
        # Strip our [corrupted] decoration to get the real channel name.
        $selectedName = ([string]$selectedLabel -replace '\s+\[corrupted\]$', '').Trim()

        try {
            $ch = Get-Channels | Where-Object { $_.Name -eq $selectedName } | Select-Object -First 1
        } catch {
            return
        }
        if (-not $ch) { return }

        $script:txtName.Text    = $ch.Name
        $script:txtWebhook.Text = if ($ch.WebhookUrl) { $ch.WebhookUrl } else { "" }
        $script:txtRoleId.Text  = $ch.RoleId

        $script:editingOriginalName = $ch.Name
        $script:btnAddSave.Content  = "Update Channel"

        $script:infoName.Text    = $ch.Name
        $script:infoWebhook.Text = if ($ch.WebhookUrl) { $ch.WebhookUrl } else { "(missing or corrupted)" }
        $script:infoRoleId.Text  = if ($ch.RoleId) { $ch.RoleId } else { "(none)" }
    })

    $script:btnAddSave.Add_Click({
      try {
        $name    = $script:txtName.Text.Trim()
        $webhook = $script:txtWebhook.Text.Trim()
        $roleId  = $script:txtRoleId.Text.Trim()

        if (-not $name) {
            [System.Windows.MessageBox]::Show(
                "Discord Server Name is required.",
                "Missing field",
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Warning) | Out-Null
            return
        }
        if (-not $webhook) {
            [System.Windows.MessageBox]::Show(
                "Webhook URL is required.",
                "Missing field",
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Warning) | Out-Null
            return
        }
        if (-not (Test-DiscordWebhookUrl -Url $webhook)) {
            [System.Windows.MessageBox]::Show(
                "That does not look like a Discord webhook URL.`nExpected:`nhttps://discord.com/api/webhooks/{id}/{token}",
                "Invalid Webhook URL",
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Warning) | Out-Null
            return
        }
        if (-not (Test-DiscordRoleId -RoleId $roleId)) {
            [System.Windows.MessageBox]::Show(
                "Role ID must be numeric (e.g. 123456789012345678), or left blank.",
                "Invalid Role ID",
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Warning) | Out-Null
            return
        }

        # Force-array so $channels is never $null even if channels.json does not exist yet.
        $channels = @(Get-Channels)

        $isEditMode = [bool]$script:editingOriginalName

        if ($isEditMode) {
            if ($name -ne $script:editingOriginalName) {
                if ($channels | Where-Object { $_.Name -eq $name }) {
                    [System.Windows.MessageBox]::Show(
                        "A channel named '$name' already exists.",
                        "Duplicate Name",
                        [System.Windows.MessageBoxButton]::OK,
                        [System.Windows.MessageBoxImage]::Warning) | Out-Null
                    return
                }
            }

            $updated = @()
            $found = $false
            foreach ($ch in $channels) {
                if ($ch.Name -eq $script:editingOriginalName) {
                    $updated += [PSCustomObject]@{
                        Name       = $name
                        WebhookUrl = $webhook
                        RoleId     = $roleId
                    }
                    $found = $true
                } else {
                    $updated += $ch
                }
            }

            if (-not $found) {
                [System.Windows.MessageBox]::Show(
                    "Could not find original channel '$($script:editingOriginalName)' to update. It may have been deleted in another session.",
                    "Update Failed",
                    [System.Windows.MessageBoxButton]::OK,
                    [System.Windows.MessageBoxImage]::Error) | Out-Null
                & $script:clearForm
                & $script:refreshList
                return
            }

            Save-Channels -Channels $updated
        } else {
            if ($channels | Where-Object { $_.Name -eq $name }) {
                [System.Windows.MessageBox]::Show(
                    "A channel named '$name' already exists.",
                    "Duplicate Name",
                    [System.Windows.MessageBoxButton]::OK,
                    [System.Windows.MessageBoxImage]::Warning) | Out-Null
                return
            }

            $newCh = [PSCustomObject]@{
                Name       = $name
                WebhookUrl = $webhook
                RoleId     = $roleId
            }
            $updated = @($channels) + $newCh

            Save-Channels -Channels $updated
        }

        & $script:clearForm
        & $script:refreshList
      }
      catch {
        $line  = if ($_.InvocationInfo) { $_.InvocationInfo.ScriptLineNumber } else { "?" }
        $where = if ($_.InvocationInfo -and $_.InvocationInfo.Line) { $_.InvocationInfo.Line.Trim() } else { "" }
        $msg   = "Unexpected error while saving the channel:`n`n$($_.Exception.Message)`n`nLine $line"
        if ($where) { $msg += ":`n$where" }
        Write-LdnLog "btnAddSave: CAUGHT EXCEPTION - $($_.Exception.GetType().FullName) line $line - $($_.Exception.Message)"
        [System.Windows.MessageBox]::Show(
            $msg,
            "Save Failed",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Error) | Out-Null
      }
    })

    $script:btnTest.Add_Click({
        $name     = $script:txtName.Text.Trim()
        $webhook  = $script:txtWebhook.Text.Trim()
        $roleId   = $script:txtRoleId.Text.Trim()
        $withRole = [bool]$script:chkTestWithRole.IsChecked

        if (-not $webhook) {
            [System.Windows.MessageBox]::Show(
                "Enter a Webhook URL to test.",
                "Missing Webhook URL",
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Warning) | Out-Null
            return
        }
        if (-not (Test-DiscordWebhookUrl -Url $webhook)) {
            [System.Windows.MessageBox]::Show(
                "That does not look like a Discord webhook URL.",
                "Invalid URL",
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Warning) | Out-Null
            return
        }
        if ($withRole) {
            if (-not $roleId) {
                [System.Windows.MessageBox]::Show(
                    "'With role ping' is enabled but no Role ID is entered.",
                    "Missing Role ID",
                    [System.Windows.MessageBoxButton]::OK,
                    [System.Windows.MessageBoxImage]::Warning) | Out-Null
                return
            }
            if (-not (Test-DiscordRoleId -RoleId $roleId)) {
                [System.Windows.MessageBox]::Show(
                    "Role ID must be numeric.",
                    "Invalid Role ID",
                    [System.Windows.MessageBoxButton]::OK,
                    [System.Windows.MessageBoxImage]::Warning) | Out-Null
                return
            }
        }

        $displayName = if ($name) { "'$name'" } else { "the webhook" }

        if ($withRole) {
            $testBody     = "<@&$roleId>`nTest message from Live Discord Notifications by Shad3ious. Webhook and role ping worked."
            $allowedRoles = @($roleId)
        } else {
            $testBody     = "Test message from Live Discord Notifications by Shad3ious. Webhook works."
            $allowedRoles = @()
        }

        $script:btnTest.IsEnabled = $false
        try {
            $result = Send-DiscordWebhookMessage -WebhookUrl $webhook `
                                                 -Content $testBody `
                                                 -AllowedRoles $allowedRoles
        } finally {
            $script:btnTest.IsEnabled = $true
        }

        if ($result.Success) {
            [System.Windows.MessageBox]::Show(
                "Test message sent to $displayName.",
                "Test Successful",
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Information) | Out-Null
        } else {
            [System.Windows.MessageBox]::Show(
                "Test failed:`n`n$($result.Error)",
                "Test Failed",
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Error) | Out-Null
        }
    })

    $script:btnClearForm.Add_Click({ & $script:clearForm })

    $script:btnDelete.Add_Click({
        $selectedLabel = $script:lstChannels.SelectedItem
        if (-not $selectedLabel) {
            [System.Windows.MessageBox]::Show(
                "Select a channel from the list first.",
                "Nothing selected",
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Information) | Out-Null
            return
        }
        # Strip our [corrupted] decoration to get the real channel name.
        $selectedName = ([string]$selectedLabel -replace '\s+\[corrupted\]$', '').Trim()

        $confirm = [System.Windows.MessageBox]::Show(
            "Delete channel '$selectedName'? This cannot be undone.",
            "Confirm Delete",
            [System.Windows.MessageBoxButton]::YesNo,
            [System.Windows.MessageBoxImage]::Question)
        if ($confirm -ne [System.Windows.MessageBoxResult]::Yes) { return }

        try {
            $remaining = Get-Channels | Where-Object { $_.Name -ne $selectedName }
            Save-Channels -Channels @($remaining)
        } catch {
            [System.Windows.MessageBox]::Show(
                $_.Exception.Message,
                "Delete Failed",
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Error) | Out-Null
            return
        }
        & $script:clearForm
        & $script:refreshList
    })

    $script:btnBack.Add_Click({ $script:chanWin.Close() })

    $script:chanWin.Add_KeyDown({
        param($s, $e)
        if ($e.Key -eq [System.Windows.Input.Key]::Escape) {
            $script:chanWin.Close()
        }
    })

    $script:chanWin.ShowDialog() | Out-Null
}

# ===================================================================
#  Main window
# ===================================================================

$mainXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Live Discord Notifications by Shad3ious"
        Height="520" Width="480"
        WindowStartupLocation="CenterScreen"
        ResizeMode="NoResize"
        Background="#1e1e1e"
        Topmost="True">
    <Window.Resources>
        <Style TargetType="TextBlock">
            <Setter Property="Foreground" Value="#cccccc"/>
            <Setter Property="FontSize" Value="13"/>
        </Style>
        <Style TargetType="TextBox">
            <Setter Property="Background" Value="#2d2d2d"/>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="BorderBrush" Value="#444444"/>
            <Setter Property="CaretBrush" Value="White"/>
            <Setter Property="Padding" Value="6"/>
            <Setter Property="FontSize" Value="13"/>
        </Style>
        <Style TargetType="CheckBox">
            <Setter Property="Foreground" Value="#cccccc"/>
            <Setter Property="FontSize" Value="13"/>
        </Style>
        <Style TargetType="Button">
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Padding" Value="0,6"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="Cursor" Value="Hand"/>
        </Style>
    </Window.Resources>
    <Grid Margin="18">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <TextBlock Grid.Row="0" Text="Custom Message:" Margin="0,0,0,6"/>
        <TextBox x:Name="txtCustom" Grid.Row="1"
                 AcceptsReturn="True" TextWrapping="Wrap"
                 VerticalScrollBarVisibility="Auto"
                 Height="90" Margin="0,0,0,12"/>

        <CheckBox x:Name="chkCSV" Grid.Row="2"
                  Content="Include random message from CSV (appears on next line)"
                  IsChecked="True" Margin="0,0,0,14"/>

        <TextBlock Grid.Row="3" Text="Configured Discord Channels:" FontWeight="Bold" Margin="0,0,0,2"/>
        <TextBlock Grid.Row="4" Text="(Uncheck to skip a channel. Ctrl+Enter to send. Esc to cancel.)"
                   FontStyle="Italic" Foreground="#888" Margin="0,0,0,6"/>
        <Border Grid.Row="5" BorderBrush="#444" BorderThickness="1" Padding="8" Margin="0,0,0,14">
            <ScrollViewer VerticalScrollBarVisibility="Auto">
                <StackPanel x:Name="channelList"/>
            </ScrollViewer>
        </Border>

        <Grid Grid.Row="6">
            <Button x:Name="btnChannels" Content="Channels" Width="100"
                    HorizontalAlignment="Left" Background="#3a3a3a"/>
            <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
                <Button x:Name="btnCancel" Content="Cancel"
                        Width="80" Margin="0,0,10,0" Background="#3a3a3a"/>
                <Button x:Name="btnOK" Content="Go Live!"
                        Width="90" Background="#5865F2"/>
            </StackPanel>
        </Grid>
    </Grid>
</Window>
"@

$mainReader     = [System.Xml.XmlReader]::Create([System.IO.StringReader]$mainXaml)
$script:mainWin = [System.Windows.Markup.XamlReader]::Load($mainReader)

$script:txtCustom   = $script:mainWin.FindName("txtCustom")
$script:chkCSV      = $script:mainWin.FindName("chkCSV")
$script:channelList = $script:mainWin.FindName("channelList")
$script:btnChannels = $script:mainWin.FindName("btnChannels")
$script:btnCancel   = $script:mainWin.FindName("btnCancel")
$script:btnOK       = $script:mainWin.FindName("btnOK")

$script:channelCheckboxes = @()
$script:dialogResult      = $null

$script:refreshChannelCheckboxes = {
    $script:channelList.Children.Clear()
    $script:channelCheckboxes = @()

    try {
        $channels = @(Get-Channels)
    } catch {
        Write-LdnLog "refreshChannelCheckboxes: Get-Channels threw - $($_.Exception.Message)"
        $errText = New-Object System.Windows.Controls.TextBlock
        $errText.Text       = "Failed to load channels: $($_.Exception.Message)"
        $errText.Foreground = [System.Windows.Media.Brushes]::Salmon
        $errText.TextWrapping = 'Wrap'
        $script:channelList.Children.Add($errText) | Out-Null
        return
    }
    if (-not $channels -or @($channels).Count -eq 0) {
        $tb = New-Object System.Windows.Controls.TextBlock
        $tb.Text       = "(No channels configured. Click 'Channels' to add one.)"
        $tb.Foreground = [System.Windows.Media.Brushes]::Gray
        $tb.FontStyle  = [System.Windows.FontStyles]::Italic
        $script:channelList.Children.Add($tb) | Out-Null
        return
    }

    foreach ($ch in $channels) {
        $cb = New-Object System.Windows.Controls.CheckBox
        $cb.Content    = $ch.Name
        $cb.IsChecked  = $true
        $cb.Margin     = '0,3,0,3'
        $cb.Foreground = [System.Windows.Media.Brushes]::LightGray
        $cb.Tag        = $ch
        if (-not $ch.WebhookUrl) {
            $cb.Content   = "$($ch.Name) (corrupted - re-add)"
            $cb.IsChecked = $false
            $cb.IsEnabled = $false
            $cb.Foreground = [System.Windows.Media.Brushes]::Salmon
        }
        $script:channelList.Children.Add($cb) | Out-Null
        $script:channelCheckboxes += $cb
    }

    # Surface decryption errors once on the main window so the user knows why
    # entries appear corrupted. The Channels management window also surfaces
    # them on its own refresh.
    $loadErrors = Get-LdnLastLoadErrors
    if ($loadErrors.Count -gt 0 -and -not $script:LdnMainErrorsShown) {
        $script:LdnMainErrorsShown = $true
        $logPath = Get-LdnLogPath
        $msg = "Some channels could not be decrypted and are shown as (corrupted - re-add):`n`n"
        foreach ($e in $loadErrors) { $msg += "- $e`n" }
        $msg += "`nFull details written to:`n$logPath"
        [System.Windows.MessageBox]::Show(
            $msg,
            "Decryption Errors",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Warning) | Out-Null
    }
}

& $script:refreshChannelCheckboxes

$script:doGoLive = {
    $customText = $script:txtCustom.Text.Trim()
    $includeCSV = [bool]$script:chkCSV.IsChecked

    if (-not $customText -and -not $includeCSV) {
        [System.Windows.MessageBox]::Show(
            "Please enter a custom message or enable the CSV message.",
            "Nothing to send",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Warning) | Out-Null
        return
    }

    $selectedChannels = @($script:channelCheckboxes |
        Where-Object { $_.IsChecked -and $_.Tag -and $_.Tag.WebhookUrl } |
        ForEach-Object { $_.Tag })

    if ($selectedChannels.Count -eq 0) {
        [System.Windows.MessageBox]::Show(
            "Select at least one channel to send to.",
            "No channels selected",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Warning) | Out-Null
        return
    }

    $script:dialogResult = @{
        CustomText = $customText
        IncludeCSV = $includeCSV
        Channels   = $selectedChannels
    }
    $script:mainWin.Close()
}

$script:btnChannels.Add_Click({
    Show-ChannelsWindow
    & $script:refreshChannelCheckboxes
})

$script:btnCancel.Add_Click({ $script:mainWin.Close() })
$script:btnOK.Add_Click({ & $script:doGoLive })

$script:mainWin.Add_KeyDown({
    param($s, $e)
    if ($e.Key -eq [System.Windows.Input.Key]::Escape) {
        $script:mainWin.Close()
        $e.Handled = $true
    }
    elseif ($e.Key -eq [System.Windows.Input.Key]::Enter -and
            ([System.Windows.Input.Keyboard]::IsKeyDown([System.Windows.Input.Key]::LeftCtrl) -or
             [System.Windows.Input.Keyboard]::IsKeyDown([System.Windows.Input.Key]::RightCtrl))) {
        & $script:doGoLive
        $e.Handled = $true
    }
})

$script:mainWin.ShowDialog() | Out-Null

# ===================================================================
#  Send messages
# ===================================================================

if ($null -eq $script:dialogResult) { exit 0 }

$messages = $null
if ($script:dialogResult.IncludeCSV) {
    $csvPath = Get-ShadCsvPath
    if (-not (Test-Path $csvPath)) {
        [System.Windows.MessageBox]::Show(
            "CSV file not found:`n$csvPath",
            "CSV Missing",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Error) | Out-Null
        exit 1
    }
    try {
        $messages = Import-Csv -Path $csvPath -ErrorAction Stop
    } catch {
        [System.Windows.MessageBox]::Show(
            "Could not read CSV: $($_.Exception.Message)",
            "CSV Read Error",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Error) | Out-Null
        exit 1
    }
    if (-not $messages) {
        [System.Windows.MessageBox]::Show(
            "CSV file is empty:`n$csvPath",
            "CSV Empty",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Error) | Out-Null
        exit 1
    }
}

foreach ($channel in $script:dialogResult.Channels) {

    $lines = @()
    if ($script:dialogResult.CustomText) {
        $lines += $script:dialogResult.CustomText
    }
    if ($script:dialogResult.IncludeCSV -and $messages) {
        $randomMsg = ($messages | Get-Random).Message
        if ($randomMsg) { $lines += $randomMsg }
    }
    $messageBody = $lines -join "`n"

    if (-not $messageBody) {
        Write-Host "[$($channel.Name)] Skipped: message body would be empty." -ForegroundColor Yellow
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
