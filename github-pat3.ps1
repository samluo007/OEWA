# GitHub PAT creation - use existing tab
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

# Check current URL
$curUrl = CDP-SR $ws "Runtime.evaluate" @{expression="window.location.href"} 1
Write-Host "[CURRENT] $curUrl"

# Fill login form
$fill = CDP-SR $ws "Runtime.evaluate" @{
    expression="
        var email = document.querySelector('#login_field');
        var pass = document.querySelector('#password');
        if (email) email.value = 'samluo007@hotmail.com';
        if (pass) pass.value = 'samluo2026';
        'fields filled'
    "
} 2
Write-Host "[FILL] $fill"
Start-Sleep 0.5

# Click sign in
$click = CDP-SR $ws "Runtime.evaluate" @{
    expression="
        var btn = document.querySelector('input[type=submit]');
        if (btn) { btn.click(); 'clicked submit'; } else { 'no btn' };
    "
} 3
Write-Host "[SUBMIT] $click"
Start-Sleep 12

# Check where we are now
$url2 = CDP-SR $ws "Runtime.evaluate" @{expression="window.location.href"} 4
$body2 = CDP-SR $ws "Runtime.evaluate" @{expression="document.body.innerText.slice(0,800)"} 5
Write-Host "[URL2] $url2"
Write-Host "[BODY2] $body2"

# If 2FA or device verification, deal with it
if ($url2 -match "sessions/verified-device" -or $body2 -match "验证") {
    Write-Host "[2FA/VERIFICATION NEEDED - waiting 20s]"
    Start-Sleep 20
}

# If still on login page, try clicking submit again
if ($url2 -match "login" -or $body2 -match "Sign in") {
    Write-Host "[STILL LOGIN - retry]"
    $click2 = CDP-SR $ws "Runtime.evaluate" @{
        expression="
            var btn = document.querySelector('input[type=submit]') || document.querySelector('.btn-primary');
            if (btn) { btn.click(); 'retry clicked'; } else { 'still no btn' }
        "
    } 6
    Write-Host "[RETRY] $click2"
    Start-Sleep 15
    $url3 = CDP-SR $ws "Runtime.evaluate" @{expression="window.location.href"} 7
    Write-Host "[URL3] $url3"
}

# Now navigate to PAT creation page
$patNav = CDP-SR $ws "Page.navigate" @{url="https://github.com/settings/tokens/new?scopes=repo,workflow,gist,read:org"} 8
Write-Host "[NAV PAT] sent"
Start-Sleep 8

$patUrl = CDP-SR $ws "Runtime.evaluate" @{expression="window.location.href"} 9
$patBody = CDP-SR $ws "Runtime.evaluate" @{expression="document.body.innerText.slice(0,2000)"} 10
Write-Host "[PAT URL] $patUrl"
Write-Host "=== PAT BODY ==="
Write-Host $patBody

# If on token page, fill and generate
if ($patBody.Length -gt 100 -and $patBody -notmatch "Sign in") {
    Write-Host "[ON TOKEN PAGE]"
    
    # Fill description
    CDP-SR $ws "Runtime.evaluate" @{
        expression="
            var inp = document.querySelector('#token_description') || 
                      document.querySelector('[name=description]') ||
                      document.querySelector('input[id*=description]') ||
                      document.querySelector('input[placeholder*=描述]') ||
                      document.querySelector('input[placeholder*=description]');
            if (inp) { inp.value = 'OEWA OpenClaw Integration 2026'; 'desc set: ' + inp.id; }
            else { 'no desc field, listing inputs: ' + Array.from(document.querySelectorAll('input')).map(i=>i.id+':'+i.type).join('|') }
        "
    } 11
    Start-Sleep 1
    
    # Make sure repo scope is checked
    CDP-SR $ws "Runtime.evaluate" @{
        expression="
            var cbs = document.querySelectorAll('input[type=checkbox]');
            var repoFound = false;
            for (var cb of cbs) {
                var name = (cb.name || '').toLowerCase();
                var label = (cb.parentElement?.innerText || '').toLowerCase();
                if (name.includes('repo') || label.includes('repo')) {
                    if (!cb.checked) cb.click();
                    repoFound = true;
                }
            }
            'repo scope: ' + repoFound;
        "
    } 12
    Start-Sleep 1
    
    # Click generate button - look for various text patterns
    CDP-SR $ws "Runtime.evaluate" @{
        expression="
            var btns = document.querySelectorAll('button, [type=submit]');
            var patterns = ['generate','生成','创建','submit','确认'];
            for (var b of btns) {
                var t = (b.innerText||'').trim().toLowerCase();
                for (var p of patterns) {
                    if (t.includes(p)) { b.click(); return 'clicked: ' + b.innerText.trim(); }
                }
            }
            'no generate btn found';
        "
    } 13
    Write-Host "[GENERATE BTN]"
    Start-Sleep 6
    
    # Read the token
    $token = CDP-SR $ws "Runtime.evaluate" @{
        expression="
            var inps = document.querySelectorAll('input');
            var found = '';
            for (var i of inps) {
                var v = i.value || i.defaultValue || '';
                if (v.match(/^ghp_[a-zA-Z0-9]{36}$/) || v.match(/^github_pat_/)) {
                    found = v; break;
                }
            }
            if (found) 'TOKEN_FOUND:' + found;
            else document.body.innerText.match(/ghp_[a-zA-Z0-9]{36}/)?.[0] || 'NO_TOKEN_IN_PAGE';
        "
    } 14
    Write-Host "[TOKEN RESULT] $token"
    
    # Save to file
    if ($token -match "ghp_[a-zA-Z0-9]{36}") {
        $tokenValue = ($token -split 'ghp_')[1]
        $tokenValue = "ghp_$tokenValue"
        $tokenValue | Out-File -FilePath "$env:USERPROFILE\.qclaw\oe_github_token.txt" -Encoding UTF8
        Write-Host "[SAVED TOKEN to oe_github_token.txt]"
        Write-Host "GITHUB_TOKEN=ghp_$tokenValue"
    }
}

try { $ws.CloseAsync('NormalClosure','',[Threading.CancellationToken]::None).Wait(2000) } catch {}
Write-Host "[DONE]"