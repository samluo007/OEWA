# OEWA GitHub OAuth v3 - Connect to Gateway then navigate to integrations
$debugPort = 9222

function CDP-SR {
    param($ws, $method, $params=@{}, $id=1)
    $msg = @{id=$id; method=$method; params=$params} | ConvertTo-Json -Compress
    $bytes = [Text.Encoding]::UTF8.GetBytes($msg)
    $ws.SendAsync([ArraySegment[byte]]$bytes, 'Text', $true, [Threading.CancellationToken]::None).Wait(6000)
    Start-Sleep -Milliseconds 500
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

# Find input fields and connect button
$inputs = CDP-SR $ws "Runtime.evaluate" @{expression="JSON.stringify(Array.from(document.querySelectorAll('input')).map(e=>({id:e.id,name:e.name,type:e.type,placeholder:e.placeholder})))"} 2
Write-Host "=== INPUTS ==="
Write-Host $inputs

$btns = CDP-SR $ws "Runtime.evaluate" @{expression="JSON.stringify(Array.from(document.querySelectorAll('button')).map(e=>({id:e.id,text:e.innerText.trim(),disabled:e.disabled})))"} 3
Write-Host "=== BUTTONS ==="
Write-Host $btns

# Enter the gateway token
$tokenInput = CDP-SR $ws "Runtime.evaluate" @{expression="(Array.from(document.querySelectorAll('input')).find(i=>i.placeholder?.includes('token')||i.placeholder?.includes('令牌')||i.name?.includes('token'))||null)?.id"} 4
Write-Host "[TOKEN INPUT] $tokenInput"

if ($tokenInput -match '"value":"([^"]+)"') {
    $inputId = $Matches[1]
    Write-Host "Found token input: $inputId"
    
    # Type the token
    CDP-SR $ws "Input.dispatchKeyEvent" @{type="keyDown"; text="d7006d7239e4fa61c3b0e7e13ce4fe1ef4cbdc98acf7a9c1"; key="d"} 5
    Start-Sleep 1
}

# Try typing into any input with placeholder containing "token"
$typeToken = CDP-SR $ws "Runtime.evaluate" @{
    expression="
        var inp = Array.from(document.querySelectorAll('input')).find(i => 
            (i.placeholder && i.placeholder.includes('token')) || 
            (i.placeholder && i.placeholder.includes('Token')) ||
            (i.placeholder && i.placeholder.includes('令牌'))
        );
        if (inp) { inp.value = 'd7006d7239e4fa61c3b0e7e13ce4fe1ef4cbdc98acf7a9c1'; inp.dispatchEvent(new Event('input',{bubbles:true})); inp.dispatchEvent(new Event('change',{bubbles:true})); 'typed:' + inp.id; } 
        else { 'no input found' }
    "
} 5
Write-Host "[TYPE TOKEN] $typeToken"
Start-Sleep 1

# Find and click connect button
$connectBtn = CDP-SR $ws "Runtime.evaluate" @{
    expression="JSON.stringify(Array.from(document.querySelectorAll('button, [role=button]')).map(e=>({id:e.id,text:e.innerText.trim()})))"
} 6
Write-Host "[ALL BUTTONS] $connectBtn"

# Click the connect button
$clickConn = CDP-SR $ws "Runtime.evaluate" @{
    expression="
        var btn = Array.from(document.querySelectorAll('button, [role=button]')).find(e => 
            e.innerText.includes('连接') || 
            e.innerText.includes('Connect') ||
            e.innerText.includes('connect')
        );
        if (btn) { btn.click(); 'clicked:' + btn.id + ':' + btn.innerText.trim(); } 
        else { 'no connect button found' }
    "
} 7
Write-Host "[CLICK CONNECT] $clickConn"
Start-Sleep 3

# After connecting, look for integrations/navigation
$navLinks = CDP-SR $ws "Runtime.evaluate" @{
    expression="JSON.stringify(Array.from(document.querySelectorAll('a')).map(e=>({href:e.href,text:e.innerText.trim(),class:e.className})).filter(e=>e.href).slice(0,20))"
} 8
Write-Host "[NAV LINKS] $navLinks"

try { $ws.CloseAsync('NormalClosure', "", [Threading.CancellationToken]::None).Wait(1000) } catch {}
Write-Host "[DONE]"