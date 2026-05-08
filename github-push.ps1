# Push OEWA to GitHub using user-provided PAT
$token = "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"
$headers = @{
    Authorization = "Bearer $token"
    Accept = "application/vnd.github+json"
    "X-GitHub-Api-Version" = "2022-11-28"
}

$repoName = "OEWA"
$orgOrUser = "samluo007"

Write-Host "[Step 1: Creating repo $repoName]"

# Check if repo already exists
try {
    $check = Invoke-RestMethod -Uri "https://api.github.com/repos/$orgOrUser/$repoName" -Headers $headers -TimeoutSec 10
    Write-Host "[Repo already exists - skipping creation]"
    $repoUrl = "https://github.com/$orgOrUser/$repoName"
} catch {
    # Create the repo
    Write-Host "[Creating new repo...]"
    $body = @{
        name = $repoName
        description = "Enterprise AI Agent Workflow Automation Platform - MVP 1.0"
        homepage = "http://192.168.10.5:3003"
        private = $false
        has_wiki = $true
        auto_init = $false
    } | ConvertTo-Json -Compress
    
    try {
        $r = Invoke-RestMethod -Uri "https://api.github.com/user/repos" -Headers $headers -Method Post -Body $body -ContentType "application/json" -TimeoutSec 15
        $repoUrl = $r.html_url
        Write-Host "[Repo created: $repoUrl]"
    } catch {
        Write-Host "[CREATE ERROR: $($_.Exception.Message)]"
        $repoUrl = "https://github.com/$orgOrUser/$repoName"
        Write-Host "[Using $repoUrl]"
    }
}

# Step 2: Add remote and push
$workDir = "C:\Users\Administrator\.qclaw\workspace-agent-ef4666a4"
Set-Location $workDir

# Check if git remote already set
$remote = git remote get-url origin 2>$null
if ($remote) {
    Write-Host "[Remote already: $remote]"
    git remote set-url origin "https://samluo007:${token}@github.com/samluo007/OEWA.git"
} else {
    Write-Host "[Setting remote]"
    git remote add origin "https://samluo007:${token}@github.com/samluo007/OEWA.git"
}

# Check .gitignore
if (-not (Test-Path "$workDir\.gitignore")) {
    Write-Host "[Creating .gitignore]"
    @"
# Python
__pycache__/
*.py[cod]
*.egg-info/
venv/
.venv/
env/

# Node
node_modules/
dist/
*.log

# IDE
.vscode/
.idea/
*.swp

# OS
.DS_Store
Thumbs.db

# Local
*.local
.env

# Project specific
*.zip
github-pat*.ps1
github-auth*.ps1
"@ | Out-File "$workDir\.gitignore" -Encoding UTF8
}

# Stage files
Write-Host "[Staging files...]"
git add -A

# Check what will be committed
$status = git status --short
Write-Host "=== FILES TO COMMIT ==="
Write-Host $status

# Commit
Write-Host "[Committing...]"
git commit -m "feat: OEWA v1.0 - Enterprise AI Agent Workflow Automation Platform

- FastAPI backend with workflow execution engine
- Vue3 frontend with visual flow canvas
- 3 industry templates (ecommerce/marketing/data)
- Docker deployment ready
- CRUD API + monitoring dashboard
- Real LLM integration (GPT-4o)

MVP completed May 7-8, 2026" 2>&1

# Push
Write-Host "[Pushing to GitHub...]"
git push origin master 2>&1
Write-Host "[PUSH DONE]"

Write-Host "[REPO URL: $repoUrl]"