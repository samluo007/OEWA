# OEWA API 文档 v1.0

## 📋 概述
OEWA API是基于FastAPI构建的RESTful API，提供工作流管理、执行引擎、监控面板等核心功能。

**基础URL：** `http://localhost:8000/api`  
**认证：** 暂无（Phase 2将增加API Key认证）  
**格式：** JSON

---

## 📂 工作流 API

### 1. 获取工作流列表
**请求：**
```http
GET /api/workflows
```
**响应：**
```json
{
  "id": "uuid",
  "name": "工作流名称",
  "description": "描述",
  "industry": "电商",
  "yaml_config": "...",
  "status": "draft|active|archived",
  "created_at": "2026-05-08T12:00:00",
  "updated_at": "2026-05-08T12:00:00"
}
```

### 2. 创建工作流
**请求：**
```http
POST /api/workflows
Content-Type: application/json

{
  "name": "电商客服自动化",
  "description": "处理客户咨询",
  "industry": "ecommerce",
  "yaml_config": "nodes:\n  - id: node_1\n    type: llm"
}
```
**响应：**
```json
{
  "id": "uuid",
  "name": "电商客服自动化",
  ...
}
```

### 3. 获取单个工作流
**请求：**
```http
GET /api/workflows/{workflow_id}
```

### 4. 更新工作流
**请求：**
```http
PUT /api/workflows/{workflow_id}
Content-Type: application/json

{
  "name": "新名称",
  "description": "新描述",
  "industry": "ecommerce",
  "yaml_config": "..."
}
```

### 5. 删除工作流
**请求：**
```http
DELETE /api/workflows/{workflow_id}
```
**响应：**
```json
{
  "message": "Workflow deleted successfully"
}
```

---

## 🤖 执行 API

### 6. 执行工作流
**请求：**
```http
POST /api/workflows/{workflow_id}/execute
Content-Type: application/json

{
  "input_data": {
    "customer_id": "C001",
    "query": "我想退货"
  }
}
```
**响应：**
```json
{
  "id": "execution_uuid",
  "workflow_id": "workflow_uuid",
  "status": "success",
  "input_data": {...},
  "output_data": {
    "summary": "工作流执行完成，共执行3个节点",
    "results": {
      "node_1": {"status": "success", "output": "..."},
      "node_2": {"status": "success", "output": "..."}
    }
  },
  "started_at": "2026-05-08T12:00:00",
  "finished_at": "2026-05-08T12:00:05",
  "duration_ms": 5000
}
```

### 7. 获取执行记录
**请求：**
```http
GET /api/executions/{execution_id}
```

---

## 📊 监控 API

### 8. 获取监控统计
**请求：**
```http
GET /api/monitoring/stats
```
**响应：**
```json
{
  "total_executions": 150,
  "success_count": 145,
  "failed_count": 5,
  "avg_duration_ms": 2300.5
}
```

### 9. 获取最近执行记录
**请求：**
```http
GET /api/monitoring/recent-executions?limit=10
```
**响应：**
```json
[
  {
    "id": "execution_uuid",
    "workflow_id": "workflow_uuid",
    "status": "success",
    "started_at": "2026-05-08T12:00:00",
    "finished_at": "2026-05-08T12:00:05"
  }
]
```

---

## 🧩 节点类型 API

### 10. 获取节点类型列表
**请求：**
```http
GET /api/node/types
```
**响应：**
```json
[
  {"type": "llm", "name": "LLM节点", "icon": "brain", "inputs": ["prompt"], "outputs": ["response"]},
  {"type": "code", "name": "代码执行节点", "icon": "code", "inputs": ["code"], "outputs": ["result"]},
  {"type": "http", "name": "HTTP请求节点", "icon": "globe", "inputs": ["url", "method"], "outputs": ["response"]},
  {"type": "condition", "name": "条件分支节点", "icon": "git-branch", "inputs": ["condition"], "outputs": ["true", "false"]}
]
```

---

## 📋 模板 API

### 11. 获取行业模板列表
**请求：**
```http
GET /api/templates
```
**响应：**
```json
[
  {"id": "ecommerce_cs", "name": "电商客服自动化", "industry": "ecommerce", "nodes_count": 5},
  {"id": "marketing_auto", "name": "营销自动化", "industry": "marketing", "nodes_count": 8},
  {"id": "data_report", "name": "数据报告生成", "industry": "customer_service", "nodes_count": 4},
  {"id": "xhs_xianyu_marketing", "name": "小红书咸鱼营销自动化", "industry": "ecommerce", "nodes_count": 6}
]
```

---

## ⚠️ 错误码

| 状态码 | 说明 |
|--------|------|
| 200 | 成功 |
| 400 | 请求参数错误 |
| 404 | 资源不存在 |
| 500 | 服务器内部错误 |

---

## 🔧 错误响应示例
```json
{
  "detail": "Workflow not found"
}
```

---
**版本：** v1.0  
**更新日期：** 2026-05-08  
**API文档：** http://localhost:8000/docs（Swagger UI）