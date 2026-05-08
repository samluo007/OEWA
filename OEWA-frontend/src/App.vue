<template>
  <div class="app-container">
    <header class="app-header">
      <h1>🛠️ OEWA - 企业级AI Agent工作流自动化平台</h1>
      <div class="header-actions">
        <button @click="loadWorkflows">刷新</button>
        <button @click="showCreateModal = true">新建工作流</button>
      </div>
    </header>
    
    <main class="app-main">
      <aside class="sidebar">
        <h3>📋 工作流列表</h3>
        <div v-if="loading" class="loading">加载中...</div>
        <div v-else-if="workflows.length === 0" class="empty">
          暂无工作流，点击上方"新建工作流"创建
        </div>
        <ul v-else class="workflow-list">
          <li 
            v-for="wf in workflows" 
            :key="wf.id"
            :class="{ active: selectedWorkflow?.id === wf.id }"
            @click="selectWorkflow(wf)"
          >
            <span class="wf-name">{{ wf.name }}</span>
            <span class="wf-industry">{{ wf.industry || '未分类' }}</span>
          </li>
        </ul>
        
        <!-- 监控面板 -->
        <div class="monitoring-section">
          <h3>📊 监控面板</h3>
          <MonitoringPanel />
        </div>
      </aside>
      
      <section class="main-content">
        <div v-if="selectedWorkflow" class="workflow-editor">
          <div class="editor-header">
            <h2>{{ selectedWorkflow.name }}</h2>
            <div class="editor-actions">
              <button @click="executeWorkflow(selectedWorkflow.id)">执行</button>
              <button @click="saveWorkflow">保存</button>
            </div>
          </div>
          <FlowCanvas :workflow="selectedWorkflow" @save="saveWorkflow" />
        </div>
        <div v-else class="welcome">
          <h2>欢迎使用OEWA</h2>
          <p>请从左侧选择工作流，或新建一个</p>
        </div>
      </section>
    </main>
    
    <!-- 新建工作流模态框 -->
    <div v-if="showCreateModal" class="modal-overlay" @click.self="showCreateModal = false">
      <div class="modal-content">
        <h3>新建工作流</h3>
        <form @submit.prevent="createWorkflow">
          <div class="form-group">
            <label>名称</label>
            <input v-model="newWorkflow.name" required />
          </div>
          <div class="form-group">
            <label>描述</label>
            <textarea v-model="newWorkflow.description"></textarea>
          </div>
          <div class="form-group">
            <label>行业</label>
            <select v-model="newWorkflow.industry">
              <option value="">未分类</option>
              <option value="ecommerce">电商</option>
              <option value="marketing">营销</option>
              <option value="customer_service">客服</option>
            </select>
          </div>
          <div class="form-actions">
            <button type="button" @click="showCreateModal = false">取消</button>
            <button type="submit">创建</button>
          </div>
        </form>
      </div>
    </div>
  </div>
</template>

<script>
import { ref, onMounted } from 'vue';
import FlowCanvas from './components/FlowCanvas.vue';
import MonitoringPanel from './components/MonitoringPanel.vue';
import axios from 'axios';

