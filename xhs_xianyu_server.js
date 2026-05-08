const express = require('express');
const yaml = require('js-yaml');
const fs = require('fs');
const app = express();
const PORT = 8000;

app.use(express.json());

// 加载工作流模板
let workflows = {};
try {
  const templatePath = 'C:\\Users\\Administrator\\.qclaw\\workspace-agent-ef4666a4\\OEWA-backend\\templates\\xhs_xianyu_marketing.yaml';
  const templateContent = fs.readFileSync(templatePath, 'utf8');
  const template = yaml.load(templateContent);
  workflows['xhs_xianyu_marketing'] = {
    id: 'xhs_xianyu_marketing',
    name: template.name,
    description: template.description,
    industry: template.industry,
    yaml_config: templateContent,
    status: 'active',
    created_at: new Date().toISOString(),
    updated_at: new Date().toISOString()
  };
  console.log('✅ 模板加载成功:', template.name);
} catch (err) {
  console.error('❌ 模板加载失败:', err.message);
}

// API: 列出工作流
app.get('/api/workflows', (req, res) => {
  res.json(Object.values(workflows));
});

// API: 获取模板列表
app.get('/api/templates', (req, res) => {
  res.json([
    {id: 'xhs_xianyu_marketing', name: '小红书咸鱼营销自动化', industry: 'ecommerce', nodes_count: 6}
  ]);
});

// API: 执行工作流（模拟）
app.post('/api/workflows/:id/execute', (req, res) => {
  const workflowId = req.params.id;
  if (!workflows[workflowId]) {
    return res.status(404).json({error: 'Workflow not found'});
  }
  
  const workflow = workflows[workflowId];
  const config = yaml.load(workflow.yaml_config);
  const nodes = config.nodes || [];
  
  // 模拟执行
  const results = {};
  nodes.forEach(node => {
    results[node.id] = {
      status: 'success',
      output: `节点 ${node.name} 执行完成`,
      type: node.type
    };
  });
  
  res.json({
    id: require('crypto').randomUUID(),
    workflow_id: workflowId,
    status: 'success',
    output_data: {
      summary: `工作流执行完成，共执行${nodes.length}个节点`,
      results: results,
      demo: {
        xhs_post: '小红书笔记发布成功（模拟）',
        xianyu_item: '闲鱼商品上架成功（模拟）',
        conversion_rate: '3.2%（模拟数据）'
      }
    },
    started_at: new Date().toISOString(),
    finished_at: new Date().toISOString(),
    duration_ms: 1500
  });
});

// API: 监控统计
app.get('/api/monitoring/stats', (req, res) => {
  res.json({
    total_executions: 1,
    success_count: 1,
    failed_count: 0,
    avg_duration_ms: 1500
  });
});

app.listen(PORT, () => {
  console.log(`\n========================================`);
  console.log(`  🚀 小红书咸鱼项目API服务已启动`);
  console.log(`========================================`);
  console.log(`  后端API: http://localhost:${PORT}`);
  console.log(`  API文档: http://localhost:${PORT}/api/workflows`);
  console.log(`  执行测试: POST http://localhost:${PORT}/api/workflows/xhs_xianyu_marketing/execute`);
  console.log(`========================================\n`);
});
