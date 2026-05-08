# OEWA GitHub PAT Creation - Automate via browser
$debugPort = 9222

function CDP-SR {
    param($ws, $method, $params=@{}, $id=1)
    $msg = @{id=$id; method=$method; params=$params} | ConvertTo-Json -Compress
    $bytes = [Text.Encoding]::UTF8.GetBytes($msg)
    try {
        $ws.SendAsync([ArraySegment[byte]]$bytes, 'Text', $true, [Threading.CancellationToken]::None).Wait(6000)
        Start-Sleep -Milliseconds 300
        $buf = [byte[]]::new(16384)
        $ws.ReceiveAsync([ArraySegment[byte]]$buf, [Threading.CancellationToken]::None).Wait(6000) | Out-Null
        [Text.Encoding]::UTF8.GetString($buf).TrimEnd([char]0)
    } catch { "" }
}

# Create new tab for GitHub
$newTab = Invoke-RestMethod -Method Put "http://localhost:$debugPort/json/new" -TimeoutSec 5
$wsUrl = $newTab.webSocketDebuggerUrl
$tabId = $newTab.id
Write-Host "[NEW TAB] $tabId"

$ws = New-Object System.Net.WebSockets.ClientWebSocket
$ws.ConnectAsync([Uri]$wsUrl, [Threading.CancellationToken]::None).Wait(8000)
Write-Host "[WS OK]"

# Step 1: Go to GitHub login
CDP-SR $ws "Page.navigate" @{url="https://github.com/login"} 1
Start-Sleep 5

$title = CDP-SR $ws "Runtime.evaluate" @{expression="document.title"} 2
$body = CDP-SR $ws "Runtime.evaluate" @{expression="document.body.innerText.slice(0,2000)"} 3
Write-Host "[LOGIN PAGE] $title"
Write-Host $body

# Check if already logged in
if ($body -match "Sign in" -and $body -notmatch "samluo") {
    Write-Host "Need to log in to GitHub"
    
    # Fill login form
    $fillResult = CDP-SR $ws "Runtime.evaluate" @{
        expression="
            var emailInput = document.querySelector('#login_field') || document.querySelector('input[name=login]');
            var passInput = document.querySelector('#password') || document.querySelector('input[name=password]');
            if (emailInput) emailInput.value = 'samluo007@hotmail.com';
            if (passInput) passInput.value = 'samluo2026';
            'filled: email=' + (emailInput?'yes':'no') + ' pass=' + (passInput?'yes':'no');
        "
    } 4
    Write-Host "[FILL] $fillResult"
    Start-Sleep 1
    
    # Click sign in button
    $clickResult = CDP-SR $ws "Runtime.evaluate" @{
        expression="
            var btn = document.querySelector('input[type=submit]') || document.querySelector('.btn-primary');
            if (btn) { btn.click(); 'clicked: ' + btn.type + ' ' + btn.className; } 
            else { 'no btn found' }
        "
    } 5
    Write-Host "[CLICK SIGN IN] $clickResult"
    Start-Sleep 8
}

# Check where we are now
$currentUrl = CDP-SR $ws "Runtime.evaluate" @{expression="window.location.href"} 6
Write-Host "[CURRENT URL] $currentUrl"

# Step 2: Go to Personal Access Tokens page
CDP-SR $ws "Page.navigate" @{url="https://github.com/settings/tokens/new"} 7
Start-Sleep 6

$tokenUrl = CDP-SR $ws "Runtime.evaluate" @{expression="window.location.href"} 8
Write-Host "[TOKEN PAGE URL] $tokenUrl"

$tokenBody = CDP-SR $ws "Runtime.evaluate" @{expression="document.body.innerText.slice(0,3000)"} 9
Write-Host "=== TOKEN PAGE ==="
Write-Host $tokenBody

# Fill in PAT creation form
if ($tokenUrl -match "tokens/new" -or $tokenBody.Length -gt 100) {
    # Fill description
    $fillDesc = CDP-SR $ws "Runtime.evaluate" @{
        expression="
            var descInput = document.querySelector('#token_description') || document.querySelector('[name=description]') || document.querySelector('input[placeholder*=description]') || document.querySelector('input[placeholder*=描述]');
            if (descInput) { descInput.value = 'OEWA OpenClaw Integration'; 'desc set: ' + descInput.id; }
            else { 'no desc input' }
        "
    } 10
    Write-Host "[DESC] $fillDesc"
    Start-Sleep 0.5
    
    # Check all checkboxes for scopes (need repo scope)
    $checkScopes = CDP-SR $ws "Runtime.evaluate" @{
        expression="
            var scopes = ['repo', 'workflow', 'read:org', 'gist'];
            var checkboxes = document.querySelectorAll('input[type=checkbox]');
            var checked = [];
            for (var cb of checkboxes) {
                checked.push(cb.name || cb.id || cb.parentElement?.innerText?.trim()?.substring(0,30));
            }
            JSON.stringify(checked.slice(0,20));
        "
    } 11
    Write-Host "[CHECKBOXES] $checkScopes"
    
    # Select repo scope
    $selectRepo = CDP-SR $ws "Runtime.evaluate" @{
        expression="
            var cbs = document.querySelectorAll('input[type=checkbox]');
            for (var cb of cbs) {
                var name = (cb.name || '').toLowerCase();
                var label = (cb.parentElement?.innerText || '').toLowerCase();
                if (name.includes('repo') || label.includes('repo')) {
                    if (!cb.checked) cb.click();
                }
            }
            'repo scope attempted';
        "
    } 12
    Write-Host "[REPO SCOPE] $selectRepo"
    Start-Sleep 1
    
    # Click generate button
    $genBtn = CDP-SR $ws "Runtime.evaluate" @{
        expression="
            var btns = document.querySelectorAll('button, [type=submit]');
            var genText = ['generate', '创建', '生成', '提交', '创建令牌'];
            for (var b of btns) {
                var t = (b.innerText || '').trim().toLowerCase();
                if (genText.some(x => t.includes(x))) {
                    b.click();
                    return 'Clicked: ' + b.innerText.trim() + ' id:' + b.id;
                }
            }
            'no generate btn found. All btns: ' + Array.from(btns).map(b=>b.innerText.trim()).filter(t=>t).slice(0,5).join(',');
        "
    } 13
    Write-Host "[GENERATE] $genBtn"
    Start-Sleep 5
}

# Get the generated token
$tokenResult = CDP-SR $ws "Runtime.evaluate" @{
    expression="
        // Look for the token in the page
        var scripts = document.querySelectorAll('script');
        var tokenEl = document.querySelector('[data-token]') || document.querySelector('.token') || document.querySelector('.copy-token');
        var readonlyInputs = document.querySelectorAll('input[readonly]');
        var results = [];
        for (var inp of readonlyInputs) {
            if (inp.value && inp.value.length > 20) results.push(inp.value);
        }
        // Also check for clipboard data
        var cloneArea = document.querySelector('.clone textarea') || document.querySelector('.token-field');
        if (results.length > 0) JSON.stringify(results);
        else document.body.innerText.match(/ghp_[a-zA-Z0-9]{36}|github_pat_[a-zA-Z0-9_]{22,}/)?.[0] || 'token not found in page';
    "
} 14
Write-Host "[TOKEN RESULT] $tokenResult"

# Take screenshot for debugging
# CDP-SR $ws "Page.captureScreenshot" @{} 15

try { $ws.CloseAsync('NormalClosure', "", [Threading.CancellationToken]::None).Wait(1000) } catch {}
Write-Host "[DONE]"