<template>
  <div class="items-page">
    <el-card>
      <template #header>
        <div class="header-actions">
          <span>商品列表</span>
          <el-button type="primary" @click="showCreateDialog = true">
            <el-icon><Plus /></el-icon> 发布商品
          </el-button>
        </div>
      </template>

      <el-table :data="items" v-loading="loading" stripe>
        <el-table-column prop="id" label="ID" width="80" />
        <el-table-column prop="title" label="商品名称" />
        <el-table-column prop="price" label="价格" width="120">
          <template #default="{ row }">¥{{ row.price }}</template>
        </el-table-column>
        <el-table-column prop="category_name" label="分类" width="120" />
        <el-table-column prop="status" label="状态" width="100">
          <template #default="{ row }">
            <el-tag :type="row.status === 'on_sale' ? 'success' : 'info'">
              {{ row.status === 'on_sale' ? '出售中' : '待审核' }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="120">
          <template #default="{ row }">
            <el-button
              type="danger"
              size="small"
              @click="deleteItem(row)"
            >
              删除
            </el-button>
          </template>
        </el-table-column>
      </el-table>
    </el-card>

    <el-dialog v-model="showCreateDialog" title="发布商品" width="500px">
      <el-form :model="newItem" label-width="80px">
        <el-form-item label="商品名称">
          <el-input v-model="newItem.title" />
        </el-form-item>
        <el-form-item label="价格">
          <el-input-number v-model="newItem.price" :min="0" />
        </el-form-item>
        <el-form-item label="分类">
          <el-select v-model="newItem.category_id">
            <el-option v-for="cat in categories" :key="cat.id" :label="cat.name" :value="cat.id" />
          </el-select>
        </el-form-item>
        <el-form-item label="描述">
          <el-input v-model="newItem.description" type="textarea" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="showCreateDialog = false">取消</el-button>
        <el-button type="primary" @click="createItem">确定</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import api from '@/api'

const items = ref([])
const categories = ref([])
const loading = ref(false)
const showCreateDialog = ref(false)
const newItem = ref({ title: '', price: 0, category_id: '', description: '' })

const fetchItems = async () => {
  loading.value = true
  try {
    const res = await api.get('/items')
    // 后端返回的是 { total, data }，所以取 res.data
    if (res.data && Array.isArray(res.data)) {
      items.value = res.data
    } else if (res.data && Array.isArray(res.data.data)) {
      items.value = res.data.data
    } else if (Array.isArray(res)) {
      items.value = res
    } else {
      items.value = []
      console.warn('数据格式不对:', res)
    }
  } catch (error) {
    console.error('获取商品失败:', error)
    ElMessage.error('获取商品失败')
  } finally {
    loading.value = false
  }
}

const fetchCategories = async () => {
  try {
    const res = await api.get('/categories')
    if (Array.isArray(res)) {
      categories.value = res
    } else if (res.data && Array.isArray(res.data)) {
      categories.value = res.data
    } else {
      categories.value = []
    }
  } catch (error) {
    console.error('获取分类失败', error)
  }
}

const createItem = async () => {
  try {
    await api.post('/items', newItem.value)
    ElMessage.success('发布成功')
    showCreateDialog.value = false
    newItem.value = { title: '', price: 0, category_id: '', description: '' }
    fetchItems()
  } catch (error) {
  const status = error.response?.status
  const msg = error.response?.data?.error || '发布失败'
  console.log('deleteItem error', status, msg)
  ElMessage.error(msg)
}
}

const deleteItem = async (item) => {
  try {
    await ElMessageBox.confirm(
      `确定要删除商品"${item.title}"吗？此操作不可恢复。`,
      '确认删除',
      {
        confirmButtonText: '确定删除',
        cancelButtonText: '取消',
        type: 'warning',
      }
    )

    await api.delete(`/items/${item.id}`)
    ElMessage.success('删除成功')
    fetchItems()
  } catch (error) {
    if (error === 'cancel') {
      return // 用户取消删除
    }
    const msg = error.response?.data?.error || '删除失败'
    ElMessage.error(msg)
  }
}

onMounted(() => {
  fetchItems()
  fetchCategories()
})
</script>

<style scoped>
.header-actions {
  display: flex;
  justify-content: space-between;
  align-items: center;
}
</style>