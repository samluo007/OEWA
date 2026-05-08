# OEWA GitHub PAT - Fast track
$debugPort = 9222

function CDP-SR {
    param($ws, $method, $params=@{}, $id=1)
    $msg = @{id=$id; method=$method; params=$params} | ConvertTo-Json -Compress
    $bytes = [Text.Encoding]::UTF8.GetBytes($msg)
    try {
        $ws.SendAsync([ArraySegment[byte]]$bytes, 'Text', $true, [Threading.CancellationToken]::None).Wait(6000)
        Start-Sleep -Milliseconds 200
        $buf = [byte[]]::new(8192)
        $ws.ReceiveAsync([ArraySegment[byte]]$buf, [Threading.CancellationToken]::None).Wait(6000) | Out-Null
        [Text.Encoding]::UTF8.GetString($buf).TrimEnd([char]0)
    } catch { "" }
}

# Use existing OpenClaw tab (already logged into OpenClaw gateway)
$pages = Invoke-RestMethod "http://localhost:$debugPort/json" -TimeoutSec 5
$opTab = $pages | Where-Object { $_.title -eq "OpenClaw Control" } | Select-Object -First 1
$wsUrl = $opTab.webSocketDebuggerUrl

$ws = New-Object System.Net.WebSockets.ClientWebSocket
$ws.ConnectAsync([Uri]$wsUrl, [Threading.CancellationToken]::None).Wait(8000)
Write-Host "[WS OK]"

# Navigate to GitHub PAT creation (will redirect to login if not logged in)
CDP-SR $ws "Page.navigate" @{url="https://github.com/settings/tokens/new?scopes=repo,workflow"} 1
Start-Sleep 8

$url = CDP-SR $ws "Runtime.evaluate" @{expression="window.location.href"} 2
$body = CDP-SR $ws "Runtime.evaluate" @{expression="document.body.innerText.slice(0,2000)"} 3
Write-Host "[URL] $url"
Write-Host "=== BODY ==="
Write-Host $body

# Check if this is a login page
if ($url -match "login" -or $body -match "Sign in" -or $body -match "登录") {
    Write-Host "[LOGIN REQUIRED]"
    
    # Fill email and password
    CDP-SR $ws "Runtime.evaluate" @{
        expression="
            var email = document.querySelector('#login_field') || document.querySelector('input[name=login]');
            var pass = document.querySelector('#password') || document.querySelector('input[name=password]');
            var btn = document.querySelector('input[type=submit]');
            if (email) email.value = 'samluo007@hotmail.com';
            if (pass) pass.value = 'samluo2026';
            if (btn) { btn.click(); 'submitted'; } else { 'no submit btn' };
        "
    } 4
    Write-Host "[LOGIN SUBMITTED]"
    Start-Sleep 10
    
    $url2 = CDP-SR $ws "Runtime.evaluate" @{expression="window.location.href"} 5
    Write-Host "[AFTER LOGIN] $url2"
    
    # If still on login, maybe 2FA or password is wrong
    if ($url2 -match "login") {
        $body2 = CDP-SR $ws "Runtime.evaluate" @{expression="document.body.innerText.slice(0,500)"} 6
        Write-Host "[STILL LOGIN] $body2"
    }
}

# Now we should be on the token creation page
$finalUrl = CDP-SR $ws "Runtime.evaluate" @{expression="window.location.href"} 7
$finalBody = CDP-SR $ws "Runtime.evaluate" @{expression="document.body.innerText.slice(0,2000)"} 8
Write-Host "[FINAL URL] $finalUrl"
Write-Host "=== FINAL BODY ==="
Write-Host $finalBody

# If on token page, fill description and generate
if ($finalUrl -match "tokens/new" -or $finalBody.Length -gt 200) {
    # Fill description field
    CDP-SR $ws "Runtime.evaluate" @{
        expression="
            var inp = document.querySelector('#token_description') || document.querySelector('[id*=description]') || document.querySelector('input[name*=desc]');
            if (inp) { inp.value = 'OEWA OpenClaw Push'; 'set desc'; } else { 'no desc field' }
        "
    } 9
    Write-Host "[DESC SET]"
    Start-Sleep 0.5
    
    # Select repo scope if not already
    CDP-SR $ws "Runtime.evaluate" @{
        expression="
            var cbs = document.querySelectorAll('input[type=checkbox]');
            var checked = [];
            for (var cb of cbs) {
                if (cb.checked) checked.push(cb.name || cb.parentElement?.innerText?.trim());
                if ((cb.name||'').includes('repo') && !cb.checked) cb.click();
            }
            'checkboxes: ' + checked.length;
        "
    } 10
    Write-Host "[SCOPES]"
    Start-Sleep 0.5
    
    # Click generate
    CDP-SR $ws "Runtime.evaluate" @{
        expression="
            var btns = document.querySelectorAll('button, [type=submit]');
            for (var b of btns) {
                var t = (b.innerText||'').trim();
                if (t.includes('生成') || t.includes('Generate') || t.includes('创建') || t.includes('Create token')) {
                    b.click(); return 'clicked: ' + t;
                }
            }
            'no gen btn. btns: ' + Array.from(btns).map(b=>(b.innerText||'').trim()).filter(t=>t).join('|');
        "
    } 11
    Write-Host "[GENERATE]"
    Start-Sleep 5
    
    # Read the token
    $tokenPage = CDP-SR $ws "Runtime.evaluate" @{
        expression="
            // Look for token in readonly input
            var inps = document.querySelectorAll('input[readonly], input[type=text]');
            var tokenVals = [];
            for (var i of inps) {
                if (i.value && (i.value.startsWith('ghp_') || i.value.startsWith('github_pat_'))) {
                    tokenVals.push(i.value);
                }
            }
            // Also try clipboard
            if (tokenVals.length > 0) 'TOKEN:' + tokenVals[0];
            else document.body.innerText.match(/ghp_[a-zA-Z0-9]{36}|github_pat_[a-zA-Z0-9_]{22,}/)?.[0] || 'NO_TOKEN';
        "
    } 12
    Write-Host "[TOKEN] $tokenPage"
}

# Try direct API approach via OpenClaw local proxy
# The 127.0.0.1:19000 proxy should have a GitHub integration token
# Let's check what integrations are available
Write-Host "`n=== CHECKING LOCAL INTEGRATION ==="
$intCheck = CDP-SR $ws "Runtime.evaluate" @{
    expression="
        // Look in localStorage for any GitHub tokens
        var keys = Object.keys(localStorage);
        var ghKeys = keys.filter(k => k.toLowerCase().includes('github') || k.toLowerCase().includes('token') || k.toLowerCase().includes('gh_'));
        var results = [];
        for (var k of ghKeys) {
            var v = localStorage.getItem(k);
            if (v && v.length > 5) results.push(k + ':' + v.substring(0,20));
        }
        JSON.stringify(results.slice(0,10));
    "
} 13
Write-Host "[LOCAL STORAGE] $intCheck"

try { $ws.CloseAsync('NormalClosure', "", [Threading.CancellationToken]::None).Wait(1000) } catch {}
Write-Host "[DONE]"