# GitHub PAT - diagnose the form and find the submit button
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

# First scroll down to bottom of page
CDP $ws "Runtime.evaluate" @{expression="window.scrollTo(0, document.body.scrollHeight)"} 1 | Out-Null
Start-Sleep 2

# Get all buttons with their positions
$r1 = CDP $ws "Runtime.evaluate" @{
    expression="
        (function() {
            var btns = Array.from(document.querySelectorAll('button, input[type=submit]'));
            var result = [];
            for (var b of btns) {
                var rect = b.getBoundingClientRect();
                result.push(b.tagName + ' text=[' + (b.innerText||'').trim() + '] disabled=' + b.disabled + ' rect=' + JSON.stringify({x:rect.x,y:rect.y,w:rect.width,h:rect.height}));
            }
            return result.join('\n');
        })()
    "
} 2
Write-Host "=== ALL BUTTONS WITH POSITIONS ==="
Write-Host $r1

# Also look at the form and its submit action
$r2 = CDP $ws "Runtime.evaluate" @{
    expression="
        (function() {
            var forms = Array.from(document.querySelectorAll('form'));
            var result = [];
            for (var f of forms) {
                result.push('FORM action=' + f.action + ' method=' + f.method + ' id=' + f.id + ' innerHTML snippet=' + f.innerHTML.slice(0,500));
            }
            return result.length > 0 ? result.join('\n') : 'NO_FORMS';
        })()
    "
} 3
Write-Host "=== FORMS ==="
Write-Host $r2

# Find the actual "Generate token" button by text content
$r3 = CDP $ws "Runtime.evaluate" @{
    expression="
        (function() {
            var all = Array.from(document.querySelectorAll('*'));
            var genBtns = [];
            for (var el of all) {
                var t = el.innerText || '';
                if (t.trim().toLowerCase().indexOf('generate') !== -1 && (el.tagName === 'BUTTON' || el.tagName === 'INPUT')) {
                    var rect = el.getBoundingClientRect();
                    genBtns.push(el.tagName + ' text=[' + t.trim() + '] rect=' + JSON.stringify({x:Math.round(rect.x),y:Math.round(rect.y),w:Math.round(rect.width),h:Math.round(rect.height)}) + ' vis=' + rect.width + ',' + rect.height);
                }
            }
            return genBtns.length > 0 ? genBtns.join('\n') : 'NO_GEN_BTN_FOUND';
        })()
    "
} 4
Write-Host "=== GENERATE BUTTONS ==="
Write-Host $r3

try { $ws.CloseAsync('NormalClosure','',[Threading.CancellationToken]::None).Wait(2000) } catch {}
Write-Host "[DONE]"