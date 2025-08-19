param (
    [Parameter(Mandatory = $true)]
    [string]$PolicyName,

    # Choose a field to match against (CRP is an alias of ProxyPolicyName)
    [ValidateSet('NetworkPolicyName','ProxyPolicyName','ConnectionRequestPolicyName','CalledStationID')]
    [string]$MatchField = 'NetworkPolicyName',

    # Time window: Minutes > Hours > Days (default 1 day if none supplied)
    [int]$MinutesBack,
    [int]$HoursBack,
    [int]$DaysBack,

    # Use substring match instead of exact (case-insensitive)
    [switch]$Contains
)

# ---- Elevation check (needed for Security log) ----
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Run as Administrator to read the Security log." -ForegroundColor Red
    exit 1
}

# ---- Helpers ----
function Get-XmlData([xml]$x, [string]$name) {
    $x.Event.EventData.Data | Where-Object Name -eq $name |
        Select-Object -ExpandProperty '#text' -ErrorAction Ignore
}
function Nz($v) { if ($null -eq $v) { '' } else { [string]$v } }

# ---- Time window ----
if     ($MinutesBack) { $StartTime = (Get-Date).AddMinutes(-$MinutesBack); $RangeText = "$MinutesBack minute(s)" }
elseif ($HoursBack)   { $StartTime = (Get-Date).AddHours(-$HoursBack);     $RangeText = "$HoursBack hour(s)" }
elseif ($DaysBack)    { $StartTime = (Get-Date).AddDays(-$DaysBack);       $RangeText = "$DaysBack day(s)" }
else                  { $StartTime = (Get-Date).AddDays(-1);               $RangeText = "1 day (default)" }

# Treat CRP as ProxyPolicyName (how 6272/6273 store it)
if ($MatchField -eq 'ConnectionRequestPolicyName') { $MatchField = 'ProxyPolicyName' }

Write-Host "Searching Security log (6272/6273) for $MatchField '$PolicyName' over the last $RangeText..." -ForegroundColor Cyan

# ---- Pull audited NPS events ----
$events = Get-WinEvent -FilterHashtable @{
    LogName   = 'Security'
    Id        = 6272,6273  # Granted / Denied
    StartTime = $StartTime
} -ErrorAction SilentlyContinue

if (-not $events) {
    Write-Host "No Security events found in the window." -ForegroundColor Yellow
    exit 0
}

# ---- Parse, filter, project ----
$rows = foreach ($evt in $events) {
    [xml]$x = $evt.ToXml()

    $fieldValue = Get-XmlData $x $MatchField
    if (-not $fieldValue) { continue }

    $isMatch = if ($Contains) { $fieldValue -like "*$PolicyName*" } else { $fieldValue -ieq $PolicyName }
    if (-not $isMatch) { continue }

    # Access (PS 5.1-friendly)
    $access = 'Unknown'
    if     ($evt.Id -eq 6272) { $access = 'Granted' }
    elseif ($evt.Id -eq 6273) { $access = 'Denied'  }

    # EAP type normalization
    $eapRaw = Get-XmlData $x 'EAPType'
    $eap    = if ($eapRaw -eq 'Microsoft: Smart Card or other certificate') { 'EAP-TLS' } else { $eapRaw }

    [pscustomobject]@{
        TimeCreated = $evt.TimeCreated
        Access      = $access
        UserName    = Get-XmlData $x 'SubjectUserName'
        ClientIP    = Get-XmlData $x 'ClientIPAddress'
        AuthType    = Get-XmlData $x 'AuthenticationType'
        EAPType     = $eap
    }
}

if (-not $rows) {
    Write-Host "No matching events found for '$PolicyName' in the last $RangeText." -ForegroundColor Yellow
    exit 0
}

# ---- Autosize widths based on data (with a minimum of header length) ----
# Convert to a printable snapshot so we measure exactly what we print
$print = $rows | Sort-Object TimeCreated | ForEach-Object {
    [pscustomobject]@{
        TimeCreated = $_.TimeCreated.ToString()   # use locale formatting
        Access      = Nz $_.Access
        UserName    = Nz $_.UserName
        ClientIP    = Nz $_.ClientIP
        AuthType    = Nz $_.AuthType
        EAPType     = Nz $_.EAPType
    }
}

# Calculate widths
$w = @{
    TimeCreated = [Math]::Max( ($print | % { $_.TimeCreated.Length } | Measure-Object -Maximum).Maximum, 'TimeCreated'.Length )
    Access      = [Math]::Max( ($print | % { $_.Access.Length      } | Measure-Object -Maximum).Maximum, 'Access'.Length )
    UserName    = [Math]::Max( ($print | % { $_.UserName.Length    } | Measure-Object -Maximum).Maximum, 'UserName'.Length )
    ClientIP    = [Math]::Max( ($print | % { $_.ClientIP.Length    } | Measure-Object -Maximum).Maximum, 'ClientIP'.Length )
    AuthType    = [Math]::Max( ($print | % { $_.AuthType.Length    } | Measure-Object -Maximum).Maximum, 'AuthType'.Length )
    EAPType     = [Math]::Max( ($print | % { $_.EAPType.Length     } | Measure-Object -Maximum).Maximum, 'EAPType'.Length )
}

# Add a little breathing room between AuthType and EAPType if they're tight
$w.AuthType = [Math]::Max($w.AuthType + 3, $w.AuthType)

# Build header and separator
$fmtAll = "{0,-$($w.TimeCreated)}  {1,-$($w.Access)}  {2,-$($w.UserName)}  {3,-$($w.ClientIP)}  {4,-$($w.AuthType)}  {5,-$($w.EAPType)}"
$header = $fmtAll -f 'TimeCreated','Access','UserName','ClientIP','AuthType','EAPType'
$totalWidth = $header.Length

Write-Host ""
Write-Host $header
Write-Host ("-" * $totalWidth)

# Print rows with color for Access
foreach ($r in $print) {
    # left chunk before Access
    $leftFmt = "{0,-$($w.TimeCreated)}  "
    Write-Host ($leftFmt -f $r.TimeCreated) -NoNewline

    # Access (colored)
    $accFmt = "{0,-$($w.Access)}  "
    $accCol = if ($r.Access -eq 'Granted') { 'Green' } else { 'Red' }
    Write-Host ($accFmt -f $r.Access) -NoNewline -ForegroundColor $accCol

    # rest
    $restFmt = "{0,-$($w.UserName)}  {1,-$($w.ClientIP)}  {2,-$($w.AuthType)}  {3,-$($w.EAPType)}"
    Write-Host ($restFmt -f $r.UserName, $r.ClientIP, $r.AuthType, $r.EAPType)
}

Write-Host "`nTotal hits found: $($print.Count)" -ForegroundColor Green
Write-Host "Last seen: $($print[-1].TimeCreated)" -ForegroundColor Green
