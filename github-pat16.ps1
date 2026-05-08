# GitHub PAT - submit via HTTP POST to avoid CDP expression issues
# Get the token via form POST, not browser DOM manipulation

$url = "https://github.com/settings/tokens"
$loginUrl = "https://github.com/login"

# Step 1: Get authenticity token
Write-Host "[Step 1: Getting authenticity token]"
try {
    $r = Invoke-WebRequest -Uri $url -SessionVariable gh -TimeoutSec 15 -UserAgent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
    $html = $r.Content
    $csrfMatch = [regex]::Match($html, 'name="authenticity_token" value="([^"]+)"')
    $csrf = $csrfMatch.Groups[1].Value
    Write-Host "[CSRF] $csrf"
} catch {
    Write-Host "[ERROR] $($_.Exception.Message)"
    exit 1
}

# Step 2: Fill the form and POST
$note = "OEWA OpenClaw Integration 2026"
$scopes = @("repo","workflow","gist","read:org")

$body = @{
    "authenticity_token" = $csrf
    "oauth_access[description]" = $note
    "oauth_access[default_expires_at]" = "30"
    "oauth_access[custom_expires_at]" = ""
    "oauth_access[scopes][]" = "repo"
    "oauth_access[scopes][]" = "workflow"
    "oauth_access[scopes][]" = "gist"
    "oauth_access[scopes][]" = "read:org"
}

Write-Host "[Step 2: Submitting form]"
try {
    $r2 = Invoke-WebRequest -Uri $url -WebSession $gh -Method Post -Body $body -ContentType "application/x-www-form-urlencoded" -TimeoutSec 15 -UserAgent "Mozilla/5.0" -MaximumRedirection 5
    $html2 = $r2.Content
    Write-Host "[STATUS] $($r2.StatusCode)"
    Write-Host "[FINAL URL] $($r2.BaseResponse.ResponseUri)"
    
    # Check for token
    $tokenMatch = [regex]::Match($html2, 'ghp_[a-zA-Z0-9]{36}')
    if ($tokenMatch.Success) {
        $token = $tokenMatch.Value
        Write-Host "[TOKEN FOUND!] $token"
        $token | Out-File -FilePath "$env:USERPROFILE\.qclaw\oe_github_token.txt" -Encoding UTF8
        Write-Host "[TOKEN SAVED]"
    } else {
        Write-Host "[NO TOKEN - checking body snippet...]"
        Write-Host $html2.Substring(0, [Math]::Min(1000, $html2.Length))
    }
} catch {
    Write-Host "[ERROR] $($_.Exception.Message)"
    if ($_.Exception.Response) {
        Write-Host "[RESPONSE STATUS] $($_.Exception.Response.StatusCode.value__)"
    }
}

Write-Host "[DONE]"