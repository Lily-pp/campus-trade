<template>
  <div class="users-page">
    <el-card>
      <template #header>
        <div class="header-actions">
          <span>用户管理</span>
          <div class="header-right">
            <el-input
              v-model="keyword"
              placeholder="搜索用户名/姓名"
              clearable
              style="width: 220px; margin-right: 12px"
              @keyup.enter="fetchUsers"
              @clear="fetchUsers"
            >
              <template #suffix>
                <el-icon style="cursor:pointer" @click="fetchUsers"><Search /></el-icon>
              </template>
            </el-input>
            <el-button type="primary" @click="openCreate">
              <el-icon><Plus /></el-icon> 新增用户
            </el-button>
          </div>
        </div>
      </template>

      <el-table :data="users" v-loading="loading" stripe>
        <el-table-column prop="id" label="ID" width="70" />
        <el-table-column prop="username" label="用户名" width="140" />
        <el-table-column prop="real_name" label="姓名" width="120" />
        <el-table-column prop="role" label="角色" width="110">
          <template #default="{ row }">
            <el-tag :type="roleMap[row.role]?.type || 'info'" size="small">
              {{ roleMap[row.role]?.label || row.role }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="campus" label="校区" width="120" />
        <el-table-column prop="status" label="状态" width="100">
          <template #default="{ row }">
            <el-tag :type="row.status === 1 ? 'success' : 'danger'" size="small">
              {{ row.status === 1 ? '正常' : '已禁用' }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="created_at" label="注册时间" min-width="160">
          <template #default="{ row }">{{ formatTime(row.created_at) }}</template>
        </el-table-column>
        <el-table-column label="操作" width="180" fixed="right">
          <template #default="{ row }">
            <el-button
              size="small"
              :type="row.status === 1 ? 'warning' : 'success'"
              @click="toggleStatus(row)"
            >
              {{ row.status === 1 ? '禁用' : '启用' }}
            </el-button>
            <el-button size="small" type="danger" @click="deleteUser(row)">删除</el-button>
          </template>
        </el-table-column>
      </el-table>

      <!-- 分页 -->
      <div class="pagination">
        <el-pagination
          background
          layout="total, prev, pager, next"
          :total="total"
          :page-size="pageSize"
          v-model:current-page="page"
          @current-change="fetchUsers"
        />
      </div>
    </el-card>

    <!-- 新增用户弹窗 -->
    <el-dialog v-model="dialogVisible" title="新增用户" width="440px" @close="resetForm">
      <el-form :model="form" :rules="rules" ref="formRef" label-width="80px">
        <el-form-item label="用户名" prop="username">
          <el-input v-model="form.username" placeholder="3-20 个字符" />
        </el-form-item>
        <el-form-item label="密码" prop="password">
          <el-input v-model="form.password" type="password" show-password placeholder="请输入密码" />
        </el-form-item>
        <el-form-item label="姓名">
          <el-input v-model="form.real_name" placeholder="可选" />
        </el-form-item>
        <el-form-item label="角色" prop="role">
          <el-select v-model="form.role" style="width:100%">
            <el-option label="前台用户" value="user" />
            <el-option label="运营人员" value="operator" />
            <el-option label="管理员" value="admin" />
          </el-select>
        </el-form-item>
        <el-form-item label="校区">
          <el-input v-model="form.campus" placeholder="可选" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="dialogVisible = false">取消</el-button>
        <el-button type="primary" @click="submitCreate" :loading="submitting">创建</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { Plus, Search } from '@element-plus/icons-vue'
import api from '@/api'

const users = ref([])
const loading = ref(false)
const submitting = ref(false)
const total = ref(0)
const page = ref(1)
const pageSize = 20
const keyword = ref('')

const dialogVisible = ref(false)
const formRef = ref(null)
const form = ref({ username: '', password: '', real_name: '', role: 'user', campus: '' })
const rules = {
  username: [
    { required: true, message: '请输入用户名', trigger: 'blur' },
    { min: 3, max: 20, message: '用户名长度 3-20', trigger: 'blur' }
  ],
  password: [{ required: true, message: '请输入密码', trigger: 'blur' }],
  role:     [{ required: true, message: '请选择角色', trigger: 'change' }]
}

const roleMap = {
  admin:    { label: '管理员', type: 'danger' },
  operator: { label: '运营人员', type: 'warning' },
  user:     { label: '前台用户', type: '' }
}

const formatTime = (t) => t ? new Date(t).toLocaleString('zh-CN') : '-'

const fetchUsers = async () => {
  loading.value = true
  try {
    const res = await api.get('/users', {
      params: { page: page.value, pageSize, keyword: keyword.value || undefined }
    })
    if (res.data?.code === 0) {
      users.value = res.data.data.list
      total.value = res.data.data.total
    }
  } catch (e) {
    ElMessage.error('获取用户列表失败')
  } finally {
    loading.value = false
  }
}

const openCreate = () => {
  form.value = { username: '', password: '', real_name: '', role: 'user', campus: '' }
  dialogVisible.value = true
}

const resetForm = () => formRef.value?.resetFields()

const submitCreate = async () => {
  await formRef.value.validate()
  submitting.value = true
  try {
    await api.post('/users', form.value)
    ElMessage.success('创建成功')
    dialogVisible.value = false
    fetchUsers()
  } catch (e) {
    ElMessage.error(e.response?.data?.message || '创建失败')
  } finally {
    submitting.value = false
  }
}

const toggleStatus = async (row) => {
  const newStatus = row.status === 1 ? 0 : 1
  const action = newStatus === 0 ? '禁用' : '启用'
  try {
    await ElMessageBox.confirm(`确定要${action}用户"${row.username}"吗？`, '确认', { type: 'warning' })
    await api.put(`/users/${row.id}/status`, { status: newStatus })
    ElMessage.success(`已${action}`)
    fetchUsers()
  } catch (e) {
    if (e === 'cancel' || e?.toString() === 'cancel') return
    ElMessage.error(e.response?.data?.message || `${action}失败`)
  }
}

const deleteUser = async (row) => {
  try {
    await ElMessageBox.confirm(`确定要删除用户"${row.username}"吗？此操作不可恢复。`, '确认删除', {
      confirmButtonText: '确定删除', cancelButtonText: '取消', type: 'warning'
    })
    await api.delete(`/users/${row.id}`)
    ElMessage.success('删除成功')
    fetchUsers()
  } catch (e) {
    if (e === 'cancel' || e?.toString() === 'cancel') return
    ElMessage.error(e.response?.data?.message || '删除失败')
  }
}

onMounted(fetchUsers)
</script>

<style scoped>
.header-actions {
  display: flex;
  justify-content: space-between;
  align-items: center;
}
.header-right {
  display: flex;
  align-items: center;
}
.pagination {
  margin-top: 16px;
  display: flex;
  justify-content: flex-end;
}
</style>
