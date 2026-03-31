<template>
  <div class="categories-page">
    <el-card>
      <template #header>
        <div class="header-actions">
          <span>分类管理</span>
          <el-button type="primary" @click="openAdd(null)">
            <el-icon><Plus /></el-icon> 新增顶级分类
          </el-button>
        </div>
      </template>

      <el-table
        :data="tree"
        v-loading="loading"
        row-key="id"
        :tree-props="{ children: 'children' }"
        default-expand-all
        stripe
      >
        <el-table-column prop="name" label="分类名称" min-width="180" />
        <el-table-column prop="parent_id" label="层级" width="100">
          <template #default="{ row }">
            <el-tag size="small" :type="row.parent_id === 0 ? 'primary' : 'info'">
              {{ row.parent_id === 0 ? '顶级' : '子分类' }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="sort_order" label="排序" width="80" />
        <el-table-column label="操作" width="220">
          <template #default="{ row }">
            <el-button size="small" @click="openAdd(row)">添加子类</el-button>
            <el-button size="small" type="primary" @click="openEdit(row)">编辑</el-button>
            <el-button size="small" type="danger" @click="deleteCategory(row)">删除</el-button>
          </template>
        </el-table-column>
      </el-table>
    </el-card>

    <!-- 新增/编辑弹窗 -->
    <el-dialog v-model="dialogVisible" :title="dialogTitle" width="420px" @close="resetForm">
      <el-form :model="form" :rules="rules" ref="formRef" label-width="90px">
        <el-form-item label="父级分类">
          <el-input :value="form.parent_name || '顶级分类'" disabled />
        </el-form-item>
        <el-form-item label="分类名称" prop="name">
          <el-input v-model="form.name" placeholder="请输入分类名称" />
        </el-form-item>
        <el-form-item label="排序值" prop="sort_order">
          <el-input-number v-model="form.sort_order" :min="0" :max="999" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="dialogVisible = false">取消</el-button>
        <el-button type="primary" @click="submitForm" :loading="submitting">确定</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { Plus } from '@element-plus/icons-vue'
import api from '@/api'

const loading = ref(false)
const submitting = ref(false)
const tree = ref([])
const flat = ref([])

const dialogVisible = ref(false)
const dialogTitle = ref('')
const formRef = ref(null)
const editingId = ref(null)

const form = ref({ name: '', parent_id: 0, parent_name: '', sort_order: 0 })
const rules = {
  name: [{ required: true, message: '请输入分类名称', trigger: 'blur' }]
}

// 平铺数组 → 树结构
const buildTree = (list) => {
  const map = {}
  const roots = []
  list.forEach(item => { map[item.id] = { ...item, children: [] } })
  list.forEach(item => {
    if (item.parent_id === 0) {
      roots.push(map[item.id])
    } else if (map[item.parent_id]) {
      map[item.parent_id].children.push(map[item.id])
    }
  })
  // 移除空 children（el-table tree 不需要空数组，直接 undefined）
  const clean = (nodes) => nodes.map(n => {
    if (n.children.length === 0) {
      const { children, ...rest } = n
      return rest
    }
    return { ...n, children: clean(n.children) }
  })
  return clean(roots)
}

const fetchCategories = async () => {
  loading.value = true
  try {
    const res = await api.get('/categories')
    if (res.data?.code === 0 && Array.isArray(res.data.data)) {
      flat.value = res.data.data
      tree.value = buildTree(res.data.data)
    }
  } catch (e) {
    ElMessage.error('获取分类失败')
  } finally {
    loading.value = false
  }
}

const openAdd = (parentRow) => {
  editingId.value = null
  dialogTitle.value = parentRow ? `新增子分类（父：${parentRow.name}）` : '新增顶级分类'
  form.value = {
    name: '',
    parent_id: parentRow ? parentRow.id : 0,
    parent_name: parentRow ? parentRow.name : '',
    sort_order: 0
  }
  dialogVisible.value = true
}

const openEdit = (row) => {
  editingId.value = row.id
  dialogTitle.value = '编辑分类'
  const parentName = flat.value.find(c => c.id === row.parent_id)?.name || ''
  form.value = {
    name: row.name,
    parent_id: row.parent_id,
    parent_name: parentName || (row.parent_id === 0 ? '' : String(row.parent_id)),
    sort_order: row.sort_order
  }
  dialogVisible.value = true
}

const resetForm = () => {
  formRef.value?.resetFields()
  editingId.value = null
}

const submitForm = async () => {
  await formRef.value.validate()
  submitting.value = true
  try {
    const payload = {
      name: form.value.name,
      parent_id: form.value.parent_id,
      sort_order: form.value.sort_order
    }
    if (editingId.value) {
      await api.put(`/categories/${editingId.value}`, payload)
      ElMessage.success('更新成功')
    } else {
      await api.post('/categories', payload)
      ElMessage.success('创建成功')
    }
    dialogVisible.value = false
    fetchCategories()
  } catch (e) {
    ElMessage.error(e.response?.data?.message || '操作失败')
  } finally {
    submitting.value = false
  }
}

const deleteCategory = async (row) => {
  try {
    await ElMessageBox.confirm(
      `确定要删除分类"${row.name}"吗？如存在子分类请先删除子分类。`,
      '确认删除',
      { confirmButtonText: '确定删除', cancelButtonText: '取消', type: 'warning' }
    )
    await api.delete(`/categories/${row.id}`)
    ElMessage.success('删除成功')
    fetchCategories()
  } catch (e) {
    if (e === 'cancel' || e?.toString() === 'cancel') return
    ElMessage.error(e.response?.data?.message || '删除失败')
  }
}

onMounted(fetchCategories)
</script>

<style scoped>
.header-actions {
  display: flex;
  justify-content: space-between;
  align-items: center;
}
</style>
