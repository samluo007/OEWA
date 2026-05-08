# OEWA 部署指南 v1.0

## 🐳 Docker 部署（推荐）

### 前提条件
- Docker 20.10+
- Docker Compose 1.29+
- 最低配置：2核CPU，4GB内存，20GB磁盘

### 快速部署

**步骤1：下载项目**
```bash
git clone https://github.com/oewa/oewa.git
cd oewa
```

**步骤2：配置环境变量**
```bash
cp .env.example .env
# 编辑 .env 文件，配置数据库密码等
```

**步骤3：启动服务**
```bash
docker-compose up -d
```

**步骤4：验证部署**
```bash
# 检查服务状态
docker-compose ps

# 检查后端API
curl http://localhost:8000/api/workflows

# 检查前端
curl http://localhost:3000
```

### 访问服务
- 前端：http://localhost:3000
- 后端API：http://localhost:8000
- API文档：http://localhost:8000/docs

### 停止服务
```bash
docker-compose down
```

### 重新部署
```bash
docker-compose down && docker-compose up -d
```

---

## ☁️ 云服务器部署

### 阿里云/腾讯云部署

**步骤1：购买云服务器**
- 选择Ubuntu 20.04 LTS或CentOS 7
- 配置：2核4GB，带公网IP
- 开放端口：22（SSH）、80（HTTP）、443（HTTPS）、8000、3000

**步骤2：安装Docker**
```bash
# Ubuntu
curl -fsSL https://get.docker.com | sh
sudo systemctl enable docker
sudo systemctl start docker

# CentOS
sudo yum install -y docker
sudo systemctl enable docker
sudo systemctl start docker
```

**步骤3：安装Docker Compose**
```bash
sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

**步骤4：上传项目**
```bash
# 使用scp上传项目
scp -r oewa-archive.tar.gz root@your-server:/opt/oewa/
ssh root@your-server
cd /opt/oewa
tar -xzf oewa-archive.tar.gz
```

**步骤5：配置域名（可选）**
```bash
# 购买域名，配置DNS解析
# 配置Nginx反向代理
```

**步骤6：启动服务**
```bash
docker-compose up -d
```

**步骤7：配置SSL证书（可选）**
```bash
# 使用Let's Encrypt免费证书
sudo apt install certbot
sudo certbot --nginx -d yourdomain.com
```

---

## 🐧 Linux 服务器手动部署

### 后端部署

**步骤1：安装Python 3.10+**
```bash
# Ubuntu
sudo apt update
sudo apt install python3.10 python3.10-venv python3-pip

# CentOS
sudo yum install python310 python310-pip
```

**步骤2：创建项目目录**
```bash
mkdir -p /opt/oewa/backend
cd /opt/oewa/backend
```

**步骤3：安装依赖**
```bash
python3.10 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

**步骤4：配置环境变量**
```bash
export DATABASE_URL=postgresql://user:pass@localhost:5432/oewa
export REDIS_URL=redis://localhost:6379/0
```

**步骤5：启动后端服务**
```bash
# 开发环境
uvicorn main:app --reload --host 0.0.0.0 --port 8000

# 生产环境（使用systemd）
sudo nano /etc/systemd/system/oewa-backend.service
```

**systemd服务文件示例：**
```ini
[Unit]
Description=OEWA Backend Service
After=network.target

[Service]
User=www-data
Group=www-data
WorkingDirectory=/opt/oewa/backend
ExecStart=/opt/oewa/backend/venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000
Restart=always

[Install]
WantedBy=multi-user.target
```

**启动服务：**
```bash
sudo systemctl enable oewa-backend
sudo systemctl start oewa-backend
sudo systemctl status oewa-backend
```

### 前端部署

**步骤1：安装Node.js 18+**
```bash
# Ubuntu
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt install nodejs

# 验证
node --version
npm --version
```

**步骤2：构建前端**
```bash
cd /opt/oewa/frontend
npm install
npm run build
```

**步骤3：配置Nginx**
```bash
sudo apt install nginx
sudo nano /etc/nginx/sites-available/oewa
```

**Nginx配置示例：**
```nginx
server {
    listen 80;
    server_name yourdomain.com;

    root /opt/oewa/frontend/dist;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    location /api {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

**启用配置：**
```bash
sudo ln -s /etc/nginx/sites-available/oewa /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

---

## 📊 数据库配置

### PostgreSQL 安装

**步骤1：安装PostgreSQL**
```bash
# Ubuntu
sudo apt install postgresql postgresql-contrib

# 启动服务
sudo systemctl enable postgresql
sudo systemctl start postgresql
```

**步骤2：创建数据库**
```bash
sudo -u postgres psql

# 在psql中执行
CREATE DATABASE oewa_db;
CREATE USER oewa WITH PASSWORD 'your_password';
GRANT ALL PRIVILEGES ON DATABASE oewa_db TO oewa;
\q
```

### Redis 安装

**步骤1：安装Redis**
```bash
# Ubuntu
sudo apt install redis-server

# 启动服务
sudo systemctl enable redis-server
sudo systemctl start redis-server
```

**步骤2：验证Redis**
```bash
redis-cli ping
# 应返回 PONG
```

---

## 🔒 安全配置

### 防火墙配置
```bash
# Ubuntu (UFW)
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable

# 仅限特定IP访问API
sudo ufw allow from 192.168.1.0/24 to any port 8000
```

### SSL证书配置
```bash
# 使用Let's Encrypt
sudo apt install certbot python3-certbot-nginx
sudo certbot --nginx -d yourdomain.com -d api.yourdomain.com
```

### 数据库安全
```sql
-- 限制数据库用户权限
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO oewa;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO oewa;
```

---

## 📈 性能优化

### 后端优化
1. **启用Gunicorn多进程**
   ```bash
   gunicorn main:app -w 4 -k uvicorn.workers.UvicornWorker --bind 0.0.0.0:8000
   ```

2. **配置Redis缓存**
   ```python
   # 在main.py中配置缓存
   from fastapi_cache import FastAPICache
   from fastapi_cache.backends.redis import RedisBackend
   
   redis = RedisRedis(host='localhost', port=6379, db=0)
   FastAPICache.init(RedisBackend(redis), prefix="oewa")
   ```

### 前端优化
1. **启用Gzip压缩**
   ```nginx
   gzip on;
   gzip_types text/plain text/css application/json application/javascript;
   gzip_min_length 1000;
   ```

2. **配置CDN**
   ```html
   <!-- 在index.html中引用CDN资源 -->
   <script src="https://cdn.example.com/vue3.4.21.min.js"></script>
   ```

---

## 🛠️ 运维监控

### 日志配置
```bash
# 查看后端日志
docker-compose logs -f backend

# 查看Nginx日志
tail -f /var/log/nginx/access.log
tail -f /var/log/nginx/error.log
```

### 健康检查
```bash
# 后端健康检查
curl http://localhost:8000/

# 前端健康检查
curl http://localhost:3000/

# 数据库健康检查
sudo -u postgres psql -c "SELECT 1"
```

### 自动备份
```bash
# 数据库备份脚本
#!/bin/bash
DATE=$(date +%Y%m%d)
BACKUP_DIR=/opt/backups/oewa
mkdir -p $BACKUP_DIR
pg_dump -U oewa -d oewa_db > $BACKUP_DIR/oewa_$DATE.sql
# 保留最近30天备份
find $BACKUP_DIR -name "*.sql" -mtime +30 -delete
```

---
**版本：** v1.0  
**更新日期：** 2026-05-08  
**技术支持：** support@oewa.com