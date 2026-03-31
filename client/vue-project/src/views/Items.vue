<template>
  <div class="items-page">
    <!-- 搜索筛选栏 -->
    <el-card shadow="never" style="margin-bottom: 12px">
      <el-row :gutter="12" align="middle">
        <el-col :span="7">
          <el-input
            v-model="filters.keyword"
            placeholder="搜索商品名称..."
            clearable
            @keyup.enter="doSearch"
            @clear="doSearch"
          >
            <template #prefix><el-icon><Search /></el-icon></template>
          </el-input>
        </el-col>
        <el-col :span="5">
          <el-select v-model="filters.status" placeholder="全部状态" clearable @change="doSearch" style="width:100%">
            <el-option v-for="s in statusOptions" :key="s.value" :label="s.label" :value="s.value" />
          </el-select>
        </el-col>
        <el-col :span="5">
          <el-select v-model="filters.category_id" placeholder="全部分类" clearable @change="doSearch" style="width:100%">
            <el-option v-for="c in categories" :key="c.id" :label="c.name" :value="c.id" />
          </el-select>
        </el-col>
        <el-col :span="7">
          <el-button type="primary" @click="doSearch">
            <el-icon><Search /></el-icon>&nbsp;搜索
          </el-button>
          <el-button @click="resetFilters">重置</el-button>
        </el-col>
      </el-row>
    </el-card>

    <!-- 商品表格 -->
    <el-card>
      <template #header>
        <span>
          商品管理
          <el-tag type="info" size="small" style="margin-left:8px">共 {{ total }} 条</el-tag>
        </span>
      </template>

      <el-table :data="items" v-loading="loading" stripe border style="width:100%">
        <el-table-column prop="id" label="ID" width="65" />
        <el-table-column prop="title" label="商品名称" min-width="160" show-overflow-tooltip />
        <el-table-column prop="price" label="价格" width="100">
          <template #default="{ row }">¥{{ row.price }}</template>
        </el-table-column>
        <el-table-column prop="category_name" label="分类" width="110" />
        <el-table-column prop="seller_name" label="发布人" width="100" />
        <el-table-column prop="seller_campus" label="校区" width="100" />
        <el-table-column label="浏览/收藏" width="90" align="center">
          <template #default="{ row }">
            {{ row.views_count }}/{{ row.favorites_count }}
          </template>
        </el-table-column>
        <el-table-column label="状态" width="90" align="center">
          <template #default="{ row }">
            <el-tag :type="statusMap[row.status]?.type ?? 'info'" size="small">
              {{ statusMap[row.status]?.label ?? row.status }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="发布时间" width="155">
          <template #default="{ row }">{{ formatTime(row.created_at) }}</template>
        </el-table-column>
        <el-table-column label="操作" width="100" fixed="right" align="center">
          <template #default="{ row }">
            <el-dropdown trigger="click" @command="(cmd) => handleCommand(row, cmd)">
              <el-button type="primary" size="small">
                操作 <el-icon class="el-icon--right"><ArrowDown /></el-icon>
              </el-button>
              <template #dropdown>
                <el-dropdown-menu>
                  <el-dropdown-item v-if="row.status === 'pending'" command="approve">审核通过</el-dropdown-item>
                  <el-dropdown-item v-if="row.status === 'pending'" command="reject">拒绝</el-dropdown-item>
                  <el-dropdown-item v-if="row.status === 'on_sale'" command="off">下架</el-dropdown-item>
                  <el-dropdown-item v-if="row.status === 'off'" command="on_sale">上架</el-dropdown-item>
                  <el-dropdown-item command="delete" divided>
                    <span style="color: #f56c6c">删除</span>
                  </el-dropdown-item>
                </el-dropdown-menu>
              </template>
            </el-dropdown>
          </template>
        </el-table-column>
      </el-table>

      <div style="margin-top:16px; display:flex; justify-content:flex-end">
        <el-pagination
          background
          layout="total, prev, pager, next, sizes"
          :page-sizes="[10, 15, 20, 50]"
          :total="total"
          :page-size="filters.pageSize"
          v-model:current-page="filters.page"
          @current-change="fetchItems"
          @size-change="(s) => { filters.pageSize = s; doSearch() }"
        />
      </div>
    </el-card>
  </div>
</template>

<script setup>
import { ref, reactive, onMounted } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { Search, ArrowDown } from '@element-plus/icons-vue'
import api from '@/api'

const items      = ref([])
const categories = ref([])
const loading    = ref(false)
const total      = ref(0)

const filters = reactive({
  page: 1,
  pageSize: 15,
  keyword: '',
  status: '',
  category_id: ''
})

// 状态映射（含 pending）
const statusMap = {
  pending: { label: '待审核', type: 'danger' },
  on_sale: { label: '出售中', type: 'success' },
  sold:    { label: '已售出', type: 'info' },
  off:     { label: '已下架', type: 'warning' },
}

const statusOptions = [
  { label: '待审核', value: 'pending' },
  { label: '出售中', value: 'on_sale' },
  { label: '已下架', value: 'off' },
  { label: '已售出', value: 'sold' },
]

const formatTime = (t) => t ? new Date(t).toLocaleString('zh-CN') : '-'

const fetchItems = async () => {
  loading.value = true
  try {
    const params = {
      page: filters.page,
      pageSize: filters.pageSize,
    }
    if (filters.keyword)     params.keyword     = filters.keyword
    if (filters.status)      params.status      = filters.status
    if (filters.category_id) params.category_id = filters.category_id

    const res = await api.get('/items/all', { params })
    if (res.data?.code === 0) {
      items.value = res.data.data.list
      total.value = res.data.data.total
    } else {
      ElMessage.error(res.data?.message || '获取失败')
    }
  } catch (error) {
    ElMessage.error(error.response?.data?.message || '获取商品列表失败')
  } finally {
    loading.value = false
  }
}

const fetchCategories = async () => {
  try {
    const res = await api.get('/categories')
    if (res.data?.code === 0) categories.value = res.data.data
  } catch {}
}

const doSearch = () => {
  filters.page = 1
  fetchItems()
}

const resetFilters = () => {
  filters.keyword = ''
  filters.status = ''
  filters.category_id = ''
  doSearch()
}

const handleCommand = (row, cmd) => {
  if (cmd === 'delete') {
    deleteItem(row)
  } else if (cmd === 'approve') {
    changeStatus(row, 'on_sale')
  } else if (cmd === 'reject') {
    changeStatus(row, 'off')
  } else {
    changeStatus(row, cmd)
  }
}

const changeStatus = async (item, newStatus) => {
  const actionLabel = statusMap[newStatus]?.label ?? newStatus
  try {
    await api.put(`/items/${item.id}/status`, { status: newStatus })
    ElMessage.success(`已将「${item.title}」设为${actionLabel}`)
    fetchItems()
  } catch (error) {
    ElMessage.error(error.response?.data?.message || '操作失败')
  }
}

const deleteItem = async (item) => {
  try {
    await ElMessageBox.confirm(
      `确定删除商品「${item.title}」？此操作不可恢复。`,
      '确认删除',
      { confirmButtonText: '删除', cancelButtonText: '取消', type: 'warning' }
    )
    await api.delete(`/items/${item.id}`)
    ElMessage.success('删除成功')
    fetchItems()
  } catch (error) {
    if (error === 'cancel' || error?.message?.includes('cancel')) return
    ElMessage.error(error.response?.data?.message || '删除失败')
  }
}

onMounted(() => {
  fetchItems()
  fetchCategories()
})
</script>

<style scoped>
.items-page { padding: 0; }
</style>