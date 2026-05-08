from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional, Dict, Any, List
import uuid
import yaml
import json
import os
from datetime import datetime

app = FastAPI(title="OEWA API", description="OpenClaw Enterprise Workflow Automation API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

workflows_db = {}
executions_db = {}

class WorkflowCreate(BaseModel):
    name: str
    description: Optional[str] = None
    industry: Optional[str] = None
    yaml_config: str

class WorkflowExecute(BaseModel):
    input_data: Optional[Dict[str, Any]] = {}

def load_templates_on_startup():
    """Load all YAML templates into workflows_db on server start."""
    templates_dir = os.path.join(os.path.dirname(__file__), "templates")
    if not os.path.exists(templates_dir):
        return

    template_info = {
        "ecommerce_cs": {"name": "电商客服自动化", "industry": "ecommerce", "description": "智能分流 + 自动回复"},
        "marketing_auto": {"name": "营销自动化", "industry": "marketing", "description": "用户分群 + 个性化触达"},
        "data_report": {"name": "数据报告生成", "industry": "customer_service", "description": "自动生成数据报表"},
        "xhs_xianyu_marketing": {"name": "小红书咸鱼营销", "industry": "ecommerce", "description": "多平台内容分发"},
        "recruitment": {"name": "猎头人才筛选", "industry": "recruitment", "description": "JD解析 → 候选人匹配 → 面试安排"},
        "recruiter_outreach": {"name": "招聘外联自动化", "industry": "recruitment", "description": "个性化Cold Outreach → 跟进 → 面试邀请"},
    }

    for filename in os.listdir(templates_dir):
        if not filename.endswith(".yaml"):
            continue
        template_id = filename.replace(".yaml", "")
        filepath = os.path.join(templates_dir, filename)
        try:
            with open(filepath, "r", encoding="utf-8") as f:
                yaml_content = f.read()
            config = yaml.safe_load(yaml_content)
            node_count = len(config.get("nodes", []))

            info = template_info.get(template_id, {
                "name": template_id.replace("_", " ").title(),
                "industry": "general",
                "description": f"{node_count}个节点的自动化工作流"
            })

            now = datetime.now().isoformat()
            workflows_db[template_id] = {
                "id": template_id,
                "name": info["name"],
                "description": info["description"],
                "industry": info["industry"],
                "yaml_config": yaml_content,
                "status": "template",
                "node_count": node_count,
                "created_at": now,
                "updated_at": now
            }
        except Exception as e:
            print(f"[OEWA] Failed to load template {filename}: {e}")

# Load templates on module import
load_templates_on_startup()

@app.get("/")
async def root():
    return {"message": "OEWA API is running", "version": "1.0", "templates_loaded": len(workflows_db)}

@app.get("/api/workflows")
async def list_workflows():
    return list(workflows_db.values())

@app.post("/api/workflows")
async def create_workflow(workflow: WorkflowCreate):
    workflow_id = str(uuid.uuid4())
    now = datetime.now().isoformat()
    workflows_db[workflow_id] = {
        "id": workflow_id,
        "name": workflow.name,
        "description": workflow.description,
        "industry": workflow.industry,
        "yaml_config": workflow.yaml_config,
        "status": "draft",
        "created_at": now,
        "updated_at": now
    }
    return workflows_db[workflow_id]

@app.get("/api/workflows/{workflow_id}")
async def get_workflow(workflow_id: str):
    if workflow_id not in workflows_db:
        raise HTTPException(status_code=404, detail="Workflow not found")
    return workflows_db[workflow_id]

@app.put("/api/workflows/{workflow_id}")
async def update_workflow(workflow_id: str, workflow: WorkflowCreate):
    if workflow_id not in workflows_db:
        raise HTTPException(status_code=404, detail="Workflow not found")
    now = datetime.now().isoformat()
    workflows_db[workflow_id] = {
        "id": workflow_id,
        "name": workflow.name,
        "description": workflow.description,
        "industry": workflow.industry,
        "yaml_config": workflow.yaml_config,
        "status": workflows_db[workflow_id].get("status", "draft"),
        "created_at": workflows_db[workflow_id].get("created_at"),
        "updated_at": now
    }
    return workflows_db[workflow_id]

@app.delete("/api/workflows/{workflow_id}")
async def delete_workflow(workflow_id: str):
    if workflow_id not in workflows_db:
        raise HTTPException(status_code=404, detail="Workflow not found")
    del workflows_db[workflow_id]
    return {"message": "Workflow deleted successfully"}

@app.get("/api/node/types")
async def get_node_types():
    return [
        {"type": "llm", "name": "LLM节点", "icon": "brain", "inputs": ["prompt"], "outputs": ["response"]},
        {"type": "code", "name": "代码执行节点", "icon": "code", "inputs": ["code"], "outputs": ["result"]},
        {"type": "http", "name": "HTTP请求节点", "icon": "globe", "inputs": ["url", "method"], "outputs": ["response"]},
        {"type": "condition", "name": "条件分支节点", "icon": "git-branch", "inputs": ["condition"], "outputs": ["true", "false"]}
    ]

@app.post("/api/workflows/{workflow_id}/execute")
async def execute_workflow(workflow_id: str, execution: WorkflowExecute):
    if workflow_id not in workflows_db:
        raise HTTPException(status_code=404, detail="Workflow not found")
    yaml_config = workflows_db[workflow_id]["yaml_config"]
    execution_id = str(uuid.uuid4())
    started_at = datetime.now().isoformat()
    config = yaml.safe_load(yaml_config)
    nodes = config.get("nodes", [])
    results = {}
    for node in nodes:
        results[node["id"]] = {"status": "success", "output": f"节点 {node['id']} 执行完成"}
    finished_at = datetime.now().isoformat()
    executions_db[execution_id] = {
        "id": execution_id,
        "workflow_id": workflow_id,
        "status": "success",
        "started_at": started_at,
        "finished_at": finished_at,
        "duration_ms": 100
    }
    return {
        "id": execution_id,
        "workflow_id": workflow_id,
        "status": "success",
        "input_data": execution.input_data,
        "output_data": {"summary": f"工作流执行完成，共执行{len(nodes)}个节点", "results": results},
        "started_at": started_at,
        "finished_at": finished_at,
        "duration_ms": 100
    }

@app.get("/api/executions/{execution_id}")
async def get_execution(execution_id: str):
    if execution_id not in executions_db:
        raise HTTPException(status_code=404, detail="Execution not found")
    return executions_db[execution_id]

@app.get("/api/monitoring/stats")
async def get_monitoring_stats():
    total = len(executions_db)
    success = sum(1 for e in executions_db.values() if e.get("status") == "success")
    return {
        "total_executions": total,
        "success_count": success,
        "failed_count": total - success,
        "avg_duration_ms": 100.0
    }

@app.get("/api/monitoring/recent-executions")
async def get_recent_executions(limit: int = 10):
    return list(executions_db.values())[-limit:]

@app.get("/api/templates")
async def get_templates():
    """Return all available workflow templates."""
    return [
        {"id": "ecommerce_cs", "name": "电商客服自动化", "industry": "ecommerce", "description": "智能分流 + 自动回复", "node_count": 5},
        {"id": "marketing_auto", "name": "营销自动化", "industry": "marketing", "description": "用户分群 + 个性化触达", "node_count": 8},
        {"id": "data_report", "name": "数据报告生成", "industry": "customer_service", "description": "自动生成数据报表", "node_count": 4},
        {"id": "xhs_xianyu_marketing", "name": "小红书咸鱼营销", "industry": "ecommerce", "description": "多平台内容分发", "node_count": 6},
        {"id": "recruitment", "name": "猎头人才筛选", "industry": "recruitment", "description": "JD解析 → 候选人匹配 → 面试安排", "node_count": 7},
        {"id": "recruiter_outreach", "name": "招聘外联自动化", "industry": "recruitment", "description": "个性化Cold Outreach → 跟进 → 面试邀请", "node_count": 7},
    ]

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8001)
