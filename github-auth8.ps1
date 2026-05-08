# OEWA GitHub OAuth v8 - Fresh tab, navigate to integrations, find GitHub button
$debugPort = 9222

function CDP-SR {
    param($ws, $method, $params=@{}, $id=1)
    $msg = @{id=$id; method=$method; params=$params} | ConvertTo-Json -Compress
    $bytes = [Text.Encoding]::UTF8.GetBytes($msg)
    try {
        $ws.SendAsync([ArraySegment[byte]]$bytes, 'Text', $true, [Threading.CancellationToken]::None).Wait(6000)
        Start-Sleep -Milliseconds 300
        $buf = [byte[]]::new(16384)
        $ws.ReceiveAsync([ArraySegment[byte]]$buf, [Threading.CancellationToken]::None).Wait(6000) | Out-Null
        [Text.Encoding]::UTF8.GetString($buf).TrimEnd([char]0)
    } catch { "" }
}

# Create fresh tab with PUT
$newTab = Invoke-RestMethod -Method Put "http://localhost:$debugPort/json/new" -TimeoutSec 5
$tabId = $newTab.id
$wsUrl = $newTab.webSocketDebuggerUrl
Write-Host "[NEW TAB] $tabId"

$ws = New-Object System.Net.WebSockets.ClientWebSocket
$ws.ConnectAsync([Uri]$wsUrl, [Threading.CancellationToken]::None).Wait(8000)
Write-Host "[WS OK]"

# Navigate to integrations
CDP-SR $ws "Page.navigate" @{url="http://127.0.0.1:28789/integrations"} 1
Start-Sleep 5

$url = CDP-SR $ws "Runtime.evaluate" @{expression="window.location.href"} 2
$title = CDP-SR $ws "Runtime.evaluate" @{expression="document.title"} 3
$body = CDP-SR $ws "Runtime.evaluate" @{expression="document.body.innerText.slice(0,4000)"} 4
Write-Host "[URL] $url"
Write-Host "[TITLE] $title"
Write-Host "=== BODY ==="
Write-Host $body

# Find all interactive elements
$els = CDP-SR $ws "Runtime.evaluate" @{
    expression="
        JSON.stringify(Array.from(document.querySelectorAll('a, button, [role=button], .item, .card, .option, .tile')).map(e=>({
            t:e.innerText?.trim().substring(0,80),
            h:e.href,
            c:e.className,
            tag:e.tagName
        })).filter(e=>e.t||e.h).slice(0,40));
    "
} 5
Write-Host "=== ALL ELEMENTS ==="
Write-Host $els

# Click on skills link if exists
$skillsLink = CDP-SR $ws "Runtime.evaluate" @{
    expression="
        var links = Array.from(document.querySelectorAll('a, button'));
        var skillLink = links.find(e => e.innerText?.includes('技能') || e.innerText?.includes('Skill') || e.href?.includes('skills'));
        if (skillLink) {
            skillLink.click();
            'Clicked: ' + skillLink.href + ' : ' + skillLink.innerText;
        } else { 'no skill link found' }
    "
} 6
Write-Host "[SKILLS] $skillsLink"
Start-Sleep 3

# Get new page
$body2 = CDP-SR $ws "Runtime.evaluate" @{expression="document.body.innerText.slice(0,3000)"} 7
Write-Host "=== SKILLS PAGE ==="
Write-Host $body2

# Check for GitHub skill and its config button
$ghInSkills = CDP-SR $ws "Runtime.evaluate" @{
    expression="
        var all = document.querySelectorAll('*');
        var found = [];
        for (var el of all) {
            var walker = document.createTreeWalker(el, NodeFilter.SHOW_TEXT, null, false);
            while(walker.nextNode()) {
                var t = walker.currentNode.textContent?.trim() || '';
                if (t.includes('GitHub') || t.includes('github')) {
                    found.push(el.tagName + '|' + el.className.substring(0,50) + '|' + t.substring(0,100));
                    break;
                }
            }
        }
        JSON.stringify(found.slice(0,20));
    "
} 8
Write-Host "=== GITHUB IN SKILLS ==="
Write-Host $ghInSkills

# Find GitHub card/button and click it
$ghClick = CDP-SR $ws "Runtime.evaluate" @{
    expression="
        var all = document.querySelectorAll('a, button, .card, .item, .option, .tile');
        for (var el of all) {
            var t = (el.innerText || '').trim();
            if (t.includes('GitHub') || t.includes('github')) {
                el.click();
                return 'Clicked: ' + el.tagName + ' class:' + el.className + ' text:' + t.substring(0,80);
            }
        }
        return 'GitHub element not found';
    "
} 9
Write-Host "[GITHUB CLICK] $ghClick"
Start-Sleep 4

# Take screenshot to see what's on screen
CDP-SR $ws "Page.captureScreenshot" @{} 10
$ss = CDP-SR $ws "Runtime.evaluate" @{expression="''"} 11

# Final page state
$finalBody = CDP-SR $ws "Runtime.evaluate" @{expression="document.body.innerText.slice(0,3000)"} 12
Write-Host "=== FINAL PAGE ==="
Write-Host $finalBody

$finalUrl = CDP-SR $ws "Runtime.evaluate" @{expression="window.location.href"} 13
Write-Host "[FINAL URL] $finalUrl"

try { $ws.CloseAsync('NormalClosure', "", [Threading.CancellationToken]::None).Wait(1000) } catch {}
Write-Host "[DONE]"