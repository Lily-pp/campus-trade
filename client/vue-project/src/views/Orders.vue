<template>
  <div class="orders-page">
    <!-- 筛选 -->
    <el-card class="filter-card" shadow="never">
      <el-row :gutter="12" align="middle">
        <el-col :span="7">
          <el-input v-model="filters.keyword" placeholder="搜索商品名称" clearable @keyup.enter="doSearch" @clear="doSearch">
            <template #prefix><el-icon><Search /></el-icon></template>
          </el-input>
        </el-col>
        <el-col :span="5">
          <el-select v-model="filters.status" placeholder="状态筛选" clearable @change="doSearch" style="width:100%">
            <el-option label="待交易" value="pending" />
            <el-option label="已完成" value="completed" />
            <el-option label="已取消" value="cancelled" />
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
        <span>订单管理 <el-tag type="info" size="small">共 {{ total }} 条</el-tag></span>
      </template>

      <el-table :data="orders" v-loading="loading" stripe border>
        <el-table-column prop="id" label="订单ID" width="80" />
        <el-table-column prop="item_title" label="商品" min-width="140" show-overflow-tooltip />
        <el-table-column prop="price" label="成交价" width="100">
          <template #default="{ row }">¥{{ row.price }}</template>
        </el-table-column>
        <el-table-column prop="buyer_name" label="买家" width="110" />
        <el-table-column prop="buyer_campus" label="校区" width="100" />
        <el-table-column prop="seller_name" label="卖家" width="110" />
        <el-table-column prop="status" label="状态" width="100">
          <template #default="{ row }">
            <el-tag :type="orderStatusMap[row.status]?.type || 'info'" size="small">
              {{ orderStatusMap[row.status]?.label || row.status }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="created_at" label="下单时间" width="160">
          <template #default="{ row }">{{ formatTime(row.created_at) }}</template>
        </el-table-column>
        <el-table-column label="操作" width="100" fixed="right" align="center">
          <template #default="{ row }">
            <el-dropdown v-if="row.status === 'pending'" trigger="click" @command="(cmd) => changeStatus(row.id, cmd)">
              <el-button type="primary" size="small">
                操作 <el-icon class="el-icon--right"><ArrowDown /></el-icon>
              </el-button>
              <template #dropdown>
                <el-dropdown-menu>
                  <el-dropdown-item command="completed">标记完成</el-dropdown-item>
                  <el-dropdown-item command="cancelled">取消订单</el-dropdown-item>
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
          @current-change="fetchOrders"
        />
      </div>
    </el-card>
  </div>
</template>

<script setup>
import { ref, reactive, onMounted } from 'vue'
import { ElMessage } from 'element-plus'
import { Search, ArrowDown } from '@element-plus/icons-vue'
import api from '@/api'

const orders  = ref([])
const loading = ref(false)
const total   = ref(0)

const filters = reactive({ page: 1, pageSize: 15, keyword: '', status: '' })

const orderStatusMap = {
  pending:   { label: '待交易', type: 'warning' },
  completed: { label: '已完成', type: 'success' },
  cancelled: { label: '已取消', type: 'info' },
}

const formatTime = (t) => t ? new Date(t).toLocaleString('zh-CN') : '-'

const fetchOrders = async () => {
  loading.value = true
  try {
    const params = { page: filters.page, pageSize: filters.pageSize }
    if (filters.keyword) params.keyword = filters.keyword
    if (filters.status)  params.status  = filters.status

    const res = await api.get('/orders', { params })
    if (res.data?.code === 0) {
      orders.value = res.data.data.list
      total.value  = res.data.data.total
    }
  } catch {
    ElMessage.error('获取订单失败')
  } finally {
    loading.value = false
  }
}

const doSearch    = () => { filters.page = 1; fetchOrders() }
const resetFilters = () => { filters.keyword = ''; filters.status = ''; doSearch() }

const changeStatus = async (id, status) => {
  try {
    await api.put(`/orders/${id}/status`, { status })
    ElMessage.success('状态已更新')
    fetchOrders()
  } catch (e) {
    ElMessage.error(e.response?.data?.message || '操作失败')
  }
}

onMounted(fetchOrders)
</script>

<style scoped>
.filter-card { margin-bottom: 0; }
.pagination { margin-top: 16px; display: flex; justify-content: flex-end; }
</style>
