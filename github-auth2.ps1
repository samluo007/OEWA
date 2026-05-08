# OEWA GitHub OAuth - Better Page Exploration
$debugPort = 9222

function Get-EDGETabs {
    $pages = Invoke-RestMethod "http://localhost:$debugPort/json" -TimeoutSec 5
    $pages | Where-Object { $_.type -eq "page" } | Select-Object id, title, url | Format-Table -AutoSize | Out-String
}

function CDP-Send-Recv {
    param($ws, $method, $params=@{}, $id=1)
    $msg = @{id=$id; method=$method; params=$params} | ConvertTo-Json -Compress
    $bytes = [Text.Encoding]::UTF8.GetBytes($msg)
    $ws.SendAsync([ArraySegment[byte]]$bytes, 'Text', $true, [Threading.CancellationToken]::None).Wait(6000)
    Start-Sleep -Milliseconds 500
    $buf = [byte[]]::new(8192)
    try { $ws.ReceiveAsync([ArraySegment[byte]]$buf, [Threading.CancellationToken]::None).Wait(6000) | Out-Null } catch {}
    [Text.Encoding]::UTF8.GetString($buf).TrimEnd([char]0)
}

# Find the OpenClaw page
$pages = Invoke-RestMethod "http://localhost:$debugPort/json" -TimeoutSec 5
$opTab = $pages | Where-Object { $_.title -eq "OpenClaw Control" } | Select-Object -First 1

if (-not $opTab) {
    # Try to create new page
    try {
        $newTab = Invoke-RestMethod "http://localhost:$debugPort/json/new" -TimeoutSec 5
        $opTab = @{"id"=$newTab.id; "webSocketDebuggerUrl"=$newTab.webSocketDebuggerUrl}
    } catch {
        # Use first available page
        $opTab = ($pages | Where-Object { $_.type -eq "page" -and $_.url -notlike "chrome://*" -and $_.url -notlike "edge://*" } | Select-Object -First 1)
    }
}

$wsUrl = $opTab.webSocketDebuggerUrl
Write-Host "Using tab: $($opTab.title) | $($opTab.id)"

$ws = New-Object System.Net.WebSockets.ClientWebSocket
$ws.ConnectAsync([Uri]$wsUrl, [Threading.CancellationToken]::None).Wait(8000)
if ($ws.State -ne 'Open') { Write-Host "WS failed"; exit 1 }
Write-Host "[WS OK]"

# Navigate to OpenClaw integrations
$nav = CDP-Send-Recv $ws "Page.navigate" @{url="http://127.0.0.1:28789/integrations"} 1
Write-Host "[NAV] $nav"
Start-Sleep 5

# Get page title and all interactive elements
$title = CDP-Send-Recv $ws "Runtime.evaluate" @{expression="document.title"} 2
Write-Host "[TITLE] $title"

# Get all text content and buttons
$body = CDP-Send-Recv $ws "Runtime.evaluate" @{expression="document.body.innerText.slice(0,3000)"} 3
Write-Host "=== PAGE TEXT ==="
Write-Host $body

# Get all buttons/links with their text
$elements = CDP-Send-Recv $ws "Runtime.evaluate" @{expression="JSON.stringify(Array.from(document.querySelectorAll('button, [role=button], .btn, .button, a')).filter(e=>e.offsetParent!==null).map(e=>({t:e.innerText?.trim(),h:e.href,c:e.className,id:e.id})).filter(e=>e.t).slice(0,30))"} 4
Write-Host "=== ELEMENTS ==="
if ($elements -match '"t":"([^"]*)"') { Write-Host $elements }

# Get page source to find structure
$src = CDP-Send-Recv $ws "Runtime.evaluate" @{expression="document.documentElement.outerHTML.slice(0,8000)"} 5
Write-Host "=== HTML SNIPPET ==="
Write-Host $src.Substring(0, [Math]::Min(4000, $src.Length))

try { $ws.CloseAsync('NormalClosure', "", [Threading.CancellationToken]::None).Wait(1000) } catch {}
Write-Host "[DONE]"