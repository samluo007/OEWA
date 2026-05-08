# GitHub PAT - fill description, click Generate
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

# Navigate back to PAT page
CDP $ws "Page.navigate" @{url="https://github.com/settings/tokens/new?scopes=repo,workflow,gist,read:org"} 1 | Out-Null
Start-Sleep 6

$url = CDP $ws "Runtime.evaluate" @{expression="window.location.href"} 2
Write-Host "[URL] $url"

# Fill the Note field using DOM node
$f1 = CDP $ws "Runtime.evaluate" @{
    expression="
        (function() {
            var inp = document.getElementById('oauth_access_description') ||
                      document.querySelector('input[name=""oauth_access[description]""]') ||
                      document.querySelector('input[id*=description]');
            if (inp) {
                // Try both value-setting methods
                inp.focus();
                inp.value = 'OEWA OpenClaw Integration 2026';
                // Also try dispatching input event
                inp.dispatchEvent(new Event('input', {bubbles:true}));
                inp.dispatchEvent(new Event('change', {bubbles:true}));
                return 'SET:' + inp.value + ' id=' + inp.id + ' name=' + inp.name;
            }
            return 'NOT_FOUND inputs=' + JSON.stringify(Array.from(document.querySelectorAll('input')).map(function(i){return i.id+':'+i.name+':'+(i.value||'').slice(0,20)}));
        })()
    "
} 3
Write-Host "[FILL NOTE] $f1"
Start-Sleep 1

# Verify it was set
$f2 = CDP $ws "Runtime.evaluate" @{
    expression="
        (function() {
            var inp = document.getElementById('oauth_access_description') ||
                      document.querySelector('input[name=""oauth_access[description]""]');
            if (inp) return 'VALUE:' + inp.value;
            return 'NOT_FOUND';
        })()
    "
} 4
Write-Host "[VERIFY] $f2"

# Now click Generate token button
# First scroll to it
CDP $ws "Runtime.evaluate" @{expression="window.scrollTo({top:0, behavior:'instant'})"} 5 | Out-Null
Start-Sleep 1
CDP $ws "Runtime.evaluate" @{expression="window.scrollTo({top:600, behavior:'instant'})"} 5 | Out-Null
Start-Sleep 1

# Get button position
$btnRaw = CDP $ws "Runtime.evaluate" @{
    expression="
        (function() {
            var btns = Array.from(document.querySelectorAll('button'));
            var genBtn = btns.find(function(b) { return (b.innerText||'').trim().toLowerCase().indexOf('generate') !== -1; });
            if (genBtn) {
                genBtn.scrollIntoView({block:'center'});
                var r = genBtn.getBoundingClientRect();
                return JSON.stringify({cx: r.x+r.width/2, cy: r.y+r.height/2, vis: r.y >= 0 && r.y+r.height <= window.innerHeight});
            }
            return 'NO_BTN';
        })()
    "
} 6
$jsonStr = $btnRaw -replace '^True\s*', ''
Write-Host "[BTN POS] $btnRaw"

if ($jsonStr -notmatch 'NO_BTN') {
    $btnPos = $jsonStr | ConvertFrom-Json -EA SilentlyContinue
    if ($btnPos -and $btnPos.vis) {
        $cx = [double]$btnPos.cx
        $cy = [double]$btnPos.cy
        Write-Host "[Clicking at cx=$cx cy=$cy]"
        
        CDP $ws "Input.dispatchMouseEvent" @{type="mouseMoved";x=$cx;y=$cy;button="left";clickCount=0} 7 | Out-Null
        Start-Sleep 0.5
        CDP $ws "Input.dispatchMouseEvent" @{type="mousePressed";x=$cx;y=$cy;button="left";clickCount=1} 8 | Out-Null
        Start-Sleep 0.3
        CDP $ws "Input.dispatchMouseEvent" @{type="mouseReleased";x=$cx;y=$cy;button="left";clickCount=1} 9 | Out-Null
        
        Write-Host "[CLICK SENT]"
        Start-Sleep 10
        
        $url2 = CDP $ws "Runtime.evaluate" @{expression="window.location.href"} 10
        $body2 = CDP $ws "Runtime.evaluate" @{expression="document.body.innerText.slice(0,3000)"} 11
        Write-Host "[URL2] $url2"
        Write-Host "=== BODY ==="
        Write-Host $body2
        
        # Token check
        $tokRaw = CDP $ws "Runtime.evaluate" @{
            expression="
                (function() {
                    var txt = document.body.innerText;
                    var m = txt.match(/ghp_[a-zA-Z0-9]{36}/);
                    return m ? 'TOKEN:' + m[0] : 'NO_TOKEN';
                })()
            "
        } 12
        Write-Host "[TOKEN] $tokRaw"
        
        if ($tokRaw -match 'TOKEN:(ghp_[a-zA-Z0-9]{36})') {
            $token = $matches[1]
            $token | Out-File -FilePath "$env:USERPROFILE\.qclaw\oe_github_token.txt" -Encoding UTF8
            Write-Host "[SUCCESS! TOKEN: $token]"
        }
    } else {
        Write-Host "[BTN NOT VISIBLE - viewY=$($btnPos.viewY)]"
    }
}

try { $ws.CloseAsync('NormalClosure','',[Threading.CancellationToken]::None).Wait(2000) } catch {}
Write-Host "[DONE]"