export default {
  components: { FlowCanvas, MonitoringPanel },
  setup() {
    const workflows = ref([]);
    const selectedWorkflow = ref(null);
    const loading = ref(false);
    const showCreateModal = ref(false);
    const newWorkflow = ref({ name: '', description: '', industry: '' });

    const API_BASE = 'http://localhost:8000/api';

    const loadWorkflows = async () => {
      loading.value = true;
      try {
        const res = await axios.get(`${API_BASE}/workflows`);
        workflows.value = res.data;
      } catch (e) {
        console.error('加载工作流失败', e);
      } finally {
        loading.value = false;
      }
    };

    const selectWorkflow = (wf) => {
      selectedWorkflow.value = wf;
    };

    const createWorkflow = async () => {
      try {
        const yamlConfig = `nodes:\n  - id: node_1\n    type: llm\n    position:\n      x: 100\n      y: 100\n    data:\n      label: 新节点\n      config:\n        model: gpt-4o\n        prompt: 请输入提示词`;
        const res = await axios.post(`${API_BASE}/workflows`, {
          name: newWorkflow.value.name,
          description: newWorkflow.value.description,
          industry: newWorkflow.value.industry,
          yaml_config: yamlConfig
        });
        workflows.value.push(res.data);
        showCreateModal.value = false;
        newWorkflow.value = { name: '', description: '', industry: '' };
      } catch (e) {
        console.error('创建失败', e);
      }
    };

    const saveWorkflow = async () => {
      if (!selectedWorkflow.value) return;
      try {
        await axios.put(`${API_BASE}/workflows/${selectedWorkflow.value.id}`, selectedWorkflow.value);
        alert('保存成功');
      } catch (e) {
        console.error('保存失败', e);
      }
    };

    const executeWorkflow = async (id) => {
      try {
        const res = await axios.post(`${API_BASE}/workflows/${id}/execute`, { input_data: {} });
        alert(`执行成功！执行ID: ${res.data.id}`);
      } catch (e) {
        console.error('执行失败', e);
      }
    };

    onMounted(() => {
      loadWorkflows();
    });

    return {
      workflows,
      selectedWorkflow,
      loading,
      showCreateModal,
      newWorkflow,
      loadWorkflows,
      selectWorkflow,
      createWorkflow,
      saveWorkflow,
      executeWorkflow
    };
  }
};
</script>

<style>
.app-container {
  display: flex;
  flex-direction: column;
  height: 100vh;
  font-family: Arial, sans-serif;
}
.app-header {
  background: #2c3e50;
  color: white;
  padding: 10px 20px;
  display: flex;
  justify-content: space-between;
  align-items: center;
}
.app-header h1 {
  margin: 0;
  font-size: 20px;
}
.header-actions button {
  margin-left: 10px;
  padding: 5px 15px;
  background: #3498db;
  color: white;
  border: none;
  border-radius: 3px;
  cursor: pointer;
}
.app-main {
  display: flex;
  flex: 1;
  overflow: hidden;
}
.sidebar {
  width: 300px;
  background: #f5f5f5;
  padding: 15px;
  overflow-y: auto;
  border-right: 1px solid #ddd;
}
.sidebar h3 {
  margin-top: 0;
}
.workflow-list {
  list-style: none;
  padding: 0;
}
.workflow-list li {
  padding: 10px;
  margin-bottom: 5px;
  background: white;
  border-radius: 4px;
  cursor: pointer;
  border: 1px solid #ddd;
}
.workflow-list li.active {
  border-color: #3498db;
  background: #e3f2fd;
}
.wf-name {
  display: block;
  font-weight: bold;
}
.wf-industry {
  font-size: 12px;
  color: #666;
}
.monitoring-section {
  margin-top: 20px;
  padding-top: 20px;
  border-top: 1px solid #ddd;
}
.main-content {
  flex: 1;
  padding: 20px;
  overflow-y: auto;
}
.welcome {
  text-align: center;
  margin-top: 100px;
  color: #666;
}
.editor-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 20px;
}
.editor-actions button {
  margin-left: 10px;
  padding: 5px 15px;
  background: #2ecc71;
  color: white;
  border: none;
  border-radius: 3px;
  cursor: pointer;
}
.modal-overlay {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: rgba(0,0,0,0.5);
  display: flex;
  justify-content: center;
  align-items: center;
}
.modal-content {
  background: white;
  padding: 20px;
  border-radius: 5px;
  width: 400px;
}
.form-group {
  margin-bottom: 15px;
}
.form-group label {
  display: block;
  margin-bottom: 5px;
  font-weight: bold;
}
.form-group input, .form-group textarea, .form-group select {
  width: 100%;
  padding: 8px;
  border: 1px solid #ddd;
  border-radius: 3px;
}
.form-actions {
  text-align: right;
}
.form-actions button {
  margin-left: 10px;
  padding: 5px 15px;
  cursor: pointer;
}
.loading, .empty {
  text-align: center;
  color: #666;
  padding: 20px;
}
</style>
