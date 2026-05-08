# OEWA GitHub OAuth v5 - Click connect button properly
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

# Start fresh - go to gateway
CDP-SR $ws "Page.navigate" @{url="http://127.0.0.1:28789"} 1
Start-Sleep 3

# Focus and type token using CDP Input domain
$focusToken = CDP-SR $ws "Runtime.evaluate" @{
    expression="
        var inputs = document.querySelectorAll('input');
        var inp = inputs[1]; // token field (password type)
        if (inp) {
            inp.focus();
            'focused: ' + inp.placeholder;
        } else { 'no input[1]' }
    "
} 2
Write-Host "[FOCUS] $focusToken"

# Use CDP Input.dispatchKeyEvent to type character by character
$token = "d7006d7239e4fa61c3b0e7e13ce4fe1ef4cbdc98acf7a9c1"
$charId = 10
foreach ($ch in $token.ToCharArray()) {
    CDP-SR $ws "Input.dispatchKeyEvent" @{
        type="keyDown"
        text=$ch
        key=$ch
        keyCode=[int]$ch -eq 61 -or [int]$ch -ge 48 -and [int]$ch -le 57 -or [int]$ch -ge 97 -and [int]$ch -le 102
    } $charId
    CDP-SR $ws "Input.dispatchKeyEvent" @{
        type="keyUp"
        text=$ch
        key=$ch
        keyCode=[int]$ch -eq 61 -or [int]$ch -eq 45
    } ($charId + 1)
    $charId += 2
    Start-Sleep -Milliseconds 30
}

# Verify what's in the input field
$verifyToken = CDP-SR $ws "Runtime.evaluate" @{expression="document.querySelectorAll('input')[1].value"} 20
Write-Host "[VERIFY TOKEN] $verifyToken"
Start-Sleep 1

# Now click the connect button by class name
$clickBtn = CDP-SR $ws "Runtime.evaluate" @{
    expression="
        var btn = document.querySelector('.login-gate__connect');
        if (btn) {
            btn.click();
            'Clicked .login-gate__connect: ' + btn.innerText;
        } else {
            'button not found';
        }
    "
} 21
Write-Host "[CLICK BTN] $clickBtn"
Start-Sleep 5

# Check URL and page
$url = CDP-SR $ws "Runtime.evaluate" @{expression="window.location.href"} 22
Write-Host "[URL] $url"

$body = CDP-SR $ws "Runtime.evaluate" @{expression="document.body.innerText.slice(0,2000)"} 23
Write-Host "=== PAGE ==="
Write-Host $body

# If connected, look for GitHub integration
if ($url -match 'chat\?session=main') {
    Write-Host "[CONNECTED] Now looking for integrations..."
    
    # Find navigation or settings links
    $navLinks = CDP-SR $ws "Runtime.evaluate" @{
        expression="
            var links = document.querySelectorAll('a, [role=button], button');
            JSON.stringify(Array.from(links).map(e=>({t:e.innerText?.trim(),h:e.href,cl:e.className,tag:e.tagName})).filter(e=>e.t&&e.t.length<50).slice(0,20));
        "
    } 24
    Write-Host "[NAV LINKS] $navLinks"
    
    # Try navigating to integrations page
    CDP-SR $ws "Page.navigate" @{url="http://127.0.0.1:28789/integrations"} 25
    Start-Sleep 4
    
    $body2 = CDP-SR $ws "Runtime.evaluate" @{expression="document.body.innerText.slice(0,3000)"} 26
    Write-Host "=== INTEGRATIONS PAGE ==="
    Write-Host $body2
    
    # Look for GitHub button
    $ghItems = CDP-SR $ws "Runtime.evaluate" @{
        expression="
            var cards = document.querySelectorAll('.card, .item, .integration-card, button');
            JSON.stringify(Array.from(cards).map(e=>({t:e.innerText?.trim(),c:e.className})).filter(e=>e.t&&(e.t.includes('github')||e.t.includes('GitHub')||e.t.includes('授权')||e.t.includes('Connect'))).slice(0,10));
        "
    } 27
    Write-Host "[GITHUB ITEMS] $ghItems"
}

try { $ws.CloseAsync('NormalClosure', "", [Threading.CancellationToken]::None).Wait(1000) } catch {}
Write-Host "[DONE]"