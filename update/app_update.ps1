# Script to upgrade installed applications using winget with batch processing

# Check if winget is installed
try {
    $wingetVersion = winget --version
    Write-Host "Winget detected: $wingetVersion" -ForegroundColor Green
} catch {
    Write-Host "Error: Winget is not installed or not in PATH. Please install winget first." -ForegroundColor Red
    exit 1
}

# Set the console encoding to UTF-8 to handle special characters in app names
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "Checking for available updates..." -ForegroundColor Cyan

# Get list of upgradeable packages and capture the output
$upgradeOutput = winget upgrade | Out-String

# Display the full upgrade list for reference
Write-Host "Available upgrades:" -ForegroundColor Cyan
Write-Host $upgradeOutput

# Parse the output to extract application information
$lines = $upgradeOutput -split "`n"
$dataStarted = $false
$upgradeableApps = @()

foreach ($line in $lines) {
    # Skip until we find the header separator line
    if ($line -match "^-{2,}") {
        $dataStarted = $true
        continue
    }
    
    # Process data lines
    if ($dataStarted -and $line -match "^[a-zA-Z0-9]") {
        # Skip the "winget upgrade" instruction line at the end
        if ($line -match "^winget upgrade") {
            continue
        }
        
        # Extract application ID (assuming standard winget output format)
        $appData = $line -split '\s\s+' | Where-Object { $_ -ne "" }
        if ($appData.Count -ge 3) {
            $appName = $appData[0].Trim()
            $appId = $appData[1].Trim()
            $appVersion = $appData[2].Trim()
            $availableVersion = if ($appData.Count -gt 3) { $appData[3].Trim() } else { "Unknown" }
            
            # Add to our collection
            $upgradeableApps += [PSCustomObject]@{
                Name = $appName
                Id = $appId
                CurrentVersion = $appVersion
                AvailableVersion = $availableVersion
                ToUpgrade = $false  # Default to not upgrading
            }
        }
    }
}

# Count how many apps need updates
$updateCount = $upgradeableApps.Count
Write-Host "Found $updateCount application(s) with available updates." -ForegroundColor Yellow

# List to store IDs of apps to upgrade
$appsToUpgrade = @()

# Process each app individually to collect user decisions
if ($updateCount -gt 0) {
    $stopProcessing = $false
    
    foreach ($app in $upgradeableApps) {
        # Check if user chose to stop processing
        if ($stopProcessing) {
            break
        }
        
        Write-Host ("-" * 60) -ForegroundColor Gray
        Write-Host "Application: $($app.Name)" -ForegroundColor Cyan
        Write-Host "ID: $($app.Id)" -ForegroundColor Cyan
        Write-Host "Current version: $($app.CurrentVersion)" -ForegroundColor Cyan
        Write-Host "Available version: $($app.AvailableVersion)" -ForegroundColor Cyan
        
        $confirmation = Read-Host "Do you want to upgrade this application? (Y/N/A to say No to all)"
        
        if ($confirmation -eq 'Y' -or $confirmation -eq 'y') {
            $app.ToUpgrade = $true
            $appsToUpgrade += $app.Id
            Write-Host "Added to upgrade list: $($app.Name)" -ForegroundColor Green
        } elseif ($confirmation -eq 'A' -or $confirmation -eq 'a') {
            Write-Host "Skipped: $($app.Name)" -ForegroundColor Gray
            Write-Host "No to all selected. Stopping further processing." -ForegroundColor Yellow
            $stopProcessing = $true
        } else {
            Write-Host "Skipped: $($app.Name)" -ForegroundColor Gray
        }
    }
    
    # Show summary of selections before proceeding
    Write-Host ("-" * 60) -ForegroundColor Gray
    $selectedCount = $appsToUpgrade.Count
    Write-Host "You've selected $selectedCount out of $updateCount applications to upgrade." -ForegroundColor Yellow
    
    if ($selectedCount -gt 0) {
        # Show list of applications that will be upgraded
        Write-Host "The following applications will be upgraded:" -ForegroundColor Cyan
        foreach ($app in $upgradeableApps | Where-Object { $_.ToUpgrade -eq $true }) {
            Write-Host "- $($app.Name) ($($app.CurrentVersion) → $($app.AvailableVersion))" -ForegroundColor White
        }
        
        # Final confirmation before batch upgrade
        $finalConfirmation = Read-Host "Proceed with batch upgrade of these $selectedCount applications? (Y/N)"
        
        if ($finalConfirmation -eq 'Y' -or $finalConfirmation -eq 'y') {
            Write-Host "Starting batch upgrade process..." -ForegroundColor Cyan
            
            # Count for success tracking
            $successCount = 0
            $failCount = 0
            
            # Process each app in the upgrade list
            foreach ($appId in $appsToUpgrade) {
                $appInfo = $upgradeableApps | Where-Object { $_.Id -eq $appId }
                Write-Host "Upgrading $($appInfo.Name)..." -ForegroundColor Yellow
                
                try {
                    # Upgrade the application
                    winget upgrade $appId
                    Write-Host "Successfully upgraded $($appInfo.Name)!" -ForegroundColor Green
                    $successCount++
                } catch {
                    Write-Host "Error upgrading $($appInfo.Name): $_" -ForegroundColor Red
                    $failCount++
                }
            }
            
            # Show final summary
            Write-Host ("-" * 60) -ForegroundColor Gray
            Write-Host "Batch upgrade process completed!" -ForegroundColor Green
            Write-Host "Summary: $successCount applications successfully upgraded, $failCount failed" -ForegroundColor Cyan
        } else {
            Write-Host "Batch upgrade canceled." -ForegroundColor Yellow
        }
    } else {
        Write-Host "No applications were selected for upgrade." -ForegroundColor Yellow
    }
} else {
    Write-Host "No updates available. All applications are up to date!" -ForegroundColor Green
}
