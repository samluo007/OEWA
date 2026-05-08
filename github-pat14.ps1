# GitHub PAT - check checkboxes, fill form, submit via JS or form submit
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

# Navigate to fresh PAT page
CDP $ws "Page.navigate" @{url="https://github.com/settings/tokens/new?scopes=repo,workflow,gist,read:org"} 1 | Out-Null
Start-Sleep 5

# Step 1: Check all checkbox states
$c1 = CDP $ws "Runtime.evaluate" @{
    expression="
        (function() {
            var cbs = Array.from(document.querySelectorAll('input[type=checkbox]'));
            var results = [];
            for (var c of cbs) {
                var lbl = c.nextElementSibling ? (c.nextElementSibling.innerText || '').trim() : '';
                if (lbl.length === 0) lbl = c.parentElement ? (c.parentElement.innerText || '').trim().slice(0,30) : '';
                results.push(c.name + ' checked=' + c.checked + ' lbl=' + lbl);
            }
            return results.join('\n');
        })()
    "
} 2
Write-Host "=== CHECKBOXES ==="
Write-Host $c1

# Step 2: Fill the note
$f1 = CDP $ws "Runtime.evaluate" @{
    expression="
        (function() {
            var inp = document.getElementById('oauth_access_description');
            if (inp) {
                inp.focus();
                inp.value = 'OEWA OpenClaw Integration 2026';
                inp.dispatchEvent(new Event('input', {bubbles:true}));
                return 'SET:' + inp.value;
            }
            return 'NOT_FOUND';
        })()
    "
} 3
Write-Host "[NOTE] $f1"

# Step 3: Find and submit the correct form - use the POST form id=new_oauth_access
$s1 = CDP $ws "Runtime.evaluate" @{
    expression="
        (function() {
            var form = document.getElementById('new_oauth_access');
            if (form) {
                // Try submitting the form
                var fd = new FormData(form);
                var params = new URLSearchParams();
                for (var pair of fd.entries()) {
                    params.append(pair[0], pair[1]);
                }
                return 'FORM_FD:' + Array.from(fd.entries()).map(function(e){return e[0]+'='+e[1]}).join('&');
            }
            return 'FORM_NOT_FOUND';
        })()
    "
} 4
Write-Host "[FORM DATA] $s1"

# Try submitting via fetch POST
$s2 = CDP $ws "Runtime.evaluate" @{
    expression="
        (function() {
            var form = document.getElementById('new_oauth_access');
            if (!form) return 'NO_FORM';
            var fd = new FormData(form);
            var csrf = fd.get('authenticity_token') || fd.get('oauth_access[authenticity_token]');
            var note = document.getElementById('oauth_access_description').value;
            var scopes = [];
            var cbs = document.querySelectorAll('input[type=checkbox][name^=\"oauth_access[scopes]\"]');
            for (var c of cbs) {
                if (c.checked) scopes.push(c.name.match(/\[scopes\]\[(.*?)\]/)[1]);
            }
            return JSON.stringify({csrf: csrf, note: note, scopes: scopes.join(',')});
        })()
    "
} 5
Write-Host "[SUBMIT DATA] $s2"

# Now submit the form via submit() method
$sub = CDP $ws "Runtime.evaluate" @{
    expression="
        (function() {
            var form = document.getElementById('new_oauth_access');
            if (form) {
                form.submit();
                return 'SUBMITTED';
            }
            return 'NO_FORM';
        })()
    "
} 6
Write-Host "[SUBMIT] $sub"
Start-Sleep 8

# Check result
$url = CDP $ws "Runtime.evaluate" @{expression="window.location.href"} 7
$body = CDP $ws "Runtime.evaluate" @{expression="document.body.innerText.slice(0,4000)"} 8
Write-Host "[URL] $url"
Write-Host "=== BODY ==="
Write-Host $body

# Token check
$tok = CDP $ws "Runtime.evaluate" @{
    expression="
        (function() {
            var txt = document.body.innerText;
            var m = txt.match(/ghp_[a-zA-Z0-9]{36}/);
            return m ? 'TOKEN:' + m[0] : 'NO_TOKEN';
        })()
    "
} 9
Write-Host "[TOKEN] $tok"

if ($tok -match 'TOKEN:(ghp_[a-zA-Z0-9]{36})') {
    $token = $matches[1]
    $token | Out-File -FilePath "$env:USERPROFILE\.qclaw\oe_github_token.txt" -Encoding UTF8
    Write-Host "[SUCCESS! TOKEN: $token]"
}

try { $ws.CloseAsync('NormalClosure','',[Threading.CancellationToken]::None).Wait(2000) } catch {}
Write-Host "[DONE]"