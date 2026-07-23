<template>
  <div class="services-admin">
    <!-- 筛选栏 -->
    <el-card shadow="never" style="margin-bottom:12px">
      <el-row :gutter="12" align="middle">
        <el-col :span="6">
          <el-input v-model="filters.keyword" placeholder="搜索名称..." clearable @keyup.enter="doSearch" @clear="doSearch">
            <template #prefix><el-icon><Search /></el-icon></template>
          </el-input>
        </el-col>
        <el-col :span="4" v-if="tab !== 'orders'">
          <el-select v-model="filters.status" placeholder="全部状态" clearable @change="doSearch" style="width:100%">
            <el-option v-for="s in statusOptions" :key="s.value" :label="s.label" :value="s.value" />
          </el-select>
        </el-col>
        <el-col :span="4" v-if="tab !== 'orders'">
          <el-select v-model="filters.approved" placeholder="审核状态" clearable @change="doSearch" style="width:100%">
            <el-option label="待审核" value="pending" />
            <el-option label="已通过" value="approved" />
            <el-option label="已拒绝" value="rejected" />
          </el-select>
        </el-col>
        <el-col :span="4">
          <el-button type="primary" @click="doSearch"><el-icon><Search /></el-icon>&nbsp;搜索</el-button>
          <el-button @click="resetFilters">重置</el-button>
        </el-col>
      </el-row>
    </el-card>

    <el-card>
      <template #header>
        <span>校园服务管理 <el-tag type="info" size="small" style="margin-left:8px">共 {{ total }} 条</el-tag></span>
      </template>
      <el-tabs v-model="tab" @tab-change="doSearch">
        <el-tab-pane label="寄存服务" name="services" />
        <el-tab-pane label="寄存需求" name="requests" />
        <el-tab-pane label="转租物品" name="rentals" />
        <el-tab-pane label="服务订单" name="orders" />
      </el-tabs>

      <!-- 服务/需求/转租 列表 -->
      <el-table v-if="tab !== 'orders'" :data="list" v-loading="loading" stripe style="width:100%">
        <el-table-column prop="id" label="ID" width="55" />
        <el-table-column prop="title" label="标题" min-width="180" show-overflow-tooltip />
        <el-table-column label="类型" width="90" align="center">
          <template #default="{ row }">
            <el-tag size="small" type="info">{{ tab === 'rentals' ? catLabel(row.category) : typeLabel(tab==='services'?row.storage_type:row.item_type) }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="校区" width="85" align="center">
          <template #default="{ row }"><span style="font-size:13px">{{ row.campus || '-' }}</span></template>
        </el-table-column>
        <el-table-column label="发布者" width="85" show-overflow-tooltip>
          <template #default="{ row }">{{ row.provider_name || row.requester_name || row.owner_name || '-' }}</template>
        </el-table-column>
        <el-table-column label="审核" width="85" align="center">
          <template #default="{ row }">
            <el-tag v-if="row.is_approved" type="success" size="small">已通过</el-tag>
            <el-tag v-else-if="row.status==='rejected'" type="danger" size="small">已拒绝</el-tag>
            <el-tag v-else type="warning" size="small">待审核</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="服务状态" width="95" align="center">
          <template #default="{ row }">
            <template v-if="row.status === 'rejected'"><el-tag type="danger" size="small">已拒绝</el-tag></template>
            <template v-else-if="tab==='services'">
              <el-tag :type="row.status==='available'?'success':row.status==='almost_full'?'warning':'info'" size="small">
                {{ row.status==='available'?'空余':row.status==='almost_full'?'即将约满':row.status==='pending'?'待审核':row.status }}
              </el-tag>
            </template>
            <template v-else-if="tab==='requests'">
              <el-tag :type="row.status==='searching'?'warning':'info'" size="small">{{ row.status==='searching'?'寻找中':row.status==='pending'?'待审核':row.status }}</el-tag>
            </template>
            <template v-else>
              <el-tag :type="row.status==='available'?'success':'info'" size="small">{{ row.status==='available'?'可租':row.status==='pending'?'待审核':row.status }}</el-tag>
            </template>
          </template>
        </el-table-column>
        <el-table-column label="发布时间" width="105" align="center">
          <template #default="{ row }"><span style="font-size:12px">{{ formatShort(row.created_at) }}</span></template>
        </el-table-column>
        <el-table-column label="操作" width="140" fixed="right" align="center">
          <template #default="{ row }">
            <template v-if="!row.is_approved && row.status !== 'rejected'">
              <el-button size="small" type="success" @click="approveItem(row,true)">通过</el-button>
              <el-button size="small" type="danger" @click="approveItem(row,false)">拒绝</el-button>
            </template>
            <el-button v-else size="small" type="danger" @click="deleteItem(row)">删除</el-button>
          </template>
        </el-table-column>
      </el-table>

      <!-- 服务订单列表 -->
      <div v-if="tab === 'orders'" v-loading="loading">
        <h4 style="margin-bottom:12px">寄存预约订单</h4>
        <el-table :data="storageOrders" stripe style="width:100%;margin-bottom:24px" size="small">
          <el-table-column prop="id" label="ID" width="60" />
          <el-table-column prop="service_title" label="寄存服务" min-width="150" show-overflow-tooltip />
          <el-table-column label="预约人" width="85" prop="renter_name" />
          <el-table-column label="提供者" width="85" prop="provider_name" />
          <el-table-column label="物品" width="110" prop="item_desc" show-overflow-tooltip />
          <el-table-column label="时间" width="150">
            <template #default="{ row }"><span style="font-size:12px">{{ row.start_date }} ~ {{ row.end_date }}</span></template>
          </el-table-column>
          <el-table-column label="金额" width="75" align="center">
            <template #default="{ row }"><span style="color:#f56c6c;font-weight:600">¥{{ row.total_price }}</span></template>
          </el-table-column>
          <el-table-column label="状态" width="80" align="center">
            <template #default="{ row }"><el-tag :type="orderStatusType(row.status)" size="small">{{ orderStatusLabel(row.status) }}</el-tag></template>
          </el-table-column>
        </el-table>

        <h4 style="margin-bottom:12px">转租订单</h4>
        <el-table :data="rentalOrders" stripe style="width:100%" size="small">
          <el-table-column prop="id" label="ID" width="60" />
          <el-table-column prop="item_title" label="转租物品" min-width="150" show-overflow-tooltip />
          <el-table-column label="租用方" width="85" prop="renter_name" />
          <el-table-column label="出租方" width="85" prop="owner_name" />
          <el-table-column label="时间" width="150">
            <template #default="{ row }"><span style="font-size:12px">{{ row.start_date }} ~ {{ row.end_date }}</span></template>
          </el-table-column>
          <el-table-column label="金额" width="75" align="center">
            <template #default="{ row }"><span style="color:#f56c6c;font-weight:600">¥{{ row.total_price }}</span></template>
          </el-table-column>
          <el-table-column label="状态" width="80" align="center">
            <template #default="{ row }"><el-tag :type="orderStatusType(row.status)" size="small">{{ orderStatusLabel(row.status) }}</el-tag></template>
          </el-table-column>
        </el-table>
      </div>

      <div style="margin-top:16px;text-align:right" v-if="tab!=='orders' && total > pageSize">
        <el-pagination v-model:current-page="page" :page-size="pageSize" :total="total"
          layout="prev, pager, next" @current-change="fetchData" small />
      </div>
    </el-card>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { Search } from '@element-plus/icons-vue'
import api from '@/api'

const tab = ref('services')
const list = ref([])
const storageOrders = ref([])
const rentalOrders = ref([])
const loading = ref(false)
const page = ref(1)
const pageSize = 20
const total = ref(0)

const filters = ref({ keyword: '', status: '', approved: '' })

const statusOptions = computed(() => {
  if (tab.value === 'services') return [
    { label:'空余', value:'available' }, { label:'即将约满', value:'almost_full' }, { label:'已满', value:'full' }, { label:'待审核', value:'pending' }, { label:'已拒绝', value:'rejected' }
  ]
  if (tab.value === 'requests') return [
    { label:'寻找中', value:'searching' }, { label:'已找到', value:'matched' }, { label:'已关闭', value:'closed' }, { label:'待审核', value:'pending' }, { label:'已拒绝', value:'rejected' }
  ]
  return [
    { label:'可租', value:'available' }, { label:'已租出', value:'rented' }, { label:'待审核', value:'pending' }, { label:'已拒绝', value:'rejected' }
  ]
})

const typeLabel = (t) => ({ bike:'电动车',suitcase:'行李',book:'书籍',appliance:'电器',other:'其他' }[t]||t)
const catLabel = (c) => ({ camera:'相机',drone:'无人机',bike:'电动车',console:'游戏机',projector:'投影仪',racket:'球拍',other:'其他' }[c]||c)
const orderStatusLabel = (s) => ({ pending:'待确认',confirmed:'已确认',active:'进行中',completed:'已完成',cancelled:'已取消' }[s]||s)
const orderStatusType = (s) => ({ pending:'warning',confirmed:'primary',active:'success',completed:'info',cancelled:'danger' }[s]||'info')

const apiMap = { services:'/storage-services', requests:'/storage-requests', rentals:'/rental-items' }

const buildParams = () => {
  const p = { page: page.value, pageSize }
  if (filters.value.keyword) p.keyword = filters.value.keyword
  if (filters.value.status) p.status = filters.value.status
  if (filters.value.approved === 'pending') { p.status = 'pending'; p.approved = 'false' }
  return p
}

const fetchData = async () => {
  loading.value = true
  try {
    if (tab.value === 'orders') {
      const [sRes, rRes] = await Promise.all([api.get('/storage-orders'), api.get('/rental-items/orders')])
      storageOrders.value = sRes.data?.code===0 ? (sRes.data.data||[]) : []
      rentalOrders.value = rRes.data?.code===0 ? (rRes.data.data||[]) : []
    } else {
      const res = await api.get(apiMap[tab.value], { params: buildParams() })
      if (res.data?.code === 0) {
        list.value = res.data.data.list || []
        total.value = res.data.data.total || 0
      }
    }
  } catch (e) { ElMessage.error('获取数据失败') }
  loading.value = false
}

const doSearch = () => { page.value = 1; fetchData() }
const resetFilters = () => { filters.value = { keyword:'',status:'',approved:'' }; doSearch() }

const approveItem = async (row, approved) => {
  try {
    await api.put(`${apiMap[tab.value]}/${row.id}/approve`, { approved })
    ElMessage.success(approved?'审核通过':'已拒绝')
    fetchData()
  } catch (e) { ElMessage.error('操作失败') }
}

const deleteItem = async (row) => {
  try {
    await ElMessageBox.confirm('确定删除？','确认',{ type:'warning' })
    await api.delete(`${apiMap[tab.value]}/${row.id}`)
    ElMessage.success('已删除')
    fetchData()
  } catch (e) { if (e!=='cancel') ElMessage.error('删除失败') }
}

const formatShort = (d) => d ? new Date(d).toLocaleDateString('zh-CN') : ''

onMounted(fetchData)
</script>
