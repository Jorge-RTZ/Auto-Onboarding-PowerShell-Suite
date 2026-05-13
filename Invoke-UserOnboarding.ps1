# Auto-Onboarding PowerShell Suite
# Simulates AD account creation, email notification, and audit logging.
# In a live AD environment, swap the simulated sections for real AD cmdlets.

[CmdletBinding(SupportsShouldProcess)]
param (
    [Parameter(Mandatory)]
    [string]$CsvPath,

    [Parameter(Mandatory)]
    [string]$SmtpServer,

    [Parameter(Mandatory)]
    [string]$FromAddress,

    [string]$LogPath = ".\Logs",

    [string]$DefaultOU = "OU=Users,DC=company,DC=local"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$script:SimulatedUsers = @()

function Initialize-Log {
    if (-not (Test-Path $LogPath)) {
        New-Item -ItemType Directory -Path $LogPath -Force | Out-Null
    }
    $timestamp = Get-Date -Format "yyyy-MM-dd_HHmmss"
    $script:LogFile = Join-Path $LogPath "Onboarding_$timestamp.log"
    Write-Log -Level "INFO" -Message "=== Auto-Onboarding Suite Started ==="
    Write-Log -Level "INFO" -Message "Log file: $script:LogFile"
    Write-Log -Level "INFO" -Message "CSV source: $CsvPath"
}

function Write-Log {
    param (
        [ValidateSet("INFO","SUCCESS","WARNING","ERROR")]
        [string]$Level = "INFO",
        [Parameter(Mandatory)]
        [string]$Message,
        [string]$User = "SYSTEM"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "[$timestamp] [$Level] [User: $User] $Message"
    Add-Content -Path $script:LogFile -Value $entry
    switch ($Level) {
        "INFO"    { Write-Host $entry -ForegroundColor Cyan    }
        "SUCCESS" { Write-Host $entry -ForegroundColor Green   }
        "WARNING" { Write-Host $entry -ForegroundColor Yellow  }
        "ERROR"   { Write-Host $entry -ForegroundColor Red     }
    }
}

function Get-SamAccountName {
    param (
        [string]$FirstName,
        [string]$LastName
    )
    $base = ($FirstName.Substring(0,1) + $LastName).ToLower() -replace '\s',''
    $sam = $base
    $counter = 2
    while ($script:SimulatedUsers -contains $sam) {
        $sam = "$base$counter"
        $counter++
    }
    return $sam
}

function Get-DepartmentOU {
    param ([string]$Department)
    $ouMap = @{
        "IT"         = "OU=IT,OU=Departments,DC=company,DC=local"
        "HR"         = "OU=HR,OU=Departments,DC=company,DC=local"
        "Finance"    = "OU=Finance,OU=Departments,DC=company,DC=local"
        "Sales"      = "OU=Sales,OU=Departments,DC=company,DC=local"
        "Operations" = "OU=Operations,OU=Departments,DC=company,DC=local"
    }
    if ($ouMap.ContainsKey($Department)) {
        return $ouMap[$Department]
    }
    Write-Log -Level "WARNING" -Message "No OU mapping for '$Department'. Using default OU."
    return $DefaultOU
}

function New-TempPassword {
    $chars = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789!@#$"
    $pwd = ""
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $bytes = New-Object byte[] 14
    $rng.GetBytes($bytes)
    foreach ($b in $bytes) {
        $pwd += $chars[$b % $chars.Length]
    }
    return $pwd
}

function New-ADUserAccount {
    param ([PSCustomObject]$Hire)
    $displayName = "$($Hire.FirstName) $($Hire.LastName)"
    try {
        $sam = Get-SamAccountName -FirstName $Hire.FirstName -LastName $Hire.LastName
        $upn = "$sam@$($Hire.EmailDomain)"
        $ou  = Get-DepartmentOU -Department $Hire.Department
        $pwd = New-TempPassword

        if ($PSCmdlet.ShouldProcess($displayName, "Create AD Account")) {
            $script:SimulatedUsers += $sam
            Start-Sleep -Milliseconds 200
            Write-Log -Level "SUCCESS" -Message "[SIMULATED] AD account created: $sam | UPN: $upn | OU: $ou" -User $displayName
        }

        return @{
            SamAccountName = $sam
            UPN            = $upn
            PlainPassword  = $pwd
        }
    }
    catch {
        Write-Log -Level "ERROR" -Message "Failed to create account for $displayName - $_" -User $displayName
        return $null
    }
}

function Send-WelcomeEmail {
    param (
        [PSCustomObject]$Hire,
        [string]$SamAccountName,
        [string]$UPN,
        [string]$TempPassword
    )
    $displayName = "$($Hire.FirstName) $($Hire.LastName)"
    try {
        if ($PSCmdlet.ShouldProcess($Hire.ManagerEmail, "Send welcome email")) {
            Start-Sleep -Milliseconds 150
            Write-Log -Level "SUCCESS" -Message "[SIMULATED] Welcome email sent to: $($Hire.ManagerEmail)" -User $displayName
        }
    }
    catch {
        Write-Log -Level "ERROR" -Message "Failed to send email to $($Hire.ManagerEmail) - $_" -User $displayName
    }
}

function Invoke-Onboarding {
    Initialize-Log

    if (-not (Test-Path $CsvPath)) {
        Write-Log -Level "ERROR" -Message "CSV file not found: $CsvPath"
        return
    }

    $hires = Import-Csv -Path $CsvPath

    if (-not $hires) {
        Write-Log -Level "ERROR" -Message "CSV file is empty. Exiting."
        return
    }

    Write-Log -Level "INFO" -Message "Loaded $($hires.Count) new hire record(s)."

    $results = New-Object System.Collections.Generic.List[PSCustomObject]

    foreach ($hire in $hires) {
        $displayName = "$($hire.FirstName) $($hire.LastName)"
        Write-Log -Level "INFO" -Message "Processing: $displayName | $($hire.Title) | $($hire.Department)" -User $displayName

        $account = New-ADUserAccount -Hire $hire

        if ($null -eq $account) {
            Write-Log -Level "WARNING" -Message "Skipping email for $displayName due to account failure." -User $displayName
            $results.Add([PSCustomObject]@{
                Name     = $displayName
                Status   = "FAILED"
                Username = "N/A"
                Email    = "N/A"
            })
            continue
        }

        Send-WelcomeEmail `
            -Hire           $hire `
            -SamAccountName $account.SamAccountName `
            -UPN            $account.UPN `
            -TempPassword   $account.PlainPassword

        $results.Add([PSCustomObject]@{
            Name     = $displayName
            Status   = "SUCCESS"
            Username = $account.SamAccountName
            Email    = $account.UPN
        })
    }

    $success = @($results | Where-Object Status -eq "SUCCESS").Count
    $failed  = @($results | Where-Object Status -eq "FAILED").Count

    Write-Log -Level "INFO"    -Message "================================="
    Write-Log -Level "INFO"    -Message "ONBOARDING COMPLETE"
    Write-Log -Level "INFO"    -Message "Processed : $($hires.Count)"
    Write-Log -Level "SUCCESS" -Message "Succeeded : $success"
    if ($failed -gt 0) {
        Write-Log -Level "WARNING" -Message "Failed    : $failed"
    }
    Write-Log -Level "INFO" -Message "Log saved : $script:LogFile"
    Write-Log -Level "INFO" -Message "================================="

    $results | Format-Table -AutoSize
}

Invoke-Onboarding
