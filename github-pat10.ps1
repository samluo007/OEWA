# GitHub PAT - scroll button into viewport then click with CDP mouse
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

# Current button is at y=1962 in document. innerHeight=894.
# To make it visible: scrollY must be >= 1962-894+1 = 1069 and <= 1962
# Let's scroll to 1500 which gives button at 1962-1500=462 in viewport (well in view)
$targetScroll = 1500
Write-Host "[Step 1: Scroll to $targetScroll]"
CDP $ws "Runtime.evaluate" @{expression="window.scrollTo({top:$targetScroll, behavior:'instant'})"} 1 | Out-Null
Start-Sleep 2

# Verify button position in viewport
$btnPos = CDP $ws "Runtime.evaluate" @{
    expression="
        (function() {
            var btns = Array.from(document.querySelectorAll('button'));
            var genBtn = btns.find(function(b) { return (b.innerText||'').trim().toLowerCase().indexOf('generate') !== -1; });
            if (genBtn) {
                var r = genBtn.getBoundingClientRect();
                var vis = r.y >= 0 && r.y+r.height <= window.innerHeight;
                return JSON.stringify({docY:r.y+window.scrollY, viewY:r.y, vis:vis, cx:r.x+r.width/2, cy:r.y+r.height/2, w:r.width, h:r.height});
            }
            return 'NO_BTN';
        })()
    "
} 2
Write-Host "[BTN POS] $btnPos"

if ($btnPos -match '"viewY":(-?\d+\.?\d*),.*"cx":(\d+\.?\d*),.*"cy":(\d+\.?\d*)') {
    $viewY = [double]$matches[1]
    $cx = [double]$matches[2]
    $cy = [double]$matches[3]
    Write-Host "[viewY=$viewY cx=$cx cy=$cy]"
    
    if ($viewY -gt 0 -and $viewY -lt 894) {
        Write-Host "[BTN VISIBLE! Clicking...]"
        
        # Mouse move
        CDP $ws "Input.dispatchMouseEvent" @{type="mouseMoved";x=$cx;y=$cy;button="left";clickCount=0} 3 | Out-Null
        Start-Sleep 0.5
        
        # Mouse press
        CDP $ws "Input.dispatchMouseEvent" @{type="mousePressed";x=$cx;y=$cy;button="left";clickCount=1} 4 | Out-Null
        Start-Sleep 0.3
        
        # Mouse release
        CDP $ws "Input.dispatchMouseEvent" @{type="mouseReleased";x=$cx;y=$cy;button="left";clickCount=1} 5 | Out-Null
        
        Write-Host "[CLICK SENT]"
        Start-Sleep 8
        
        # Check result
        $url = CDP $ws "Runtime.evaluate" @{expression="window.location.href"} 6
        $body = CDP $ws "Runtime.evaluate" @{expression="document.body.innerText.slice(0,3000)"} 7
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
        } 8
        Write-Host "[TOKEN] $tok"
        
        if ($tok -match 'ghp_[a-zA-Z0-9]{36}') {
            $token = ($tok -replace '.*?(ghp_[a-zA-Z0-9]{36}).*','$1')
            $token | Out-File -FilePath "$env:USERPROFILE\.qclaw\oe_github_token.txt" -Encoding UTF8
            Write-Host "[TOKEN SAVED: $token]"
        }
    } else {
        Write-Host "[BTN STILL NOT IN VIEW - viewY=$viewY]"
    }
} else {
    Write-Host "[COULD NOT GET BTN POS - $btnPos]"
}

try { $ws.CloseAsync('NormalClosure','',[Threading.CancellationToken]::None).Wait(2000) } catch {}
Write-Host "[DONE]"