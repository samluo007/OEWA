import uuid
import yaml
import json
from datetime import datetime

class WorkflowExecutor:
    def __init__(self):
        self.memory_store = {}  # 内存存储执行记录

    async def execute(self, workflow_id: str, yaml_config: str, input_data: dict):
        execution_id = str(uuid.uuid4())
        started_at = datetime.now().isoformat()

        try:
            # 解析YAML
            config = yaml.safe_load(yaml_config)
            nodes = config.get("nodes", [])
            edges = config.get("edges", [])

            # 简单模拟执行：按节点顺序执行（不处理条件分支）
            results = {}
            for node in nodes:
                node_id = node["id"]
                node_type = node["type"]
                # 模拟节点执行结果
                results[node_id] = {
                    "status": "success",
                    "output": f"节点 {node_id} ({node_type}) 执行完成"
                }

            finished_at = datetime.now().isoformat()
            duration_ms = 100  # 模拟耗时

            # 记录执行结果
            execution_record = {
                "id": execution_id,
                "workflow_id": workflow_id,
                "status": "success",
                "input_data": input_data,
                "output_data": {"summary": f"工作流执行完成，共执行{len(nodes)}个节点", "results": results},
                "started_at": started_at,
                "finished_at": finished_at,
                "duration_ms": duration_ms
            }

            self.memory_store[f"execution:{execution_id}"] = json.dumps(execution_record)
            self.memory_store[f"workflow:{workflow_id}:last_execution"] = execution_id

            return execution_record

        except Exception as e:
            finished_at = datetime.now().isoformat()
            execution_record = {
                "id": execution_id,
                "workflow_id": workflow_id,
                "status": "error",
                "error": str(e),
                "started_at": started_at,
                "finished_at": finished_at,
                "duration_ms": 0
            }
            self.memory_store[f"execution:{execution_id}"] = json.dumps(execution_record)
            raise
