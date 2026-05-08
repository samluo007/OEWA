# GitHub PAT - submit the form properly
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

CDP $ws "Page.navigate" @{url="https://github.com/settings/tokens/new?scopes=repo,workflow,gist,read:org"} 1 | Out-Null
Start-Sleep 5

# Step 1: Check URL
$url = CDP $ws "Runtime.evaluate" @{expression="window.location.href"} 2
Write-Host "[URL] $url"

# Step 2: Fill the note
$f1 = CDP $ws "Runtime.evaluate" @{
    expression='var inp = document.getElementById("oauth_access_description"); if (inp) { inp.focus(); inp.value = "OEWA OpenClaw 2026"; inp.dispatchEvent(new Event("input", {bubbles:true})); return "SET:" + inp.value; } return "NOT_FOUND";'
} 3
Write-Host "[NOTE] $f1"

# Step 3: Get form data
$f2 = CDP $ws "Runtime.evaluate" @{
    expression='
        (function() {
            var form = document.getElementById("new_oauth_access");
            if (!form) return "NO_FORM";
            var fd = new FormData(form);
            var entries = [];
            for (var pair of fd.entries()) {
                entries.push(pair[0] + "=" + (pair[1] || "").toString().slice(0,30));
            }
            return entries.join("|");
        })()
    '
} 4
Write-Host "[FORM ENTRIES] $f2"

# Step 4: Submit the form
$s1 = CDP $ws "Runtime.evaluate" @{
    expression='var form = document.getElementById("new_oauth_access"); if (form) { form.submit(); return "SUBMITTED"; } return "NO_FORM";'
} 5
Write-Host "[SUBMIT] $s1"
Start-Sleep 8

# Step 5: Check result
$url2 = CDP $ws "Runtime.evaluate" @{expression="window.location.href"} 6
$body = CDP $ws "Runtime.evaluate" @{expression="document.body.innerText.slice(0,4000)"} 7
Write-Host "[URL2] $url2"
Write-Host "=== BODY ==="
Write-Host $body

# Token check
$tok = CDP $ws "Runtime.evaluate" @{
    expression='var txt = document.body.innerText; var m = txt.match(/ghp_[a-zA-Z0-9]{36}/); return m ? "TOKEN:" + m[0] : "NO_TOKEN";'
} 8
Write-Host "[TOKEN] $tok"

if ($tok -match "TOKEN:(ghp_[a-zA-Z0-9]{36})") {
    $token = $matches[1]
    $token | Out-File -FilePath "$env:USERPROFILE\.qclaw\oe_github_token.txt" -Encoding UTF8
    Write-Host "[SUCCESS! TOKEN: $token]"
}

try { $ws.CloseAsync('NormalClosure','',[Threading.CancellationToken]::None).Wait(2000) } catch {}
Write-Host "[DONE]"