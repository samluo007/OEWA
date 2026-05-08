from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional, Dict, Any, List
import uuid
import yaml
import json
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

@app.get("/")
async def root():
    return {"message": "OEWA API is running", "version": "0.1"}

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
    raise HTTPException(status_code=404, detail="Execution not found")

@app.get("/api/monitoring/stats")
async def get_monitoring_stats():
    return {"total_executions": 0, "success_count": 0, "failed_count": 0, "avg_duration_ms": 0.0}

@app.get("/api/monitoring/recent-executions")
async def get_recent_executions(limit: int = 10):
    return []

@app.get("/api/templates")
async def get_templates():
    return [
        {"id": "ecommerce_cs", "name": "电商客服自动化", "industry": "ecommerce", "nodes_count": 5},
        {"id": "marketing_auto", "name": "营销自动化", "industry": "marketing", "nodes_count": 8},
        {"id": "data_report", "name": "数据报告生成", "industry": "customer_service", "nodes_count": 4},
        {"id": "xhs_xianyu_marketing", "name": "小红书咸鱼营销自动化", "industry": "ecommerce", "nodes_count": 6}
    ]

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8001)
