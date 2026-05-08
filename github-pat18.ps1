# Validate the user-provided token
$tokenFile = "$env:USERPROFILE\.qclaw\oe_github_token.txt"

# The token was provided by user: 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
# Write it to file if not already there
$tokenContent = "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"
if (-not (Test-Path $tokenFile)) {
    $tokenContent | Out-File -FilePath $tokenFile -Encoding UTF8
    Write-Host "[Token written to $tokenFile]"
} else {
    $tokenContent = Get-Content $tokenFile -Raw
    Write-Host "[Token read from file]"
}

Write-Host "[Token length] $($tokenContent.Length)"
$headers = @{
    Authorization = "Bearer $tokenContent"
    Accept = "application/vnd.github+json"
}

Write-Host "[Testing API call...]"
try {
    $r = Invoke-RestMethod -Uri "https://api.github.com/user" -Headers $headers -TimeoutSec 15
    Write-Host "[API SUCCESS!]"
    $r | ConvertTo-Json -Depth 3
} catch {
    Write-Host "[ERROR: $($_.Exception.Message)]"
    if ($_.Exception.Response) {
        Write-Host "[STATUS: $($_.Exception.Response.StatusCode.value__)]"
    }
}