# GitHub PAT creation - use CDP with more reliable button click
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

# Scroll to bottom and click Generate token
$r1 = CDP $ws "Runtime.evaluate" @{
    expression="
        (function() {
            window.scrollTo(0, document.body.scrollHeight);
            return 'scrolled to bottom';
        })()
    "
} 1
Write-Host "[SCROLL] $r1"
Start-Sleep 1

# Find the submit button - it should say "Generate token"
$r2 = CDP $ws "Runtime.evaluate" @{
    expression="
        (function() {
            var btns = Array.from(document.querySelectorAll('button, input[type=submit]'));
            var result = [];
            for (var b of btns) {
                result.push(b.tagName + ' text=' + (b.innerText || '').trim().slice(0,30) + ' disabled=' + b.disabled + ' type=' + b.type);
            }
            return result.join(' || ');
        })()
    "
} 2
Write-Host "[ALL BUTTONS]"
Write-Host $r2

# Click specific generate button
$r3 = CDP $ws "Runtime.evaluate" @{
    expression="
        (function() {
            var btn = Array.from(document.querySelectorAll('button')).find(function(b) {
                var t = (b.innerText || '').trim().toLowerCase();
                return t.indexOf('generate') !== -1 || t.indexOf('token') !== -1;
            });
            if (btn) {
                btn.scrollIntoView({behavior:'smooth', block:'center'});
                setTimeout(function() { btn.click(); }, 500);
                return 'SCROLLED_AND_CLICKED:' + btn.innerText.trim();
            }
            return 'NO_GEN_BTN';
        })()
    "
} 3
Write-Host "[CLICK GEN] $r3"
Start-Sleep 5

# Page state after click
$r4 = CDP $ws "Runtime.evaluate" @{expression="document.body.innerText.slice(0,2000)"} 4
Write-Host "=== STATE AFTER CLICK ==="
Write-Host $r4

# Check for token
$r5 = CDP $ws "Runtime.evaluate" @{
    expression="
        (function() {
            var txt = document.body.innerText;
            var m = txt.match(/ghp_[a-zA-Z0-9]{36}/);
            if (m) return 'TOKEN:' + m[0];
            // Check readonly inputs
            var inps = document.querySelectorAll('input');
            for (var i of inps) {
                if (i.value && i.value.match(/^ghp_/)) return 'INPUT_TOKEN:' + i.value;
            }
            return 'NO_TOKEN';
        })()
    "
} 5
Write-Host "[TOKEN] $r5"

if ($r5 -match 'ghp_[a-zA-Z0-9]{36}') {
    $token = ($r5 -replace '.*?(ghp_[a-zA-Z0-9]{36}).*','$1')
    Write-Host "[SAVING TOKEN]"
    $token | Out-File -FilePath "$env:USERPROFILE\.qclaw\oe_github_token.txt" -Encoding UTF8
    Write-Host "[TOKEN SAVED: $token]"
}

try { $ws.CloseAsync('NormalClosure','',[Threading.CancellationToken]::None).Wait(2000) } catch {}
Write-Host "[DONE]"