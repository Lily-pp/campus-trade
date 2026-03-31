<template>
  <div class="dashboard">
    <!-- 统计卡片：第一行 -->
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

    <!-- 第二行：热门商品 + 分类占比 -->
    <el-row :gutter="16" style="margin-bottom:16px">
      <!-- 热门商品 -->
      <el-col :span="14">
        <el-card shadow="never">
          <template #header><span>🔥 热门商品（浏览+收藏加权）</span></template>
          <el-table :data="stats.hot_items || []" size="small" stripe>
            <el-table-column prop="title" label="商品" show-overflow-tooltip />
            <el-table-column prop="price" label="价格" width="90">
              <template #default="{ row }">¥{{ row.price }}</template>
            </el-table-column>
            <el-table-column prop="views_count" label="浏览" width="70" />
            <el-table-column prop="favorites_count" label="收藏" width="70" />
          </el-table>
        </el-card>
      </el-col>

      <!-- 分类分布 -->
      <el-col :span="10">
        <el-card shadow="never" style="height:100%">
          <template #header><span>📊 分类商品分布</span></template>
          <div class="category-bars">
            <div v-for="item in stats.category_dist || []" :key="item.name" class="bar-item">
              <div class="bar-label">{{ item.name }}</div>
              <div class="bar-track">
                <div
                  class="bar-fill"
                  :style="{ width: barWidth(item.item_count) + '%' }"
                />
              </div>
              <div class="bar-count">{{ item.item_count }}</div>
            </div>
            <div v-if="!stats.category_dist?.length" class="empty-hint">暂无数据</div>
          </div>
        </el-card>
      </el-col>
    </el-row>

    <!-- 第三行：最新商品表 -->
    <el-card class="recent-card" v-loading="loading">
      <template #header>
        <div style="display:flex;justify-content:space-between;align-items:center">
          <span>📋 最新发布商品</span>
          <el-tag v-if="(stats.pending || 0) > 0" type="danger">
            待审核 {{ stats.pending }} 件
          </el-tag>
        </div>
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
import { ref, computed, onMounted } from 'vue'
import { User, Goods, Files, Sell, Document, Warning } from '@element-plus/icons-vue'
import { ElMessage } from 'element-plus'
import api from '@/api'

const loading = ref(false)
const stats = ref({})

const statCards = [
  { key: 'users',           label: '前台用户数', icon: 'User',     color: '#409EFF' },
  { key: 'total_items',     label: '商品总数',   icon: 'Goods',    color: '#67C23A' },
  { key: 'on_sale',         label: '在售商品',   icon: 'Sell',     color: '#E6A23C' },
  { key: 'total_orders',    label: '总订单数',   icon: 'Document', color: '#9B59B6' },
  { key: 'pending',         label: '待审核商品', icon: 'Warning',  color: '#F56C6C' },
  { key: 'pending_reports', label: '待处理举报', icon: 'Warning',  color: '#E74C3C' },
  { key: 'sold',            label: '已售出',     icon: 'Sell',     color: '#1ABC9C' },
  { key: 'categories',      label: '分类总数',   icon: 'Files',    color: '#95A5A6' },
]

const statusMap = {
  on_sale: { label: '出售中', type: 'success' },
  sold:    { label: '已售出', type: 'info' },
  off:     { label: '已下架', type: 'warning' },
  pending: { label: '待审核', type: 'danger' },
}

const maxCount = computed(() => {
  const list = stats.value.category_dist || []
  return Math.max(...list.map(i => parseInt(i.item_count) || 0), 1)
})

const barWidth = (count) => Math.round((parseInt(count) / maxCount.value) * 100)

const formatTime = (t) => t ? new Date(t).toLocaleString('zh-CN') : '-'

const fetchStats = async () => {
  loading.value = true
  try {
    const res = await api.get('/stats')
    if (res.data?.code === 0) stats.value = res.data.data
  } catch {
    ElMessage.error('统计数据加载失败')
  } finally {
    loading.value = false
  }
}

onMounted(fetchStats)
</script>

<style scoped>
.dashboard { padding: 4px; }
.stat-row { margin-bottom: 16px; flex-wrap: wrap; }
.stat-card { border-radius: 8px; }
.stat-inner { display: flex; align-items: center; gap: 16px; padding: 8px 0; }
.stat-icon {
  width: 52px; height: 52px; border-radius: 12px;
  display: flex; align-items: center; justify-content: center;
  color: white; flex-shrink: 0;
}
.stat-value { font-size: 26px; font-weight: 700; color: #303133; line-height: 1; }
.stat-label { font-size: 12px; color: #909399; margin-top: 6px; }
.recent-card { border-radius: 8px; }

/* 分类进度条 */
.category-bars { padding: 4px 0; }
.bar-item { display: flex; align-items: center; margin-bottom: 10px; gap: 8px; }
.bar-label { width: 72px; font-size: 12px; color: #606266; text-align: right; flex-shrink: 0; }
.bar-track { flex: 1; height: 16px; background: #f0f2f5; border-radius: 8px; overflow: hidden; }
.bar-fill { height: 100%; background: linear-gradient(90deg, #409EFF, #67C23A); border-radius: 8px; transition: width .4s; }
.bar-count { width: 28px; font-size: 12px; color: #909399; text-align: right; }
.empty-hint { color: #c0c4cc; font-size: 13px; text-align: center; padding: 20px 0; }
</style>
