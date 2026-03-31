<template>
  <div class="reports-page">
    <el-card class="filter-card" shadow="never">
      <el-row :gutter="12" align="middle">
        <el-col :span="5">
          <el-select v-model="filters.status" placeholder="状态筛选" clearable @change="doSearch" style="width:100%">
            <el-option label="待处理" value="pending" />
            <el-option label="已处理" value="processed" />
            <el-option label="已忽略" value="ignored" />
          </el-select>
        </el-col>
        <el-col :span="4">
          <el-button type="primary" @click="doSearch">搜索</el-button>
          <el-button @click="resetFilters">重置</el-button>
        </el-col>
      </el-row>
    </el-card>

    <el-card style="margin-top:12px">
      <template #header>
        <span>举报管理 <el-tag type="info" size="small">共 {{ total }} 条</el-tag></span>
      </template>

      <el-table :data="reports" v-loading="loading" stripe border>
        <el-table-column prop="id" label="ID" width="70" />
        <el-table-column prop="reporter_name" label="举报人" width="120" />
        <el-table-column prop="target_type" label="举报对象" width="100">
          <template #default="{ row }">
            <el-tag size="small" :type="row.target_type === 'item' ? 'primary' : 'warning'">
              {{ row.target_type === 'item' ? '商品' : '用户' }} #{{ row.target_id }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="举报原因" min-width="180">
          <template #default="{ row }">
            <el-button link type="primary" @click="showReasonDetail(row)">
              {{ row.reason.length > 20 ? row.reason.substring(0, 20) + '...' : row.reason }}
            </el-button>
          </template>
        </el-table-column>
        <el-table-column prop="status" label="状态" width="100">
          <template #default="{ row }">
            <el-tag :type="reportStatusMap[row.status]?.type || 'info'" size="small">
              {{ reportStatusMap[row.status]?.label || row.status }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="handler_name" label="处理人" width="110">
          <template #default="{ row }">{{ row.handler_name || '-' }}</template>
        </el-table-column>
        <el-table-column prop="created_at" label="举报时间" width="160">
          <template #default="{ row }">{{ formatTime(row.created_at) }}</template>
        </el-table-column>
        <el-table-column label="操作" width="100" fixed="right" align="center">
          <template #default="{ row }">
            <el-dropdown v-if="row.status === 'pending'" trigger="click" @command="(cmd) => handle(row, cmd)">
              <el-button type="primary" size="small">
                操作 <el-icon class="el-icon--right"><ArrowDown /></el-icon>
              </el-button>
              <template #dropdown>
                <el-dropdown-menu>
                  <el-dropdown-item command="ignore">忽略</el-dropdown-item>
                  <el-dropdown-item v-if="row.target_type === 'item'" command="takedown" divided>下架商品</el-dropdown-item>
                  <el-dropdown-item v-if="row.target_type === 'user'" command="freeze" divided>冻结用户</el-dropdown-item>
                </el-dropdown-menu>
              </template>
            </el-dropdown>
            <el-tag v-else size="small" type="info">已处理</el-tag>
          </template>
        </el-table-column>
      </el-table>

      <div class="pagination">
        <el-pagination
          background layout="total, prev, pager, next"
          :total="total" :page-size="filters.pageSize"
          v-model:current-page="filters.page"
          @current-change="fetchReports"
        />
      </div>
    </el-card>

    <!-- 举报原因详情弹窗 -->
    <el-dialog v-model="reasonDialogVisible" title="举报原因详情" width="500px">
      <div v-if="currentReport">
        <p><strong>举报人：</strong>{{ currentReport.reporter_name }}</p>
        <p><strong>举报对象：</strong>{{ currentReport.target_type === 'item' ? '商品' : '用户' }} #{{ currentReport.target_id }}</p>
        <p><strong>举报时间：</strong>{{ formatTime(currentReport.created_at) }}</p>
        <el-divider />
        <p style="white-space: pre-wrap; line-height: 1.6;">{{ currentReport.reason }}</p>
      </div>
    </el-dialog>
  </div>
</template>

<script setup>
import { ref, reactive, onMounted } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { ArrowDown } from '@element-plus/icons-vue'
import api from '@/api'

const reports  = ref([])
const loading  = ref(false)
const total    = ref(0)
const filters  = reactive({ page: 1, pageSize: 15, status: 'pending' })

const reasonDialogVisible = ref(false)
const currentReport = ref(null)

const reportStatusMap = {
  pending:   { label: '待处理', type: 'danger' },
  processed: { label: '已处理', type: 'success' },
  ignored:   { label: '已忽略', type: 'info' },
}
const actionLabels = {
  ignore:   '忽略该举报',
  takedown: '下架商品',
  freeze:   '冻结用户',
}

const formatTime = (t) => t ? new Date(t).toLocaleString('zh-CN') : '-'

const showReasonDetail = (row) => {
  currentReport.value = row
  reasonDialogVisible.value = true
}

const fetchReports = async () => {
  loading.value = true
  try {
    const params = { page: filters.page, pageSize: filters.pageSize }
    if (filters.status) params.status = filters.status
    const res = await api.get('/reports', { params })
    if (res.data?.code === 0) {
      reports.value = res.data.data.list
      total.value   = res.data.data.total
    }
  } catch {
    ElMessage.error('获取举报列表失败')
  } finally {
    loading.value = false
  }
}

const doSearch     = () => { filters.page = 1; fetchReports() }
const resetFilters = () => { filters.status = ''; doSearch() }

const handle = async (row, action) => {
  try {
    await ElMessageBox.confirm(
      `确定执行「${actionLabels[action]}」？`,
      '确认操作', { type: 'warning' }
    )
    await api.put(`/reports/${row.id}/handle`, { action })
    ElMessage.success('处理成功')
    fetchReports()
  } catch (e) {
    if (e === 'cancel' || e?.toString().includes('cancel')) return
    ElMessage.error(e.response?.data?.message || '处理失败')
  }
}

onMounted(fetchReports)
</script>

<style scoped>
.filter-card { margin-bottom: 0; }
.pagination { margin-top: 16px; display: flex; justify-content: flex-end; }
</style>
