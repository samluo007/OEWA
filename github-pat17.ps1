# GitHub PAT - HTTP POST approach, proper body construction

$csrfUrl = "https://github.com/settings/tokens/new"
$postUrl = "https://github.com/settings/tokens"

# Step 1: Get authenticity token
Write-Host "[Step 1: Getting CSRF token]"
try {
    $r = Invoke-WebRequest -Uri $csrfUrl -TimeoutSec 15 -UserAgent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120.0.0.0 Safari/537.36"
    $html = $r.Content
    $csrfMatch = [regex]::Match($html, 'name="authenticity_token" value="([^"]+)"')
    $csrf = $csrfMatch.Groups[1].Value
    Write-Host "[CSRF] $csrf"
    if (-not $csrf) { Write-Host "[ERROR: no CSRF found]"; exit 1 }
} catch {
    Write-Host "[ERROR] $($_.Exception.Message)"
    exit 1
}

# Step 2: Build body as string (avoids duplicate key issue)
Write-Host "[Step 2: POSTing form]"
$body = "authenticity_token=$([Uri]::EscapeDataString($csrf))" + 
       "&oauth_access%5Bdescription%5D=OEWA+OpenClaw+Integration+2026" +
       "&oauth_access%5Bdefault_expires_at%5D=30" +
       "&oauth_access%5Bcustom_expires_at%5D=" +
       "&oauth_access%5Bscopes%5D%5B%5D=repo" +
       "&oauth_access%5Bscopes%5D%5B%5D=workflow" +
       "&oauth_access%5Bscopes%5D%5B%5D=gist" +
       "&oauth_access%5Bscopes%5D%5B%5D=read%3Aorg"

try {
    $r2 = Invoke-WebRequest -Uri $postUrl -Method Post `
        -Body $body `
        -ContentType "application/x-www-form-urlencoded" `
        -TimeoutSec 15 `
        -UserAgent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120.0.0.0 Safari/537.36" `
        -MaximumRedirection 5

    $html2 = $r2.Content
    Write-Host "[STATUS] $($r2.StatusCode)"
    Write-Host "[FINAL URL] $($r2.BaseResponse.ResponseUri)"

    $tokenMatch = [regex]::Match($html2, 'ghp_[a-zA-Z0-9]{36}')
    if ($tokenMatch.Success) {
        $token = $tokenMatch.Value
        Write-Host "[SUCCESS! TOKEN: $token]"
        $token | Out-File -FilePath "$env:USERPROFILE\.qclaw\oe_github_token.txt" -Encoding UTF8
        Write-Host "[SAVED]"
    } else {
        Write-Host "[NO TOKEN IN RESPONSE]"
        if ($html2.Length -gt 200) {
            Write-Host "=== PAGE CONTENT (first 500 chars) ==="
            Write-Host $html2.Substring(0, [Math]::Min(500, $html2.Length))
        }
    }
} catch {
    Write-Host "[ERROR $($_.Exception.Message)]"
    if ($_.Exception.Response) {
        Write-Host "[STATUS CODE] $($_.Exception.Response.StatusCode.value__)"
    }
}

Write-Host "[DONE]"