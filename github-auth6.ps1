# OEWA GitHub OAuth v6 - Connected! Navigate to GitHub integration
$debugPort = 9222
$token = "d7006d7239e4fa61c3b0e7e13ce4fe1ef4cbdc98acf7a9c1"

function CDP-SR {
    param($ws, $method, $params=@{}, $id=1)
    $msg = @{id=$id; method=$method; params=$params} | ConvertTo-Json -Compress
    $bytes = [Text.Encoding]::UTF8.GetBytes($msg)
    $ws.SendAsync([ArraySegment[byte]]$bytes, 'Text', $true, [Threading.CancellationToken]::None).Wait(6000)
    Start-Sleep -Milliseconds 200
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

# Navigate to gateway - this should now connect with saved token
CDP-SR $ws "Page.navigate" @{url="http://127.0.0.1:28789"} 1
Start-Sleep 3

# Check URL - should be connected now
$url = CDP-SR $ws "Runtime.evaluate" @{expression="window.location.href"} 2
Write-Host "[URL] $url"

# Get page
$body = CDP-SR $ws "Runtime.evaluate" @{expression="document.body.innerText.slice(0,500)"} 3
Write-Host "[BODY] $body"

# Try different integration URLs
$integrationUrls = @(
    "http://127.0.0.1:28789/integrations",
    "http://127.0.0.1:28789/channels",
    "http://127.0.0.1:28789/communications", 
    "http://127.0.0.1:28789/config",
    "http://127.0.0.1:28789/agents"
)

foreach ($intUrl in $integrationUrls) {
    Write-Host "`n=== Testing: $intUrl ==="
    CDP-SR $ws "Page.navigate" @{url=$intUrl} 100
    Start-Sleep 3
    
    $pageBody = CDP-SR $ws "Runtime.evaluate" @{expression="document.body.innerText.slice(0,2000)"} 101
    Write-Host $pageBody
    
    # Look for GitHub related content
    if ($pageBody -match "github|GitHub|授权|OAuth|集成|integration") {
        Write-Host "[*** FOUND GitHub related content on this page ***]"
        
        # Try to click the GitHub connect button
        $ghClick = CDP-SR $ws "Runtime.evaluate" @{
            expression="
                var allEls = document.querySelectorAll('*');
                var results = [];
                for (var e of allEls) {
                    var t = (e.innerText || '').trim();
                    if (t && (t.includes('GitHub') || t.includes('github') || t.includes('授权'))) {
                        results.push('tag:' + e.tagName + ' text:' + t.substring(0,200) + ' id:' + e.id + ' class:' + e.className);
                    }
                }
                JSON.stringify(results.slice(0,10));
            "
        } 102
        Write-Host "[GH CONTENT] $ghClick"
    }
    
    Start-Sleep 1
}

try { $ws.CloseAsync('NormalClosure', "", [Threading.CancellationToken]::None).Wait(1000) } catch {}
Write-Host "[DONE]"