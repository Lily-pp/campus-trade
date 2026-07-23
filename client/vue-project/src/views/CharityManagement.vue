<template>
  <div class="charity-admin">
    <el-card>
      <template #header><span>🎓 毕业公益循环计划 — 管理</span></template>
      <el-tabs v-model="tab" @tab-change="fetchData">
        <el-tab-pane label="公益商品" name="items" />
        <el-tab-pane label="回收池" name="pool" />
        <el-tab-pane label="捐赠记录" name="donations" />
      </el-tabs>

      <!-- 公益商品列表 -->
      <el-table v-if="tab === 'items'" :data="items" v-loading="loading" stripe style="width:100%">
        <el-table-column prop="id" label="ID" width="55" />
        <el-table-column prop="title" label="商品" min-width="180" show-overflow-tooltip />
        <el-table-column label="发布者" width="90" prop="owner_name" />
        <el-table-column label="校区" width="85">
          <template #default="{ row }"><span style="font-size:12px">{{ row.campus || '-' }}</span></template>
        </el-table-column>
        <el-table-column label="申请数" width="75" align="center">
          <template #default="{ row }">
            <el-tag v-if="row.apply_count > 0" type="warning" size="small">{{ row.apply_count }}</el-tag>
            <span v-else style="color:#c0c4cc">0</span>
          </template>
        </el-table-column>
        <el-table-column label="状态" width="85" align="center">
          <template #default="{ row }">
            <el-tag :type="row.status==='on_sale'?'success':row.status==='sold'?'info':'warning'" size="small">
              {{ row.status==='on_sale'?'在售':row.status==='sold'?'已送出':row.status }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="时间" width="105" align="center">
          <template #default="{ row }"><span style="font-size:12px">{{ formatShort(row.created_at) }}</span></template>
        </el-table-column>
        <el-table-column label="操作" width="70" align="center">
          <template #default="{ row }">
            <el-button size="small" type="danger" @click="deleteCharityItem(row)">删除</el-button>
          </template>
        </el-table-column>
      </el-table>

      <!-- 回收池 -->
      <div v-if="tab === 'pool'" v-loading="loading">
        <div style="margin-bottom:14px;display:flex;gap:10px">
          <el-button type="warning" @click="selectAll" :disabled="pool.length===0">全选</el-button>
          <el-button type="primary" @click="batchDonate" :disabled="selectedIds.length===0">
            批量捐赠 ({{ selectedIds.length }})
          </el-button>
        </div>
        <el-table :data="pool" stripe @selection-change="onSelectionChange" ref="poolTable" style="width:100%">
          <el-table-column type="selection" width="45" />
          <el-table-column prop="id" label="ID" width="55" />
          <el-table-column label="图片" width="60">
            <template #default="{ row }">
              <img v-if="row.cover_image" :src="row.cover_image.startsWith('http')?row.cover_image:`http://localhost:3000${row.cover_image}`" style="width:40px;height:30px;object-fit:cover;border-radius:4px" />
            </template>
          </el-table-column>
          <el-table-column prop="title" label="商品" min-width="160" show-overflow-tooltip />
          <el-table-column label="发布者" width="85" prop="owner_name" />
          <el-table-column label="位置" width="85" prop="campus" />
          <el-table-column label="发布时间" width="105" align="center">
            <template #default="{ row }"><span style="font-size:12px">{{ formatShort(row.created_at) }}</span></template>
          </el-table-column>
        </el-table>
        <el-empty v-if="pool.length===0 && !loading" description="回收池为空，所有公益商品已处理" />
      </div>

      <!-- 捐赠记录 -->
      <el-table v-if="tab === 'donations'" :data="donations" v-loading="loading" stripe style="width:100%">
        <el-table-column prop="id" label="ID" width="55" />
        <el-table-column prop="item_title" label="商品" min-width="140" show-overflow-tooltip />
        <el-table-column label="批次" width="100" prop="batch_id" />
        <el-table-column label="捐赠组织" width="130" prop="organization" show-overflow-tooltip />
        <el-table-column label="描述" min-width="150" prop="description" show-overflow-tooltip />
        <el-table-column label="捐赠时间" width="150">
          <template #default="{ row }">{{ formatTime(row.donation_time) }}</template>
        </el-table-column>
        <el-table-column label="操作人" width="85" prop="creator_name" />
      </el-table>

      <!-- 批量捐赠弹窗 -->
      <el-dialog v-model="donateVisible" title="📦 批量公益捐赠" width="480px">
        <el-form :model="donateForm" label-width="90px">
          <el-form-item label="捐赠批次"><el-input v-model="donateForm.batch_id" placeholder="如 BATCH-2026-07" /></el-form-item>
          <el-form-item label="捐赠组织"><el-input v-model="donateForm.organization" placeholder="如 山区希望小学" /></el-form-item>
          <el-form-item label="捐赠说明"><el-input v-model="donateForm.description" type="textarea" :rows="2" /></el-form-item>
          <el-form-item label="证明图片"><el-input v-model="donateForm.proof_image" placeholder="图片URL" /></el-form-item>
          <el-form-item label="捐赠时间"><el-date-picker v-model="donateForm.donation_time" type="datetime" value-format="YYYY-MM-DD HH:mm:ss" style="width:100%" /></el-form-item>
        </el-form>
        <template #footer>
          <el-button @click="donateVisible=false">取消</el-button>
          <el-button type="primary" @click="submitDonation" :loading="submitting">确认捐赠 ({{ selectedIds.length }} 件)</el-button>
        </template>
      </el-dialog>
    </el-card>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import api from '@/api'

const tab = ref('items')
const items = ref([])
const pool = ref([])
const donations = ref([])
const loading = ref(false)
const selectedIds = ref([])
const donateVisible = ref(false)
const submitting = ref(false)
const poolTable = ref(null)
const donateForm = ref({ batch_id: '', organization: '', description: '', proof_image: '', donation_time: '' })

const fetchData = async () => {
  loading.value = true
  try {
    if (tab.value === 'items') {
      const res = await api.get('/charity/items', { params: { pageSize: 100 } })
      if (res.data?.code === 0) items.value = res.data.data.list || []
    } else if (tab.value === 'pool') {
      const res = await api.get('/charity/recycle-pool')
      if (res.data?.code === 0) pool.value = res.data.data || []
      selectedIds.value = []
    } else if (tab.value === 'donations') {
      const res = await api.get('/charity/donations')
      if (res.data?.code === 0) donations.value = res.data.data || []
    }
  } catch (e) { /* ignore */ }
  loading.value = false
}

const deleteCharityItem = async (row) => {
  try {
    await ElMessageBox.confirm('确定删除？', '确认', { type: 'warning' })
    await api.delete(`/items/${row.id}`)
    ElMessage.success('已删除'); fetchData()
  } catch (e) { if (e !== 'cancel') ElMessage.error('删除失败') }
}

const onSelectionChange = (rows) => { selectedIds.value = rows.map(r => r.id) }
const selectAll = () => { poolTable.value?.toggleAllSelection() }

const batchDonate = () => {
  if (selectedIds.value.length === 0) return ElMessage.warning('请选择商品')
  donateForm.value = { batch_id: '', organization: '', description: '', proof_image: '', donation_time: '' }
  donateVisible.value = true
}

const submitDonation = async () => {
  submitting.value = true
  try {
    const res = await api.post('/charity/donations', { ...donateForm.value, item_ids: selectedIds.value })
    if (res.data?.code === 0) { ElMessage.success(res.data.message); donateVisible.value = false; fetchData() }
  } catch (e) { ElMessage.error('操作失败') }
  submitting.value = false
}

const formatShort = (d) => d ? new Date(d).toLocaleDateString('zh-CN') : ''
const formatTime = (t) => t ? new Date(t).toLocaleString('zh-CN') : ''

onMounted(fetchData)
</script>
