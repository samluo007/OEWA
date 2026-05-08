# GitHub 2FA verification + PAT creation
$debugPort = 9222
$ghTabId = "01848BFDCAD4BCD89B4AE8883698F445"
$wsUrl = "ws://localhost:$debugPort/devtools/page/$ghTabId"

function CDP-SR {
    param($ws, $method, $params=@{}, $id=1)
    $msg = @{id=$id;method=$method;params=$params} | ConvertTo-Json -Compress
    $bytes = [Text.Encoding]::UTF8.GetBytes($msg)
    try {
        $ws.SendAsync([ArraySegment[byte]]$bytes, 'Text', $true, [Threading.CancellationToken]::None).Wait(6000)
        Start-Sleep -Milliseconds 200
        $buf = [byte[]]::new(8192)
        $ws.ReceiveAsync([ArraySegment[byte]]$buf, [Threading.CancellationToken]::None).Wait(6000) | Out-Null
        [Text.Encoding]::UTF8.GetString($buf).TrimEnd([char]0)
    } catch { Write-Host "[CDP ERROR] $_"; "{}" }
}

$ws = New-Object System.Net.WebSockets.ClientWebSocket
$ws.ConnectAsync([Uri]$wsUrl, [Threading.CancellationToken]::None).Wait(10000)
Write-Host "[WS CONNECTED]"

# Navigate to GitHub login first to reset state
$nav1 = CDP-SR $ws "Page.navigate" @{url="https://github.com/login"} 1
Write-Host "[NAV LOGIN]"
Start-Sleep 4

$url1 = CDP-SR $ws "Runtime.evaluate" @{expression="window.location.href"} 2
Write-Host "[URL1] $url1"

# Fill credentials
$fill = CDP-SR $ws "Runtime.evaluate" @{
    expression="
        var email = document.querySelector('#login_field');
        var pass = document.querySelector('#password');
        if (email) email.value = 'samluo007@hotmail.com';
        if (pass) pass.value = 'samluo2026';
        'filled: ' + (email?'ok':'fail') + ',' + (pass?'ok':'fail')
    "
} 3
Write-Host "[FILL] $fill"
Start-Sleep 0.5

# Click submit
$click = CDP-SR $ws "Runtime.evaluate" @{
    expression="
        var btn = document.querySelector('input[type=submit]');
        if (btn) { btn.click(); 'clicked'; } else { 'no btn' }
    "
} 4
Write-Host "[SUBMIT] $click"
Start-Sleep 8

# Now on 2FA device verification page
$url2 = CDP-SR $ws "Runtime.evaluate" @{expression="window.location.href"} 5
$body2 = CDP-SR $ws "Runtime.evaluate" @{expression="document.body.innerText.slice(0,500)"} 6
Write-Host "[URL2] $url2"
Write-Host "[BODY2] $body2"

# Enter the 2FA code
$code = "154271"
$enter = CDP-SR $ws "Runtime.evaluate" @{
    expression="
        var inp = document.querySelector('#otp_device_code') || document.querySelector('input[id*=otp]') || document.querySelector('input[id*=code]') || document.querySelector('input[name*=code]');
        if (inp) { inp.value = '$code'; 'code entered in: ' + inp.id; }
        else { 'no otp input found, listing: ' + JSON.stringify(Array.from(document.querySelectorAll('input')).map(i=>({id:i.id,name:i.name,type:i.type,placeholder:i.placeholder}))) }
    "
} 7
Write-Host "[ENTER CODE] $enter"
Start-Sleep 1

# Click verify
$verify = CDP-SR $ws "Runtime.evaluate" @{
    expression="
        var btn = document.querySelector('button[type=submit]') || document.querySelector('button.btn-primary') || Array.from(document.querySelectorAll('button')).find(b=>/verify|验证|确认/i.test(b.innerText));
        if (btn) { btn.click(); 'clicked verify: ' + btn.innerText.trim(); }
        else { 'no verify btn, listing btns: ' + Array.from(document.querySelectorAll('button')).map(b=>b.innerText.trim()).join('|') }
    "
} 8
Write-Host "[VERIFY] $verify"
Start-Sleep 10

