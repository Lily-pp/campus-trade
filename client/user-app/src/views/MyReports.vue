<template>
  <div class="reports-page" v-loading="loading">
    <h1 class="page-title">我的举报</h1>
    
    <el-card shadow="never">
      <el-table :data="reportsList" style="width: 100%">
        <el-table-column prop="id" label="举报ID" width="100" />
        <el-table-column prop="target_type" label="举报类型" width="120">
          <template #default="scope">
            <el-tag :type="scope.row.target_type === 'item' ? 'primary' : 'success'">
              {{ scope.row.target_type === 'item' ? '商品' : '用户' }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="target_id" label="举报对象ID" width="120" />
        <el-table-column prop="reason" label="举报原因" />
        <el-table-column prop="status" label="处理状态" width="120">
          <template #default="scope">
            <el-tag :type="getStatusType(scope.row.status)">
              {{ getStatusLabel(scope.row.status) }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="created_at" label="举报时间" width="180">
          <template #default="scope">
            {{ formatTime(scope.row.created_at) }}
          </template>
        </el-table-column>
        <el-table-column prop="handled_at" label="处理时间" width="180">
          <template #default="scope">
            {{ scope.row.handled_at ? formatTime(scope.row.handled_at) : '未处理' }}
          </template>
        </el-table-column>
      </el-table>
      
      <div class="pagination" v-if="total > 0">
        <el-pagination
          v-model:current-page="currentPage"
          v-model:page-size="pageSize"
          :page-sizes="[10, 15, 20]"
          layout="total, sizes, prev, pager, next, jumper"
          :total="total"
          @size-change="handleSizeChange"
          @current-change="handleCurrentChange"
        />
      </div>
      
      <el-empty v-if="!loading && reportsList.length === 0" description="暂无举报记录" />
    </el-card>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { ElMessage } from 'element-plus'
import api from '@/api'

const loading = ref(false)
const reportsList = ref([])
const total = ref(0)
const currentPage = ref(1)
const pageSize = ref(15)

const statusMap = {
  pending: '待处理',
  processed: '已处理',
  ignored: '已忽略'
}

const statusType = {
  pending: 'warning',
  processed: 'success',
  ignored: 'info'
}

const getStatusLabel = (status) => statusMap[status] || status
const getStatusType = (status) => statusType[status] || 'info'

const formatTime = (time) => {
  if (!time) return ''
  return new Date(time).toLocaleString('zh-CN')
}

const fetchReports = async () => {
  loading.value = true
  try {
    const res = await api.get('/reports/my', {
      params: {
        page: currentPage.value,
        pageSize: pageSize.value
      }
    })
    if (res.data.code === 0) {
      reportsList.value = res.data.data.list
      total.value = res.data.data.total
    } else {
      ElMessage.warning(res.data.message)
    }
  } catch (e) {
    ElMessage.error('获取举报记录失败')
    console.error(e)
  } finally {
    loading.value = false
  }
}

const handleSizeChange = (size) => {
  pageSize.value = size
  currentPage.value = 1
  fetchReports()
}

const handleCurrentChange = (page) => {
  currentPage.value = page
  fetchReports()
}

onMounted(() => {
  fetchReports()
})
</script>

<style scoped>
.reports-page {
  max-width: 1200px;
  margin: 0 auto;
  padding: 20px 0;
}

.page-title {
  font-size: 24px;
  font-weight: 600;
  margin-bottom: 20px;
  color: #303133;
}

.pagination {
  margin-top: 20px;
  display: flex;
  justify-content: flex-end;
}
</style>