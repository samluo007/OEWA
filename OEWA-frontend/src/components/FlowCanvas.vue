<template>
  <div class="flow-canvas">
    <div class="canvas-toolbar">
      <span>🛠️ 节点库</span>
      <div class="node-palette">
        <div 
          v-for="nodeType in nodeTypes" 
          :key="nodeType.type"
          class="palette-node"
          draggable="true"
          @dragstart="onDragStart($event, nodeType)"
        >
          {{ nodeType.icon }} {{ nodeType.name }}
        </div>
      </div>
    </div>
    
    <div class="react-flow-container" ref="reactFlowContainer">
      <VueFlow
        v-model="elements"
        :node-types="nodeTypesMap"
        @dragover="onDragOver"
        @drop="onDrop"
        @node-click="onNodeClick"
      >
        <Background />
        <Controls />
        <MiniMap />
      </VueFlow>
    </div>
    
    <!-- 节点配置抽屉 -->
    <div v-if="selectedNode" class="node-config-drawer">
      <div class="drawer-header">
        <h3>配置节点: {{ selectedNode.data.label }}</h3>
        <button @click="selectedNode = null">关闭</button>
      </div>
      <div class="drawer-body">
        <div v-if="selectedNode.type === 'llm'">
          <label>模型</label>
          <input v-model="selectedNode.data.config.model" />
          <label>提示词</label>
          <textarea v-model="selectedNode.data.config.prompt" />
          <label>温度</label>
          <input type="number" v-model="selectedNode.data.config.temperature" step="0.1" min="0" max="1" />
        </div>
        <div v-else-if="selectedNode.type === 'code'">
          <label>代码</label>
          <textarea v-model="selectedNode.data.config.code" rows="10" />
        </div>
        <!-- 更多节点类型配置... -->
        <button @click="saveNodeConfig">保存配置</button>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, computed } from 'vue'
import { VueFlow } from '@vue-flow/core'
import { Background } from '@vue-flow/background'
import { Controls } from '@vue-flow/controls'
import { MiniMap } from '@vue-flow/minimap'
import axios from 'axios'

const API_BASE = 'http://localhost:8000/api'

// 画布元素（节点+边）
const elements = ref([])
const selectedNode = ref(null)
const nodeTypes = ref([])
const reactFlowContainer = ref(null)

// 节点类型映射（用于VueFlow）
const nodeTypesMap = computed(() => {
  const map = {}
  nodeTypes.value.forEach(nt => {
    map[nt.type] = {
      // 自定义节点组件（简化版用默认节点）
    }
  })
  return map
})

// 加载节点类型
async function loadNodeTypes() {
  try {
    const res = await axios.get(`${API_BASE}/node/types`)
    nodeTypes.value = res.data
  } catch (err) {
    console.error('加载节点类型失败:', err)
  }
}

// 拖拽开始
function onDragStart(event, nodeType) {
  event.dataTransfer.setData('application/vueflow', JSON.stringify(nodeType))
  event.dataTransfer.effectAllowed = 'move'
}

// 拖拽经过
function onDragOver(event) {
  event.preventDefault()
  event.dataTransfer.dropEffect = 'move'
}

// 放置节点
function onDrop(event) {
  event.preventDefault()
  
  const nodeTypeData = event.dataTransfer.getData('application/vueflow')
  if (!nodeTypeData) return
  
  const nodeType = JSON.parse(nodeTypeData)
  const bounds = reactFlowContainer.value.getBoundingClientRect()
  const position = {
    x: event.clientX - bounds.left,
    y: event.clientY - bounds.top
  }
  
  const newNode = {
    id: `node_${Date.now()}`,
    type: nodeType.type,
    position,
    data: {
      label: nodeType.name,
      config: getDefaultConfig(nodeType.type)
    }
  }
  
  elements.value.push(newNode)
}

// 节点点击
function onNodeClick(event, node) {
  selectedNode.value = node
}

// 保存节点配置
function saveNodeConfig() {
  // 更新节点数据
  selectedNode.value = null
}

// 默认配置
function getDefaultConfig(nodeType) {
  switch (nodeType) {
    case 'llm':
      return { model: 'gpt-4o', prompt: '', temperature: 0.7 }
    case 'code':
      return { code: '// 在此编写代码' }
    case 'http':
      return { url: '', method: 'GET' }
    case 'condition':
      return { condition: 'true' }
    default:
      return {}
  }
}

onMounted(() => {
  loadNodeTypes()
})
</script>

<style>
.flow-canvas {
  display: flex;
  height: 100%;
  position: relative;
}

.canvas-toolbar {
  width: 200px;
  padding: 1rem;
  background: #f8f9fa;
  border-right: 1px solid #e9ecef;
  overflow-y: auto;
}

.node-palette {
  margin-top: 1rem;
}

.palette-node {
  padding: 0.5rem;
  margin-bottom: 0.5rem;
  background: white;
  border: 1px solid #dee2e6;
  border-radius: 4px;
  cursor: grab;
  user-select: none;
}

.palette-node:hover {
  box-shadow: 0 2px 8px rgba(0,0,0,0.1);
}

.react-flow-container {
  flex: 1;
  position: relative;
}

.node-config-drawer {
  position: absolute;
  right: 0;
  top: 0;
  width: 300px;
  height: 100%;
  background: white;
  box-shadow: -2px 0 8px rgba(0,0,0,0.1);
  z-index: 10;
  padding: 1rem;
  overflow-y: auto;
}

.drawer-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 1rem;
}

.drawer-body label {
  display: block;
  margin-top: 1rem;
  margin-bottom: 0.5rem;
  font-weight: 500;
}

.drawer-body input,
.drawer-body textarea {
  width: 100%;
  padding: 0.5rem;
  border: 1px solid #ced4da;
  border-radius: 4px;
  font-size: 0.9rem;
}

.drawer-body button {
  margin-top: 1rem;
  padding: 0.5rem 1rem;
  background: #42b983;
  color: white;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  width: 100%;
}
</style>
