# OEWA GitHub OAuth v7 - Use NEW tab to access integration panel
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

# Create a NEW clean tab
try {
    $newTab = Invoke-RestMethod "http://localhost:$debugPort/json/new" -TimeoutSec 5
    $tabId = $newTab.id
    $wsUrl = $newTab.webSocketDebuggerUrl
    Write-Host "[NEW TAB] id=$tabId"
} catch {
    Write-Host "[ERROR] Could not create new tab: $_"
    exit 1
}

# Connect to new tab
$ws = New-Object System.Net.WebSockets.ClientWebSocket
$ws.ConnectAsync([Uri]$wsUrl, [Threading.CancellationToken]::None).Wait(8000)
if ($ws.State -ne 'Open') { Write-Host "WS fail"; exit 1 }
Write-Host "[WS OK]"

# Navigate to integrations panel
CDP-SR $ws "Page.navigate" @{url="http://127.0.0.1:28789/integrations"} 1
Start-Sleep 4

# Check where we are
$url = CDP-SR $ws "Runtime.evaluate" @{expression="window.location.href"} 2
Write-Host "[URL] $url"

$title = CDP-SR $ws "Runtime.evaluate" @{expression="document.title"} 3
Write-Host "[TITLE] $title"

# Get all page content
$body = CDP-SR $ws "Runtime.evaluate" @{expression="document.body.innerText.slice(0,3000)"} 4
Write-Host "=== PAGE TEXT ==="
Write-Host $body

# Get all clickable elements
$allEls = CDP-SR $ws "Runtime.evaluate" @{
    expression="
        JSON.stringify(Array.from(document.querySelectorAll('a, button, [role=button], .item, .card, .nav-item')).map(e=>({
            t: e.innerText?.trim(),
            h: e.href,
            c: e.className,
            tag: e.tagName
        })).filter(e=>e.t || e.h).slice(0,30));
    "
} 5
Write-Host "=== ELEMENTS ==="
Write-Host $allEls

# Search entire DOM for GitHub text
$githubDom = CDP-SR $ws "Runtime.evaluate" @{
    expression="
        var all = document.querySelectorAll('*');
        var found = [];
        for (var el of all) {
            var walker = document.createTreeWalker(el, NodeFilter.SHOW_TEXT, null, false);
            while(walker.nextNode()) {
                var t = walker.currentNode.textContent.trim();
                if (t && (t.includes('GitHub') || t.includes('github') || t.includes('github'))) {
                    found.push(el.tagName + ':' + el.className + ':' + t.substring(0,100));
                    break;
                }
            }
        }
        JSON.stringify(found.slice(0,20));
    "
} 6
Write-Host "=== DOM GITHUB ==="
Write-Host $githubDom

# Check if there's an integrations/skill settings area
$iframes = CDP-SR $ws "Runtime.evaluate" @{
    expression="JSON.stringify(Array.from(document.querySelectorAll('iframe')).map(f=>({src:f.src,id:f.id})))"
} 7
Write-Host "[IFRAMES] $iframes"

try { $ws.CloseAsync('NormalClosure', "", [Threading.CancellationToken]::None).Wait(1000) } catch {}
Write-Host "[DONE]"