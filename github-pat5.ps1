# GitHub PAT creation - use CDP DOM methods to click generate button
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

# Verify we are on the PAT page
$url = CDP $ws "Runtime.evaluate" @{expression="window.location.href"} 1
Write-Host "[URL] $url"

# Click the "Generate token" button using CDP DOM
$btnResult = CDP $ws "Runtime.evaluate" @{
    expression="
        (function() {
            var btns = Array.from(document.querySelectorAll('button'));
            for (var b of btns) {
                if (b.innerText.trim().toLowerCase().indexOf('generate') !== -1 ||
                    b.innerText.trim().toLowerCase().indexOf('生成') !== -1 ||
                    b.innerText.trim().toLowerCase().indexOf('创建') !== -1 ||
                    b.innerText.trim().toLowerCase().indexOf('token') !== -1) {
                    b.scrollIntoView();
                    b.click();
                    return 'CLICKED:' + b.innerText.trim();
                }
            }
            // Try submit input
            var subs = Array.from(document.querySelectorAll('input[type=submit], button[type=submit]'));
            for (var s of subs) {
                if (s.innerText.trim() || s.value) {
                    s.scrollIntoView();
                    s.click();
                    return 'CLICKED_SUBMIT:' + (s.innerText.trim() || s.value);
                }
            }
            return 'NO_BTN_FOUND buttons:' + btns.map(function(b){return b.innerText.trim().slice(0,20)}).join('|');
        })()
    "
} 2
Write-Host "[BTN RESULT] $btnResult"
Start-Sleep 8

# Check for modal or 2FA
$modal = CDP $ws "Runtime.evaluate" @{expression="document.body.innerText.slice(0,1500)"} 3
Write-Host "=== PAGE STATE ==="
Write-Host $modal

# Check for token in page
$check = CDP $ws "Runtime.evaluate" @{
    expression="
        (function() {
            var txt = document.body.innerText;
            var m = txt.match(/ghp_[a-zA-Z0-9]{36}/);
            if (m) return 'TOKEN:' + m[0];
            return 'NO_TOKEN_IN_PAGE';
        })()
    "
} 4
Write-Host "[TOKEN CHECK] $check"

# If no token yet, wait a bit more
if ($check -notmatch 'TOKEN:') {
    Write-Host "[WAITING for token...]"
    Start-Sleep 8
    $check2 = CDP $ws "Runtime.evaluate" @{
        expression="
            (function() {
                var txt = document.body.innerText;
                var m = txt.match(/ghp_[a-zA-Z0-9]{36}/);
                if (m) return 'TOKEN:' + m[0];
                return 'STILL_NO_TOKEN';
            })()
        "
    } 5
    Write-Host "[TOKEN CHECK 2] $check2"
}

# Also check for any input field with readonly that might contain token
$readonlyCheck = CDP $ws "Runtime.evaluate" @{
    expression="
        (function() {
            var results = [];
            var inps = document.querySelectorAll('input');
            for (var i of inps) {
                if (i.value && (i.value.indexOf('ghp_') !== -1 || i.value.indexOf('github_pat') !== -1)) {
                    results.push(i.id + ':' + i.value.slice(0,50));
                }
            }
            return results.length > 0 ? 'INPUTS:' + results.join('||') : 'NO_INPUT_TOKEN';
        })()
    "
} 6
Write-Host "[READONLY INPUTS] $readonlyCheck"

# Save token if found
if ($check -match 'TOKEN:(ghp_[a-zA-Z0-9]{36})') {
    $token = $matches[1]
    Write-Host "[FOUND TOKEN] $token"
    $token | Out-File -FilePath "$env:USERPROFILE\.qclaw\oe_github_token.txt" -Encoding UTF8
    Write-Host "[TOKEN SAVED]"
} elseif ($check2 -match 'TOKEN:(ghp_[a-zA-Z0-9]{36})') {
    $token = $matches[1]
    Write-Host "[FOUND TOKEN 2] $token"
    $token | Out-File -FilePath "$env:USERPROFILE\.qclaw\oe_github_token.txt" -Encoding UTF8
    Write-Host "[TOKEN SAVED]"
} else {
    Write-Host "[TOKEN NOT FOUND - user needs to click generate manually or copy token]"
}

try { $ws.CloseAsync('NormalClosure','',[Threading.CancellationToken]::None).Wait(2000) } catch {}
Write-Host "[DONE]"