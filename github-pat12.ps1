# GitHub PAT - fix JSON parsing, click the button, generate token
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
        if ($j.result.result.value) { return $j.result.result.value.ToString() }
        if ($j.result -is [string]) { return $j.result.ToString() }
        return $result
    } catch { Write-Host "[CDP ERROR] $_"; return "{}" }
}

$ws = New-Object System.Net.WebSockets.ClientWebSocket
$ws.ConnectAsync([Uri]$wsUrl, [Threading.CancellationToken]::None).Wait(10000)
Write-Host "[WS CONNECTED]"

# Verify URL
$url = CDP $ws "Runtime.evaluate" @{expression="window.location.href"} 1
Write-Host "[URL] $url"

# Get button info - strip the "True " prefix from CDP wrapper
$btnRaw = CDP $ws "Runtime.evaluate" @{
    expression="
        (function() {
            var btns = Array.from(document.querySelectorAll('button'));
            var genBtn = btns.find(function(b) { return (b.innerText||'').trim().toLowerCase().indexOf('generate') !== -1; });
            if (genBtn) {
                var r = genBtn.getBoundingClientRect();
                return JSON.stringify({viewY: r.y, cx: r.x+r.width/2, cy: r.y+r.height/2, vis: r.y >= 0 && r.y+r.height <= window.innerHeight});
            }
            return 'NO_BTN';
        })()
    "
} 2
Write-Host "[BTN RAW] $btnRaw"

# Strip "True " prefix then parse JSON
$jsonStr = $btnRaw -replace '^True\s*', ''
$btnPos = $jsonStr | ConvertFrom-Json -EA SilentlyContinue

if ($btnPos -and $btnPos.vis) {
    $cx = [double]$btnPos.cx
    $cy = [double]$btnPos.cy
    Write-Host "[Clicking Generate button at cx=$cx cy=$cy]"
    
    CDP $ws "Input.dispatchMouseEvent" @{type="mouseMoved";x=$cx;y=$cy;button="left";clickCount=0} 3 | Out-Null
    Start-Sleep 0.5
    CDP $ws "Input.dispatchMouseEvent" @{type="mousePressed";x=$cx;y=$cy;button="left";clickCount=1} 4 | Out-Null
    Start-Sleep 0.3
    CDP $ws "Input.dispatchMouseEvent" @{type="mouseReleased";x=$cx;y=$cy;button="left";clickCount=1} 5 | Out-Null
    
    Write-Host "[CLICK SENT, waiting 10s for token...]"
    Start-Sleep 10
    
    $url2 = CDP $ws "Runtime.evaluate" @{expression="window.location.href"} 6
    $body2 = CDP $ws "Runtime.evaluate" @{expression="document.body.innerText.slice(0,4000)"} 7
    Write-Host "[URL2] $url2"
    Write-Host "=== PAGE ==="
    Write-Host $body2
    
    # Token check
    $tokRaw = CDP $ws "Runtime.evaluate" @{
        expression="
            (function() {
                var txt = document.body.innerText;
                var m = txt.match(/ghp_[a-zA-Z0-9]{36}/);
                return m ? 'HAS_TOKEN:' + m[0] : 'NO_TOKEN';
            })()
        "
    } 8
    Write-Host "[TOKEN CHECK] $tokRaw"
    
    if ($tokRaw -match 'HAS_TOKEN:(ghp_[a-zA-Z0-9]{36})') {
        $token = $matches[1]
        $token | Out-File -FilePath "$env:USERPROFILE\.qclaw\oe_github_token.txt" -Encoding UTF8
        Write-Host "[SUCCESS! TOKEN SAVED: $token]"
    } else {
        Write-Host "[TOKEN NOT YET GENERATED - page may need more interaction]"
    }
} else {
    Write-Host "[BTN NOT VISIBLE - need to scroll first]"
    if ($btnPos) {
        Write-Host "[viewY=$($btnPos.viewY)]"
    }
}

try { $ws.CloseAsync('NormalClosure','',[Threading.CancellationToken]::None).Wait(2000) } catch {}
Write-Host "[DONE]"