# Check where we are now
$url3 = CDP-SR $ws "Runtime.evaluate" @{expression="window.location.href"} 9
$body3 = CDP-SR $ws "Runtime.evaluate" @{expression="document.body.innerText.slice(0,800)"} 10
Write-Host "[URL3] $url3"
Write-Host "[BODY3] $body3"

# Navigate to PAT page if logged in
if ($url3 -notmatch "login" -and $body3 -notmatch "Sign in") {
    Write-Host "[LOGGED IN! Navigating to PAT page...]"
    $patNav = CDP-SR $ws "Page.navigate" @{url="https://github.com/settings/tokens/new?scopes=repo,workflow,gist,read:org"} 11
    Write-Host "[NAV PAT]"
    Start-Sleep 8
    
    $patUrl = CDP-SR $ws "Runtime.evaluate" @{expression="window.location.href"} 12
    $patBody = CDP-SR $ws "Runtime.evaluate" @{expression="document.body.innerText.slice(0,3000)"} 13
    Write-Host "[PAT URL] $patUrl"
    Write-Host "=== PAT PAGE BODY ==="
    Write-Host $patBody
    
    # Fill form
    CDP-SR $ws "Runtime.evaluate" @{
        expression="
            var inp = document.querySelector('#token_description') || document.querySelector('[name=description]') || document.querySelector('input[placeholder*=describ]') || document.querySelector('input[id*=desc]');
            if (inp) { inp.value = 'OEWA OpenClaw Integration 2026'; 'desc set'; }
            else { 'no desc field' }
        "
    } 14
    Start-Sleep 1
    
    # Check repo scope checkbox
    CDP-SR $ws "Runtime.evaluate" @{
        expression="
            var cbs = document.querySelectorAll('input[type=checkbox]');
            var checked = [];
            for (var cb of cbs) {
                var lbl = (cb.parentElement?.innerText || '').toLowerCase();
                if (lbl.includes('repo') || cb.name?.includes('repo')) {
                    if (!cb.checked) cb.click();
                    checked.push(lbl.slice(0,30));
                }
            }
            'checked: ' + checked.join(', ');
        "
    } 15
    Start-Sleep 1
    
    # Generate token
    CDP-SR $ws "Runtime.evaluate" @{
        expression="
            var btns = document.querySelectorAll('button, [type=submit]');
            for (var b of btns) {
                var t = b.innerText.trim().toLowerCase();
                if (t.includes('generate') || t.includes('生成') || t.includes('create token')) {
                    b.click(); return 'clicked: ' + b.innerText.trim();
                }
            }
            'no generate btn';
        "
    } 16
    Write-Host "[GENERATE BTN]"
    Start-Sleep 8
    
    # Get the token
    $token = CDP-SR $ws "Runtime.evaluate" @{
        expression="
            var inps = document.querySelectorAll('input[readonly], input');
            for (var i of inps) {
                var v = i.value || i.defaultValue || '';
                if (v.match(/^ghp_[a-zA-Z0-9]{36}/) || v.match(/^github_pat_/)) return 'FOUND:' + v;
            }
            // Also try reading from the page body
            var txt = document.body.innerText;
            var m = txt.match(/ghp_[a-zA-Z0-9]{36}/) || txt.match(/github_pat_[a-zA-Z0-9_]{60,}/);
            m ? 'MATCHED:' + m[0] : 'NO_TOKEN';
        "
    } 17
    Write-Host "[TOKEN RESULT] $token"
    
    # Save token
    if ($token -match "ghp_[a-zA-Z0-9]{36}") {
        $tokFull = $token -replace '.*(ghp_[a-zA-Z0-9]{36}).*','$1'
        $tokFull | Out-File -FilePath "$env:USERPROFILE\.qclaw\oe_github_token.txt" -Encoding UTF8
        Write-Host "[TOKEN SAVED] $tokFull"
    }
} else {
    Write-Host "[STILL NOT LOGGED IN]"
}

try { $ws.CloseAsync('NormalClosure','',[Threading.CancellationToken]::None).Wait(2000) } catch {}
Write-Host "[DONE]"