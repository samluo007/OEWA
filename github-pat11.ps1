# GitHub PAT - parse JSON properly, then click the button
$debugPort = 9222
$ghTabId = "01848BFDCAD4BCD89B4AE8883698F445"
$wsUrl = "ws://localhost:$debugPort/devtools/page/$ghTabId"

function CDP {
    param($ws, $method, $params=@{}, $id=1)
    $msg = @{id=$id;method=$method;params=$params} | ConvertTo-Json -Compress
    $bytes = [Text.Encoding]::UTF8.GetBytes($msg)
    try {
        $ws.SendAsync([ArraySegment[byte]]$bytes, 'Text', $true, [Threading.CancellationToken]::None).Wait(8000)
        Start-Sleep -Milliseconds 300
        $buf = [byte[]]::new(16384)
        $ws.ReceiveAsync([ArraySegment[byte]]$buf, [Threading.CancellationToken]::None).Wait(8000) | Out-Null
        $result = [Text.Encoding]::UTF8.GetString($buf).TrimEnd([char]0)
        $j = $result | ConvertFrom-Json -EA SilentlyContinue
        if ($j.result.result.value) { return $j.result.result.value }
        if ($j.result -is [string]) { return $j.result }
        return $result
    } catch { Write-Host "[CDP ERROR] $_"; return "{}" }
}

$ws = New-Object System.Net.WebSockets.ClientWebSocket
$ws.ConnectAsync([Uri]$wsUrl, [Threading.CancellationToken]::None).Wait(10000)
Write-Host "[WS CONNECTED]"

# Get button info
$btnPosRaw = CDP $ws "Runtime.evaluate" @{
    expression="
        (function() {
            var btns = Array.from(document.querySelectorAll('button'));
            var genBtn = btns.find(function(b) { return (b.innerText||'').trim().toLowerCase().indexOf('generate') !== -1; });
            if (genBtn) {
                var r = genBtn.getBoundingClientRect();
                return JSON.stringify({
                    viewY: r.y, cx: r.x+r.width/2, cy: r.y+r.height/2,
                    vis: r.y >= 0 && r.y+r.height <= window.innerHeight
                });
            }
            return 'NO_BTN';
        })()
    "
} 1
Write-Host "[BTN RAW] $btnPosRaw"

# Parse as JSON
$btnPos = $btnPosRaw | ConvertFrom-Json -EA SilentlyContinue
if ($btnPos -and $btnPos.vis) {
    $cx = [double]$btnPos.cx
    $cy = [double]$btnPos.cy
    Write-Host "[Clicking at cx=$cx cy=$cy]"
    
    # Mouse move
    CDP $ws "Input.dispatchMouseEvent" @{type="mouseMoved";x=$cx;y=$cy;button="left";clickCount=0} 2 | Out-Null
    Start-Sleep 0.5
    
    # Mouse press
    CDP $ws "Input.dispatchMouseEvent" @{type="mousePressed";x=$cx;y=$cy;button="left";clickCount=1} 3 | Out-Null
    Start-Sleep 0.3
    
    # Mouse release
    CDP $ws "Input.dispatchMouseEvent" @{type="mouseReleased";x=$cx;y=$cy;button="left";clickCount=1} 4 | Out-Null
    
    Write-Host "[CLICK SENT]"
    Start-Sleep 8
    
    # Check result
    $url = CDP $ws "Runtime.evaluate" @{expression="window.location.href"} 5
    $body = CDP $ws "Runtime.evaluate" @{expression="document.body.innerText.slice(0,3000)"} 6
    Write-Host "[URL] $url"
    Write-Host "=== BODY ==="
    Write-Host $body
    
    # Token check
    $tok = CDP $ws "Runtime.evaluate" @{
        expression="
            (function() {
                var txt = document.body.innerText;
                var m = txt.match(/ghp_[a-zA-Z0-9]{36}/);
                if (m) return 'TOKEN:' + m[0];
                return 'NO_TOKEN';
            })()
        "
    } 7
    Write-Host "[TOKEN] $tok"
    
    if ($tok -match 'ghp_[a-zA-Z0-9]{36}') {
        $token = ($tok -replace '.*?(ghp_[a-zA-Z0-9]{36}).*','$1')
        $token | Out-File -FilePath "$env:USERPROFILE\.qclaw\oe_github_token.txt" -Encoding UTF8
        Write-Host "[TOKEN SAVED: $token]"
    }
} else {
    Write-Host "[BTN NOT VISIBLE - $btnPosRaw]"
}

try { $ws.CloseAsync('NormalClosure','',[Threading.CancellationToken]::None).Wait(2000) } catch {}
Write-Host "[DONE]"