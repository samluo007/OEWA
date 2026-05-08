# GitHub PAT - scroll to button, fill form, click Generate token
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

# Scroll the Generate token button into view
$r1 = CDP $ws "Runtime.evaluate" @{
    expression="
        (function() {
            var btns = Array.from(document.querySelectorAll('button'));
            var genBtn = btns.find(function(b) { return (b.innerText||'').trim().toLowerCase().indexOf('generate') !== -1; });
            if (genBtn) {
                genBtn.scrollIntoView({behavior:'smooth', block:'center'});
                return 'SCROLLED_TO:' + genBtn.getBoundingClientRect().y + ',' + genBtn.getBoundingClientRect().x;
            }
            return 'NOT_FOUND';
        })()
    "
} 1
Write-Host "[SCROLL] $r1"
Start-Sleep 2

# Get DOM node id for the button using CSS selector
$r2 = CDP $ws "DOM.getDocument" @{} 2
Write-Host "[DOM DOC] $($r2.Substring(0,200))"

# Find button using CSS selector
$r3 = CDP $ws "DOM.querySelectorAll" @{nodeId=1; selector="button"} 3
Write-Host "[QUERY ALL BUTTONS] $($r3.Substring(0,300))"

# Alternative: use JavaScript to directly click the button
$r4 = CDP $ws "Runtime.evaluate" @{
    expression="
        (function() {
            var btns = Array.from(document.querySelectorAll('button'));
            var genBtn = btns.find(function(b) { return (b.innerText||'').trim().toLowerCase().indexOf('generate') !== -1; });
            if (genBtn && genBtn.getBoundingClientRect().y > 0) {
                genBtn.click();
                return 'CLICKED:' + genBtn.getBoundingClientRect().y;
            } else {
                return 'BTN_NOT_VISIBLE_YET y=' + (genBtn ? genBtn.getBoundingClientRect().y : 'no btn');
            }
        })()
    "
} 4
Write-Host "[CLICK RESULT] $r4"
Start-Sleep 8

# Check if token was generated
$r5 = CDP $ws "Runtime.evaluate" @{expression="window.location.href"} 5
$r6 = CDP $ws "Runtime.evaluate" @{expression="document.body.innerText.slice(0,3000)"} 6
Write-Host "[URL5] $r5"
Write-Host "=== PAGE BODY ==="
Write-Host $r6

$r7 = CDP $ws "Runtime.evaluate" @{
    expression="
        (function() {
            var txt = document.body.innerText;
            var m = txt.match(/ghp_[a-zA-Z0-9]{36}/);
            if (m) return 'TOKEN:' + m[0];
            // Also check clipboard or any textarea
            var tas = Array.from(document.querySelectorAll('textarea, input[readonly]'));
            var results = [];
            for (var ta of tas) {
                if (ta.value && ta.value.match(/ghp_/)) results.push('TA:' + ta.value.slice(0,60));
            }
            return results.length > 0 ? results.join('||') : 'NO_TOKEN';
        })()
    "
} 7
Write-Host "[TOKEN CHECK] $r7"

if ($r7 -match 'ghp_[a-zA-Z0-9]{36}') {
    $token = ($r7 -replace '.*?(ghp_[a-zA-Z0-9]{36}).*','$1')
    Write-Host "[SAVING TOKEN: $token]"
    $token | Out-File -FilePath "$env:USERPROFILE\.qclaw\oe_github_token.txt" -Encoding UTF8
    Write-Host "[TOKEN SAVED]"
}

try { $ws.CloseAsync('NormalClosure','',[Threading.CancellationToken]::None).Wait(2000) } catch {}
Write-Host "[DONE]"