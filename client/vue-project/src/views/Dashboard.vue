<template>
  <div class="dashboard">
    <!-- 统计卡片 -->
    <el-row :gutter="16" class="stat-row">
      <el-col :span="6" v-for="card in statCards" :key="card.key">
        <el-card class="stat-card" shadow="hover">
          <div class="stat-inner">
            <div class="stat-icon" :style="{ background: card.color }">
              <el-icon :size="28"><component :is="card.icon" /></el-icon>
            </div>
            <div class="stat-info">
              <div class="stat-value">{{ stats[card.key] ?? '--' }}</div>
              <div class="stat-label">{{ card.label }}</div>
            </div>
          </div>
        </el-card>
      </el-col>
    </el-row>

    <!-- 最新商品 -->
    <el-card class="recent-card" v-loading="loading">
      <template #header>
        <span>最新发布商品</span>
      </template>
      <el-table :data="stats.recent_items || []" stripe size="small">
        <el-table-column prop="id" label="ID" width="70" />
        <el-table-column prop="title" label="商品名称" />
        <el-table-column prop="price" label="价格" width="110">
          <template #default="{ row }">¥{{ row.price }}</template>
        </el-table-column>
        <el-table-column prop="seller_name" label="发布者" width="120" />
        <el-table-column prop="status" label="状态" width="100">
          <template #default="{ row }">
            <el-tag :type="statusMap[row.status]?.type || 'info'" size="small">
              {{ statusMap[row.status]?.label || row.status }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="created_at" label="发布时间" width="180">
          <template #default="{ row }">{{ formatTime(row.created_at) }}</template>
        </el-table-column>
      </el-table>
    </el-card>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { User, Goods, Files, Sell } from '@element-plus/icons-vue'
import { ElMessage } from 'element-plus'
import api from '@/api'

const loading = ref(false)
const stats = ref({})

const statCards = [
  { key: 'users',       label: '前台用户数', icon: 'User',  color: '#409EFF' },
  { key: 'total_items', label: '商品总数',   icon: 'Goods', color: '#67C23A' },
  { key: 'on_sale',     label: '在售商品',   icon: 'Sell',  color: '#E6A23C' },
  { key: 'categories',  label: '分类总数',   icon: 'Files', color: '#F56C6C' },
]

const statusMap = {
  on_sale: { label: '出售中', type: 'success' },
  sold:    { label: '已售出', type: 'info' },
  off:     { label: '已下架', type: 'warning' },
}

const formatTime = (t) => t ? new Date(t).toLocaleString('zh-CN') : '-'

const fetchStats = async () => {
  loading.value = true
  try {
    const res = await api.get('/stats')
    if (res.data?.code === 0) {
      stats.value = res.data.data
    }
  } catch (e) {
    ElMessage.error('统计数据加载失败')
  } finally {
    loading.value = false
  }
}

onMounted(fetchStats)
</script>

<style scoped>
.dashboard { padding: 4px; }
.stat-row { margin-bottom: 20px; }
.stat-card { border-radius: 8px; }
.stat-inner {
  display: flex;
  align-items: center;
  gap: 16px;
  padding: 8px 0;
}
.stat-icon {
  width: 56px; height: 56px;
  border-radius: 12px;
  display: flex; align-items: center; justify-content: center;
  color: white; flex-shrink: 0;
}
.stat-value {
  font-size: 28px; font-weight: 700;
  color: #303133; line-height: 1;
}
.stat-label {
  font-size: 13px; color: #909399; margin-top: 6px;
}
.recent-card { border-radius: 8px; }
</style>
