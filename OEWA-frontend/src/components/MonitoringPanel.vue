<template>
  <div class="monitoring-panel">
    <h2>📊 监控面板</h2>
    
    <div v-if="loading" class="loading">加载中...</div>
    
    <div v-else class="stats-grid">
      <div class="stat-card">
        <div class="stat-value">{{ stats.total_executions || 0 }}</div>
        <div class="stat-label">总执行次数</div>
      </div>
      
      <div class="stat-card success">
        <div class="stat-value">{{ stats.success_count || 0 }}</div>
        <div class="stat-label">成功次数</div>
      </div>
      
      <div class="stat-card error">
        <div class="stat-value">{{ stats.failed_count || 0 }}</div>
        <div class="stat-label">失败次数</div>
      </div>
      
      <div class="stat-card">
        <div class="stat-value">{{ stats.avg_duration_ms ? stats.avg_duration_ms.toFixed(2) : '0.00' }} ms</div>
        <div class="stat-label">平均耗时</div>
      </div>
    </div>
    
    <div class="recent-executions">
      <h3>🕒 最近执行记录</h3>
      <table v-if="recentExecutions.length > 0">
        <thead>
          <tr>
            <th>执行ID</th>
            <th>工作流ID</th>
            <th>状态</th>
            <th>开始时间</th>
            <th>耗时(ms)</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="exec in recentExecutions" :key="exec.id">
            <td>{{ exec.id.substring(0, 8) }}...</td>
            <td>{{ exec.workflow_id.substring(0, 8) }}...</td>
            <td :class="exec.status">{{ exec.status }}</td>
            <td>{{ formatTime(exec.started_at) }}</td>
            <td>{{ exec.duration_ms || '-' }}</td>
          </tr>
        </tbody>
      </table>
      <div v-else class="empty">暂无执行记录</div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import axios from 'axios'

const API_BASE = 'http://localhost:8000/api'

const stats = ref({})
const recentExecutions = ref([])
const loading = ref(true)

async function loadStats() {
  try {
    const res = await axios.get(`${API_BASE}/monitoring/stats`)
    stats.value = res.data
  } catch (err) {
    console.error('加载统计失败:', err)
  }
}

async function loadRecentExecutions() {
  try {
    const res = await axios.get(`${API_BASE}/monitoring/recent-executions`)
    recentExecutions.value = res.data
  } catch (err) {
    console.error('加载最近执行记录失败:', err)
  }
}

function formatTime(isoString) {
  if (!isoString) return '-'
  const date = new Date(isoString)
  return date.toLocaleString('zh-CN')
}

onMounted(async () => {
  await Promise.all([loadStats(), loadRecentExecutions()])
  loading.value = false
})
</script>

<style scoped>
.monitoring-panel {
  padding: 1rem;
}

.stats-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
  gap: 1rem;
  margin-bottom: 2rem;
}

.stat-card {
  background: white;
  border-radius: 8px;
  padding: 1.5rem;
  box-shadow: 0 2px 8px rgba(0,0,0,0.1);
  text-align: center;
}

.stat-card.success {
  border-top: 4px solid #42b983;
}

.stat-card.error {
  border-top: 4px solid #f56c6c;
}

.stat-value {
  font-size: 2rem;
  font-weight: bold;
  color: #2c3e50;
}

.stat-label {
  font-size: 0.9rem;
  color: #7f8c8d;
  margin-top: 0.5rem;
}

.recent-executions {
  background: white;
  border-radius: 8px;
  padding: 1.5rem;
  box-shadow: 0 2px 8px rgba(0,0,0,0.1);
}

table {
  width: 100%;
  border-collapse: collapse;
  margin-top: 1rem;
}

th, td {
  padding: 0.75rem;
  text-align: left;
  border-bottom: 1px solid #eee;
}

th {
  background: #f8f9fa;
  font-weight: 600;
}

.status.success {
  color: #42b983;
}

.status.error {
  color: #f56c6c;
}

.loading, .empty {
  text-align: center;
  padding: 2rem;
  color: #7f8c8d;
}
</style>
