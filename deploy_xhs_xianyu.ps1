# 小红书咸鱼项目 - 一键部署脚本
# 作者：vp (CEO)
# 时间：2026-05-08 03:37
# 权限：最高权限（自主决策）

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  小红书咸鱼项目 - 一键部署" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 1. 检查依赖
Write-Host "[1/5] 检查依赖..." -ForegroundColor Green
try {
    $pythonVersion = python --version 2>&1
    Write-Host "  Python: $pythonVersion" -ForegroundColor Gray
} catch {
    Write-Host "  [错误] Python未安装，请先安装Python 3.8+" -ForegroundColor Red
    exit 1
}

try {
    $nodeVersion = node --version 2>&1
    Write-Host "  Node.js: $nodeVersion" -ForegroundColor Gray
} catch {
    Write-Host "  [错误] Node.js未安装，请先安装Node.js 16+" -ForegroundColor Red
    exit 1
}

# 2. 安装后端依赖
Write-Host "[2/5] 安装后端依赖..." -ForegroundColor Green
Set-Location "C:\Users\Administrator\.qclaw\workspace-agent-ef4666a4\OEWA-backend"
if (-not (Test-Path "venv")) {
    Write-Host "  创建虚拟环境..." -ForegroundColor Gray
    python -m venv venv
}
.\venv\Scripts\pip install -r requirements.txt
if ($LASTEXITCODE -ne 0) {
    Write-Host "  [警告] 依赖安装失败，尝试逐个安装..." -ForegroundColor Yellow
    .\venv\Scripts\pip install fastapi uvicorn pyyaml
}

# 3. 安装前端依赖
Write-Host "[3/5] 安装前端依赖..." -ForegroundColor Green
Set-Location "C:\Users\Administrator\.qclaw\workspace-agent-ef4666a4\OEWA-frontend"
.\venv\Scripts\pip install -r requirements.txt 2>$null
npm install
if ($LASTEXITCODE -ne 0) {
    Write-Host "  [警告] npm安装失败，请检查网络" -ForegroundColor Yellow
}

# 4. 启动后端服务
Write-Host "[4/5] 启动后端服务..." -ForegroundColor Green
Set-Location "C:\Users\Administrator\.qclaw\workspace-agent-ef4666a4\OEWA-backend"
Start-Process -FilePath ".\venv\Scripts\python" -ArgumentList "main.py" -WindowStyle Normal
Write-Host "  后端启动中... (http://localhost:8000)" -ForegroundColor Gray
Start-Sleep -Seconds 3

# 5. 启动前端服务
Write-Host "[5/5] 启动前端服务..." -ForegroundColor Green
Set-Location "C:\Users\Administrator\.qclaw\workspace-agent-ef4666a4\OEWA-frontend"
Start-Process -FilePath "npm" -ArgumentList "run", "dev" -WindowStyle Normal
Write-Host "  前端启动中... (http://localhost:3001)" -ForegroundColor Gray

# 完成
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  部署完成！" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "后端API: http://localhost:8000" -ForegroundColor Green
Write-Host "前端界面: http://localhost:3001" -ForegroundColor Green
Write-Host "API文档: http://localhost:8000/docs" -ForegroundColor Green
Write-Host ""
Write-Host "下一步：" -ForegroundColor Yellow
Write-Host "1. 打开前端界面，进入工作流设计器" -ForegroundColor Gray
Write-Host "2. 选择'小红书咸鱼营销自动化'模板" -ForegroundColor Gray
Write-Host "3. 拖拽配置节点，点击执行" -ForegroundColor Gray
Write-Host "4. 查看监控面板，分析效果" -ForegroundColor Gray
Write-Host ""
Write-Host "CEO决策：03:37完成部署脚本，等待执行指令。" -ForegroundColor Magenta
