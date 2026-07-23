<template>
  <div class="activities-page">
    <el-card>
      <template #header>
        <div class="header-actions">
          <span>活动管理</span>
          <el-button type="primary" @click="openAdd">
            <el-icon><Plus /></el-icon> 新增活动
          </el-button>
        </div>
      </template>

      <el-table :data="list" v-loading="loading" stripe row-key="id">
        <el-table-column type="expand">
          <template #default="{ row }">
            <div class="expand-items" v-loading="row._loadingItems">
              <div class="expand-header">
                <span>「{{ row.name }}」商品列表</span>
                <el-button size="small" type="primary" @click.stop="fetchActivityItems(row)">刷新</el-button>
              </div>
              <el-table :data="row._items || []" size="small" v-if="row._items && row._items.length > 0">
                <el-table-column prop="id" label="ID" width="60" />
                <el-table-column prop="title" label="标题" min-width="180" />
                <el-table-column prop="price" label="价格" width="90">
                  <template #default="{ row: r }">¥{{ r.price }}</template>
                </el-table-column>
                <el-table-column prop="status" label="状态" width="90">
                  <template #default="{ row: r }">
                    <el-tag :type="r.status === 'on_sale' ? 'success' : r.status === 'pending' ? 'warning' : 'info'" size="small">
                      {{ r.status === 'on_sale' ? '在售' : r.status === 'pending' ? '待审' : r.status }}
                    </el-tag>
                  </template>
                </el-table-column>
                <el-table-column prop="seller_name" label="卖家" width="100" />
                <el-table-column prop="views_count" label="浏览" width="70" />
              </el-table>
              <el-empty v-else-if="row._items" description="该活动暂无商品" :image-size="40" />
            </div>
          </template>
        </el-table-column>
        <el-table-column label="活动名称" min-width="200">
          <template #default="{ row }">
            <div class="activity-name-cell">
              <img
                v-if="row.banner_url"
                :src="row.banner_url.startsWith('http') ? row.banner_url : `http://localhost:3000${row.banner_url}`"
                class="thumb"
              />
              <span>{{ row.name }}</span>
            </div>
          </template>
        </el-table-column>
        <el-table-column label="类型/标识" width="140" show-overflow-tooltip>
          <template #default="{ row }">
            <span style="font-size:13px;color:#606266">{{ row.type }}</span>
          </template>
        </el-table-column>
        <el-table-column label="活动时间" width="240">
          <template #default="{ row }">
            <div class="time-cell">
              <div>{{ formatShort(row.start_time) }}</div>
              <div>至 {{ formatShort(row.end_time) }}</div>
            </div>
          </template>
        </el-table-column>
        <el-table-column label="状态" width="100" align="center">
          <template #default="{ row }">
            <el-tag v-if="!row.is_enabled" type="danger" size="small">已停用</el-tag>
            <el-tag v-else-if="row.time_status === 'active'" type="success" size="small">进行中</el-tag>
            <el-tag v-else-if="row.time_status === 'upcoming'" type="warning" size="small">未开始</el-tag>
            <el-tag v-else type="info" size="small">已结束</el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="sort_order" label="排序" width="70" align="center" />
        <el-table-column prop="item_count" label="商品数" width="85" align="center" />
        <el-table-column label="操作" width="250" fixed="right">
          <template #default="{ row }">
            <el-button size="small" type="primary" @click="openEdit(row)">编辑</el-button>
            <el-button
              size="small"
              :type="row.is_enabled ? 'warning' : 'success'"
              @click="toggleActivity(row)"
            >
              {{ row.is_enabled ? '停用' : '启用' }}
            </el-button>
            <el-button size="small" type="danger" @click="deleteActivity(row)">删除</el-button>
          </template>
        </el-table-column>
      </el-table>

      <div class="pagination" v-if="total > pageSize" style="margin-top:16px;display:flex;justify-content:flex-end">
        <el-pagination
          v-model:current-page="page"
          :page-size="pageSize"
          :total="total"
          layout="prev, pager, next"
          @current-change="fetchList"
        />
      </div>
    </el-card>

    <!-- 新增/编辑弹窗 -->
    <el-dialog v-model="dialogVisible" :title="dialogTitle" width="560px" @close="resetForm">
      <el-form :model="form" :rules="rules" ref="formRef" label-width="100px">
        <el-form-item label="活动名称" prop="name">
          <el-input v-model="form.name" placeholder="请输入活动名称" maxlength="100" />
        </el-form-item>
        <el-form-item label="类型标识" prop="type">
          <el-input v-model="form.type" placeholder="如 graduation_sale" maxlength="50" />
          <div class="form-tip">英文标识，用于前端区分样式，如 graduation_sale、freshman_market</div>
        </el-form-item>
        <el-form-item label="活动简介" prop="description">
          <el-input v-model="form.description" type="textarea" :rows="3" placeholder="请输入活动简介" />
        </el-form-item>
        <el-form-item label="Banner 图片">
          <el-input v-model="form.banner_url" placeholder="Banner 图片 URL（可手动输入或上传）" />
        </el-form-item>
        <el-form-item label="开始时间" prop="start_time">
          <el-date-picker
            v-model="form.start_time"
            type="datetime"
            placeholder="选择开始时间"
            format="YYYY-MM-DD HH:mm:ss"
            value-format="YYYY-MM-DD HH:mm:ss"
            style="width:100%"
          />
        </el-form-item>
        <el-form-item label="结束时间" prop="end_time">
          <el-date-picker
            v-model="form.end_time"
            type="datetime"
            placeholder="选择结束时间"
            format="YYYY-MM-DD HH:mm:ss"
            value-format="YYYY-MM-DD HH:mm:ss"
            style="width:100%"
          />
        </el-form-item>
        <el-form-item label="排序值" prop="sort_order">
          <el-input-number v-model="form.sort_order" :min="0" :max="999" />
          <div class="form-tip">数值越大越靠前</div>
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
const list = ref([])
const page = ref(1)
const pageSize = 15
const total = ref(0)

