# GitHub PAT - use CDP mouse click at exact button coordinates
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

# The Generate token button is at x=312+65=377, y=712+16=728 (center of button)
# But it's currently at y=-1546 (off-screen above). Need to scroll page first.
Write-Host "[Step 1: Get page scroll info]"
$scrollInfo = CDP $ws "Runtime.evaluate" @{
    expression="
        (function() {
            return JSON.stringify({
                scrollY: window.scrollY,
                innerHeight: window.innerHeight,
                scrollHeight: document.body.scrollHeight
            });
        })()
    "
} 1
Write-Host "[SCROLL INFO] $scrollInfo"

# Scroll to where the button is (around y=712 in viewport coordinates)
# We need to scroll so that y=712 becomes visible in the viewport
$targetScrollY = [Math]::Max(0, 712 - 400)  # scroll so button is ~400px from top
Write-Host "[Step 2: Scrolling to y=$targetScrollY]"
CDP $ws "Runtime.evaluate" @{expression="window.scrollTo(0, $targetScrollY)"} 2 | Out-Null
Start-Sleep 2

# Get actual button position after scroll
$btnPos = CDP $ws "Runtime.evaluate" @{
    expression="
        (function() {
            var btns = Array.from(document.querySelectorAll('button'));
            var genBtn = btns.find(function(b) { return (b.innerText||'').trim().toLowerCase().indexOf('generate') !== -1; });
            if (genBtn) {
                var r = genBtn.getBoundingClientRect();
                return JSON.stringify({x:r.x, y:r.y, w:r.width, h:r.height, vx:r.x+r.width/2, vy:r.y+r.height/2, top:r.top, bottom:r.bottom});
            }
            return 'NO_BTN';
        })()
    "
} 3
Write-Host "[BTN POS after scroll] $btnPos"

# Now click the button using CDP Input.dispatchMouseEvent
# x,y are in document coordinates
$clickX = 312 + 65  # center = 377
$clickY = $targetScrollY + 712 - $targetScrollY + 16  # = 728 but relative to scrollY
# Actually let's use getBoundingClientRect and calculate viewport coords
$viewClick = CDP $ws "Runtime.evaluate" @{
    expression="
        (function() {
            var btns = Array.from(document.querySelectorAll('button'));
            var genBtn = btns.find(function(b) { return (b.innerText||'').trim().toLowerCase().indexOf('generate') !== -1; });
            if (genBtn) {
                var r = genBtn.getBoundingClientRect();
                return JSON.stringify({cx:r.x+r.width/2, cy:r.y+r.height/2, vr:r.width>0});
            }
            return 'NO_BTN';
        })()
    "
} 4

if ($viewClick -match '"cx":(\d+),"cy":(\d+)') {
    $cx = $matches[1]
    $cy = $matches[2]
    Write-Host "[Step 3: Mouse click at viewport ($cx, $cy)]"
    
    # mouseMove
    CDP $ws "Input.dispatchMouseEvent" @{
        type="mouseMoved"; x=[double]$cx; y=[double]$cy; button="left"; clickCount=0
    } 5 | Out-Null
    Start-Sleep 0.5
    
    # mousePressed
    CDP $ws "Input.dispatchMouseEvent" @{
        type="mousePressed"; x=[double]$cx; y=[double]$cy; button="left"; clickCount=1
    } 6 | Out-Null
    Start-Sleep 0.3
    
    # mouseReleased
    CDP $ws "Input.dispatchMouseEvent" @{
        type="mouseReleased"; x=[double]$cx; y=[double]$cy; button="left"; clickCount=1
    } 7 | Out-Null
    
    Write-Host "[MOUSE CLICK SENT]"
    Start-Sleep 8
    
    # Check result
    $url = CDP $ws "Runtime.evaluate" @{expression="window.location.href"} 8
    $body = CDP $ws "Runtime.evaluate" @{expression="document.body.innerText.slice(0,3000)"} 9
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
    } 10
    Write-Host "[TOKEN] $tok"
    
    if ($tok -match 'ghp_[a-zA-Z0-9]{36}') {
        $token = ($tok -replace '.*?(ghp_[a-zA-Z0-9]{36}).*','$1')
        $token | Out-File -FilePath "$env:USERPROFILE\.qclaw\oe_github_token.txt" -Encoding UTF8
        Write-Host "[TOKEN SAVED: $token]"
    }
} else {
    Write-Host "[BTN NOT IN VIEW - $viewClick]"
}

try { $ws.CloseAsync('NormalClosure','',[Threading.CancellationToken]::None).Wait(2000) } catch {}
Write-Host "[DONE]"