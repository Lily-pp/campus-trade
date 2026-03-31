<template>
  <div class="logs-page">
    <el-card shadow="never" class="filter-card">
      <el-row :gutter="12" align="middle">
        <el-col :span="7">
          <el-input v-model="filters.action" placeholder="搜索操作类型（如 delete_item）" clearable
            @keyup.enter="doSearch" @clear="doSearch">
            <template #prefix><el-icon><Search /></el-icon></template>
          </el-input>
        </el-col>
        <el-col :span="4">
          <el-button type="primary" @click="doSearch">搜索</el-button>
          <el-button @click="resetFilters">重置</el-button>
        </el-col>
      </el-row>
    </el-card>

    <el-card style="margin-top:12px">
      <template #header>
        <span>操作日志 <el-tag type="info" size="small">共 {{ total }} 条</el-tag></span>
      </template>

      <el-table :data="logs" v-loading="loading" stripe border>
        <el-table-column prop="id" label="ID" width="70" />
        <el-table-column prop="admin_name" label="操作人" width="120" />
        <el-table-column prop="admin_role" label="角色" width="100">
          <template #default="{ row }">
            <el-tag size="small" :type="row.admin_role === 'admin' ? 'danger' : 'warning'">
              {{ row.admin_role === 'admin' ? '管理员' : '运营' }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="action" label="操作" width="180">
          <template #default="{ row }">
            <el-tag size="small" :type="actionType(row.action)">{{ actionLabel(row.action) }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="对象" width="130">
          <template #default="{ row }">
            <span v-if="row.target_type">{{ row.target_type }} #{{ row.target_id }}</span>
            <span v-else>-</span>
          </template>
        </el-table-column>
        <el-table-column prop="detail" label="详情" min-width="180" show-overflow-tooltip>
          <template #default="{ row }">{{ row.detail || '-' }}</template>
        </el-table-column>
        <el-table-column prop="created_at" label="时间" width="165">
          <template #default="{ row }">{{ formatTime(row.created_at) }}</template>
        </el-table-column>
      </el-table>

      <div class="pagination">
        <el-pagination
          background layout="total, prev, pager, next"
          :total="total" :page-size="filters.pageSize"
          v-model:current-page="filters.page"
          @current-change="fetchLogs"
        />
      </div>
    </el-card>
  </div>
</template>

<script setup>
import { ref, reactive, onMounted } from 'vue'
import { ElMessage } from 'element-plus'
import { Search } from '@element-plus/icons-vue'
import api from '@/api'

const logs    = ref([])
const loading = ref(false)
const total   = ref(0)
const filters = reactive({ page: 1, pageSize: 20, action: '' })

const formatTime = (t) => t ? new Date(t).toLocaleString('zh-CN') : '-'

const actionMap = {
  delete_item:          { label: '删除商品',     type: 'danger' },
  update_item_status:   { label: '更新商品状态', type: 'warning' },
  freeze_user:          { label: '冻结用户',     type: 'danger' },
  update_order_status:  { label: '更新订单状态', type: 'primary' },
  takedown_item:        { label: '下架商品',     type: 'warning' },
  ignore_report:        { label: '忽略举报',     type: 'info' },
  update_category:      { label: '更新分类',     type: 'primary' },
  delete_category:      { label: '删除分类',     type: 'danger' },
}
const actionLabel = (a) => actionMap[a]?.label || a
const actionType  = (a) => actionMap[a]?.type || 'info'

const fetchLogs = async () => {
  loading.value = true
  try {
    const params = { page: filters.page, pageSize: filters.pageSize }
    if (filters.action) params.action = filters.action
    const res = await api.get('/logs', { params })
    if (res.data?.code === 0) {
      logs.value  = res.data.data.list
      total.value = res.data.data.total
    }
  } catch {
    ElMessage.error('获取日志失败')
  } finally {
    loading.value = false
  }
}

const doSearch     = () => { filters.page = 1; fetchLogs() }
const resetFilters = () => { filters.action = ''; doSearch() }

onMounted(fetchLogs)
</script>

<style scoped>
.filter-card { margin-bottom: 0; }
.pagination { margin-top: 16px; display: flex; justify-content: flex-end; }
</style>
