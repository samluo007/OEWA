# OEWA GitHub OAuth v4 - Connect gateway then find integrations
$debugPort = 9222

function CDP-SR {
    param($ws, $method, $params=@{}, $id=1)
    $msg = @{id=$id; method=$method; params=$params} | ConvertTo-Json -Compress
    $bytes = [Text.Encoding]::UTF8.GetBytes($msg)
    $ws.SendAsync([ArraySegment[byte]]$bytes, 'Text', $true, [Threading.CancellationToken]::None).Wait(6000)
    Start-Sleep -Milliseconds 300
    $buf = [byte[]]::new(16384)
    try { $ws.ReceiveAsync([ArraySegment[byte]]$buf, [Threading.CancellationToken]::None).Wait(6000) | Out-Null } catch {}
    [Text.Encoding]::UTF8.GetString($buf).TrimEnd([char]0)
}

$pages = Invoke-RestMethod "http://localhost:$debugPort/json" -TimeoutSec 5
$opTab = $pages | Where-Object { $_.title -eq "OpenClaw Control" } | Select-Object -First 1
$wsUrl = $opTab.webSocketDebuggerUrl

$ws = New-Object System.Net.WebSockets.ClientWebSocket
$ws.ConnectAsync([Uri]$wsUrl, [Threading.CancellationToken]::None).Wait(8000)
Write-Host "[WS OK]"

# Navigate to gateway
CDP-SR $ws "Page.navigate" @{url="http://127.0.0.1:28789"} 1
Start-Sleep 3

# Type token into the password field (index 1 = token input)
$typeResult = CDP-SR $ws "Runtime.evaluate" @{
    expression="
        var inputs = document.querySelectorAll('input');
        var tokenInput = inputs[1];
        if (tokenInput) {
            tokenInput.value = 'd7006d7239e4fa61c3b0e7e13ce4fe1ef4cbdc98acf7a9c1';
            tokenInput.dispatchEvent(new Event('input', {bubbles:true}));
            tokenInput.dispatchEvent(new Event('change', {bubbles:true}));
            'Token typed into: ' + inputs[1].placeholder;
        } else {
            'No token input found';
        }
    "
} 2
Write-Host "[TYPE TOKEN] $typeResult"
Start-Sleep 1

# Click the connect button (text = "连接")
$clickResult = CDP-SR $ws "Runtime.evaluate" @{
    expression="
        var btns = document.querySelectorAll('button');
        var connBtn = null;
        for (var b of btns) {
            if (b.innerText.trim() === '连接') { connBtn = b; break; }
        }
        if (connBtn) {
            connBtn.click();
            'Clicked connect button';
        } else {
            'Connect button not found. Buttons: ' + Array.from(btns).map(b=>b.innerText.trim()).join(',');
        }
    "
} 3
Write-Host "[CLICK] $clickResult"
Start-Sleep 5

# Check current URL and page content
$url = CDP-SR $ws "Runtime.evaluate" @{expression="window.location.href"} 4
Write-Host "[URL] $url"

# Get page text to see what loaded after connect
$bodyText = CDP-SR $ws "Runtime.evaluate" @{expression="document.body.innerText.slice(0,2000)"} 5
Write-Host "=== PAGE TEXT ==="
Write-Host $bodyText

# Try to find GitHub connection button
$ghBtn = CDP-SR $ws "Runtime.evaluate" @{
    expression="
        var els = document.querySelectorAll('button, [role=button], a, .item, .card');
        var matches = [];
        for (var e of els) {
            var t = e.innerText?.trim() || '';
            if (t.includes('github') || t.includes('GitHub') || t.includes('Github') || t.includes('授权')) {
                matches.push(t + ' | class:' + e.className + ' | tag:' + e.tagName);
            }
        }
        JSON.stringify(matches.slice(0,10));
    "
} 6
Write-Host "[GITHUB BTNS] $ghBtn"

# Get ALL interactive elements
$allEls = CDP-SR $ws "Runtime.evaluate" @{
    expression="
        var els = document.querySelectorAll('button, a, [role=button], .btn, .card, .item, .integration');
        JSON.stringify(Array.from(els).map(e=>({t:e.innerText?.trim(),h:e.href,c:e.className,tag:e.tagName})).filter(e=>e.t&&e.t.length>0).slice(0,30));
    "
} 7
Write-Host "[ALL ELEMENTS] $allEls"

try { $ws.CloseAsync('NormalClosure', "", [Threading.CancellationToken]::None).Wait(1000) } catch {}
Write-Host "[DONE]"