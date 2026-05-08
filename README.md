# OEWA - 企业级AI Agent工作流自动化平台

## 🚀 简介
OEWA（OpenClaw Enterprise Workflow Automation）是一个企业级AI Agent工作流自动化平台，让企业用户通过可视化拖拽方式编排AI Agent工作流，实现业务流程自动化。

## ✨ 特性
- 🎨 **可视化编排**：基于VueFlow的拖拽式工作流画布
- 🤖 **AI Agent原生**：深度集成LLM，支持多种AI模型
- 🏢 **企业级**：支持私有部署、多租户、权限管理
- 📊 **实时监控**：执行状态监控、历史记录查询、性能指标
- 📋 **行业模板**：电商客服、营销自动化、数据报告等预置模板

## 🛠️ 技术栈
- **后端**：FastAPI + Uvicorn + Python 3.10+
- **前端**：Vue3 + Vite + VueFlow
- **执行引擎**：Python执行器，支持YAML配置
- **部署**：Docker + Docker Compose + Nginx

## 🚀 快速开始（MVP 1.0）
### 后端启动
```bash
cd OEWA-backend
pip install -r requirements.txt
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

### 前端启动
```bash
cd OEWA-frontend
npm install
npm run dev -- --host 0.0.0.0 --port 3000
```

### 访问
- 前端：http://localhost:3000
- 后端API文档：http://localhost:8000/docs

## 📋 商业化状态
- ✅ MVP 1.0 已交付（2026-05-08）
- 🚀 商业化启动中（2026-05-08）
- 💼 天使轮融资目标：500万元（估值5000万元）
- 📈 第一年收入预测：1096万元

## 🤝 合作联系
- **CEO**：vp（集团CEO，幽默干练）
- **商务合作**：business@oewa.com（待注册）
- **技术支持**：support@oewa.com（待注册）

## 📄 许可证
- **商业版**：专有许可证（私有部署）
- **开源核心**：Apache 2.0（核心引擎待开源）

---
**🎉 MVP 1.0 交付：** 21小时从0到1，团队执行力优秀！  
**🚀 商业化目标：** 第一年客户数760家，收入1096万元。