const dialogVisible = ref(false)
const dialogTitle = ref('')
const formRef = ref(null)
const editingId = ref(null)

const form = ref({
  name: '',
  type: '',
  description: '',
  banner_url: '',
  start_time: '',
  end_time: '',
  sort_order: 0
})

const rules = {
  name: [{ required: true, message: '请输入活动名称', trigger: 'blur' }],
  type: [{ required: true, message: '请输入类型标识', trigger: 'blur' }],
  start_time: [{ required: true, message: '请选择开始时间', trigger: 'change' }],
  end_time: [{ required: true, message: '请选择结束时间', trigger: 'change' }]
}

const formatTime = (t) => {
  if (!t) return ''
  const d = new Date(t)
  return `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')} ${String(d.getHours()).padStart(2,'0')}:${String(d.getMinutes()).padStart(2,'0')}`
}
const formatShort = (t) => {
  if (!t) return ''
  const d = new Date(t)
  return `${d.getMonth()+1}/${d.getDate()} ${String(d.getHours()).padStart(2,'0')}:${String(d.getMinutes()).padStart(2,'0')}`
}

const fetchActivityItems = async (row) => {
  row._loadingItems = true
  try {
    const res = await api.get(`/activities/${row.id}/items`, { params: { pageSize: 50 } })
    if (res.data?.code === 0) {
      row._items = res.data.data.list
    }
  } catch (e) {
    row._items = []
  }
  row._loadingItems = false
}

const fetchList = async () => {
  loading.value = true
  try {
    const res = await api.get('/activities/all', { params: { page: page.value, pageSize } })
    if (res.data?.code === 0) {
      list.value = res.data.data.list
      total.value = res.data.data.total
    } else {
      ElMessage.error(res.data?.message || '获取活动列表失败')
    }
  } catch (e) {
    const msg = e.response?.data?.message || e.response?.data?.error || e.message || '获取活动列表失败'
    ElMessage.error(msg)
  } finally {
    loading.value = false
  }
}

const openAdd = () => {
  editingId.value = null
  dialogTitle.value = '新增活动'
  form.value = { name: '', type: '', description: '', banner_url: '', start_time: '', end_time: '', sort_order: 0 }
  dialogVisible.value = true
}

const openEdit = (row) => {
  editingId.value = row.id
  dialogTitle.value = '编辑活动'
  form.value = {
    name: row.name,
    type: row.type,
    description: row.description || '',
    banner_url: row.banner_url || '',
    start_time: row.start_time ? row.start_time.replace('T', ' ').substring(0, 19) : '',
    end_time: row.end_time ? row.end_time.replace('T', ' ').substring(0, 19) : '',
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
    if (editingId.value) {
      await api.put(`/activities/${editingId.value}`, form.value)
      ElMessage.success('更新成功')
    } else {
      await api.post('/activities', form.value)
      ElMessage.success('创建成功')
    }
    dialogVisible.value = false
    fetchList()
  } catch (e) {
    ElMessage.error(e.response?.data?.message || '操作失败')
  } finally {
    submitting.value = false
  }
}

const toggleActivity = async (row) => {
  const action = row.is_enabled ? '停用' : '启用'
  try {
    await ElMessageBox.confirm(`确定${action}活动「${row.name}」吗？`, '确认操作', {
      confirmButtonText: `确定${action}`,
      cancelButtonText: '取消',
      type: 'warning'
    })
    const res = await api.put(`/activities/${row.id}/toggle`)
    ElMessage.success(res.data.message || `${action}成功`)
    fetchList()
  } catch (e) {
    if (e === 'cancel' || e?.toString() === 'cancel') return
    ElMessage.error(e.response?.data?.message || '操作失败')
  }
}

const deleteActivity = async (row) => {
  try {
    await ElMessageBox.confirm(`确定删除活动「${row.name}」吗？关联商品将自动解除活动关联。`, '确认删除', {
      confirmButtonText: '确定删除',
      cancelButtonText: '取消',
      type: 'warning'
    })
    await api.delete(`/activities/${row.id}`)
    ElMessage.success('删除成功')
    fetchList()
  } catch (e) {
    if (e === 'cancel' || e?.toString() === 'cancel') return
    ElMessage.error(e.response?.data?.message || '删除失败')
  }
}

onMounted(fetchList)
</script>

<style scoped>
.header-actions {
  display: flex;
  justify-content: space-between;
  align-items: center;
}
.activity-name-cell {
  display: flex;
  align-items: center;
  gap: 8px;
}
.thumb {
  width: 48px;
  height: 32px;
  object-fit: cover;
  border-radius: 4px;
  flex-shrink: 0;
}
.time-cell {
  font-size: 13px;
  line-height: 1.7;
  white-space: nowrap;
}
.expand-items { padding: 12px 20px; background: #fafafa; }
.expand-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 12px; font-weight: 600; color: #303133; }
.form-tip {
  font-size: 12px;
  color: #909399;
  margin-top: 4px;
}
</style>
