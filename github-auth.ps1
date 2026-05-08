# OEWA GitHub OAuth Browser Automation
# Uses existing Edge debug port to complete GitHub OAuth

$debugPort = 9222
$targetPage = $null

# Find a usable page (skip chrome:// and edge:// URLs)
$pages = Invoke-RestMethod "http://localhost:$debugPort/json" -TimeoutSec 5
$targetPage = $pages | Where-Object { $_.type -eq "page" -and $_.url -notlike "chrome://*" -and $_.url -notlike "edge://*" } | Select-Object -First 1

if (-not $targetPage) {
    Write-Host "[INFO] No usable page found, opening new tab"
    # Navigate to OpenClaw control panel
    $newPage = Invoke-RestMethod "http://localhost:$debugPort/json/new" -TimeoutSec 5
    $targetPage = @{"id"=$newPage.id; "webSocketDebuggerUrl"=$newPage.webSocketDebuggerUrl}
} else {
    Write-Host "[INFO] Using existing page: $($targetPage.title)"
}

$wsUrl = $targetPage.webSocketDebuggerUrl

function Send-CDP {
    param($ws, $method, $params=[ordered]@{}, $id=1)
    $msg = @{id=$id; method=$method; params=$params} | ConvertTo-Json -Compress
    $bytes = [Text.Encoding]::UTF8.GetBytes($msg)
    $ws.SendAsync([ArraySegment[byte]]$bytes, 'Text', $true, [Threading.CancellationToken]::None).Wait(5000)
    Start-Sleep -Milliseconds 200
}

function Recv-CDP {
    param($ws)
    $buf = [byte[]]::new(8192)
    try {
        $r = $ws.ReceiveAsync([ArraySegment[byte]]$buf, [Threading.CancellationToken]::None).Wait(5000)
        if ($r) { [Text.Encoding]::UTF8.GetString($buf).TrimEnd([char]0) } else { "" }
    } catch { "" }
}

# Connect WebSocket
$ws = New-Object System.Net.WebSockets.ClientWebSocket
$ws.ConnectAsync([Uri]$wsUrl, [Threading.CancellationToken]::None).Wait(8000)

if ($ws.State -ne 'Open') {
    Write-Host "[ERROR] WebSocket not connected: $($ws.State)"
    exit 1
}

Write-Host "[OK] Connected to CDP"

# Navigate to OpenClaw
Send-CDP $ws "Page.navigate" @{url="http://127.0.0.1:28789"}
Start-Sleep 4

# Get DOM
Send-CDP $ws "DOM.getDocument" @{} 1
$r = Recv-CDP $ws
Write-Host "[PAGE LOADED]"

# Try to find integration elements - look for GitHub authorization button
# First check if page loaded
Send-CDP $ws "Runtime.evaluate" @{expression="document.title"} 2
$r2 = Recv-CDP $ws
if ($r2 -match '"result"') {
    $title = ([regex]'("result":\s*"([^"]*)")').Match($r2).Groups[2].Value
    Write-Host "[PAGE TITLE] $title"
}

# Check local storage for auth tokens
Send-CDP $ws "Runtime.evaluate" @{expression="localStorage.getItem('github') || localStorage.getItem('integrations') || localStorage.getItem('token') || 'none'"} 3
$r3 = Recv-CDP $ws

# Try to get page HTML to find buttons
Send-CDP $ws "Runtime.evaluate" @{expression="Array.from(document.querySelectorAll('button, a')).map(e=>({text:e.innerText, href:e.href||'', class:e.className})).filter(e=>e.text.length>0).slice(0,20).map(e=>e.text+':'+e.href).join('\n')"} 4
$r4 = Recv-CDP $ws

Write-Host "=== Buttons found ==="
Write-Host $r4

# Try clicking GitHub button
Send-CDP $ws "Runtime.evaluate" @{expression="(Array.from(document.querySelectorAll('button, a')).find(e=>e.innerText.includes('GitHub')||e.innerText.includes('github')||e.innerText.includes('授权')||e.innerText.includes('连接'))||{id:null})?.id"} 5
$r5 = Recv-CDP $ws
if ($r5 -match '"value":"([^"]+)"') {
    $btnId = $Matches[1]
    Write-Host "[FOUND] GitHub button id: $btnId"
    Send-CDP $ws "Runtime.evaluate" @{expression="document.getElementById('$btnId')?.click()"} 6
    Start-Sleep 3
    Write-Host "[CLICKED] GitHub button"
}

$ws.CloseAsync('NormalClosure', "", [Threading.CancellationToken]::None).Wait(2000)
Write-Host "[DONE]"