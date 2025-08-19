param (
    [Parameter(Mandatory = $true)]
    [string]$PolicyName,

    [int]$MinutesBack,
    [int]$HoursBack,
    [int]$DaysBack = 30,

    [switch]$LatestOnly
)

# Must be admin to read Security log
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Run this script as Administrator to read the Security log." -ForegroundColor Red
    exit 1
}

function Get-FieldValue {
    param([string]$Message, [string[]]$Patterns)
    foreach ($p in $Patterns) {
        $m = [regex]::Match($Message, $p, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [System.Text.RegularExpressions.RegexOptions]::Multiline)
        if ($m.Success) { return $m.Groups[1].Value.Trim() }
    }
    return $null
}

# Time window
$now = Get-Date
if ($MinutesBack -gt 0) { $startTime = $now.AddMinutes(-$MinutesBack); $rangeDesc = "$MinutesBack minute(s)" }
elseif ($HoursBack -gt 0) { $startTime = $now.AddHours(-$HoursBack); $rangeDesc = "$HoursBack hour(s)" }
else { $startTime = $now.AddDays(-$DaysBack); $rangeDesc = "$DaysBack day(s)" }

Write-Host "Searching NPS logs for policy '$PolicyName' over the last $rangeDesc..." -ForegroundColor Cyan

# Safe wrapper: return empty array instead of throwing
function Safe-GetWinEvent {
    param([hashtable]$Filter)
    try { Get-WinEvent -FilterHashtable $Filter -ErrorAction Stop } catch { @() }
}

# --- System log (NPS provider). Some environments won't log policy hits here — that's okay.
$systemEvents = Safe-GetWinEvent @{ LogName='System'; StartTime=$startTime; ProviderName='NPS' }
$systemHits = $systemEvents |
  Where-Object { $_.Message -like "*$PolicyName*" } |
  Select-Object TimeCreated, Id,
    @{n="Source";e={"System-NPS"}},
    @{n="UserName";e={ Get-FieldValue $_.Message @('(?m)^\s*User Name:\s*(.+)$','(?m)^\s*User:\s*(.+)$','(?m)^\s*User-Name\s*=\s*(.+)$') }},
    @{n="Client";e={ Get-FieldValue $_.Message @('(?m)^\s*Client Machine:\s*(.+)$','(?m)^\s*Client IPv4 Address:\s*([0-9\.]+)$','(?m)^\s*Client IPv6 Address:\s*([0-9a-f:]+)$','(?m)^\s*NAS IPv4 Address:\s*([0-9\.]+)$','(?m)^\s*NAS IPv6 Address:\s*([0-9a-f:]+)$') }}

# --- Security log (NPS auth: 6272 granted, 6273 denied)
$securityEvents = Safe-GetWinEvent @{
    LogName='Security'; StartTime=$startTime;
    ProviderName='Microsoft-Windows-Security-Auditing'; Id=@(6272,6273)
}
$securityHits = $securityEvents |
  Where-Object { $_.Message -like "*$PolicyName*" } |
  Select-Object TimeCreated, Id,
    @{n="Source";e={"Security-NPS"}},
    @{n="UserName";e={ Get-FieldValue $_.Message @('(?m)^\s*Account Name:\s*(.+)$','(?m)^\s*User Name:\s*(.+)$') }},
    @{n="Client";e={ Get-FieldValue $_.Message @('(?m)^\s*NAS IPv4 Address:\s*([0-9\.]+)$','(?m)^\s*Client IPv4 Address:\s*([0-9\.]+)$','(?m)^\s*NAS IPv6 Address:\s*([0-9a-f:]+)$','(?m)^\s*Client IPv6 Address:\s*([0-9a-f:]+)$','(?m)^\s*Client Machine Name:\s*(.+)$') }}

# Combine
$allHits = @($systemHits + $securityHits) | Sort-Object TimeCreated

if (-not $allHits -or $allHits.Count -eq 0) {
    Write-Host "No hits found for policy '$PolicyName' in the last $rangeDesc." -ForegroundColor Yellow
    exit 0
}

if ($LatestOnly) {
    $last = $allHits | Sort-Object TimeCreated -Descending | Select-Object -First 1
    $user = if ($last.UserName) { $last.UserName } else { 'N/A' }
    $cli  = if ($last.Client)   { $last.Client }   else { 'N/A' }
    Write-Host "`nMost recent hit: $($last.TimeCreated)  [Event $($last.Id) / $($last.Source)]  User: $user  Client: $cli" -ForegroundColor Cyan
    $last | Format-Table -AutoSize
} else {
    $allHits | Format-Table -AutoSize
    Write-Host "`nTotal hits found: $($allHits.Count)" -ForegroundColor Green
}
