<template>
  <div class="request-page">
    <!-- 页面头部（暖色系） -->
    <div class="page-header">
      <div class="header-left">
        <h2>🔍 寄存需求</h2>
        <p class="header-sub">正在寻找寄存位置的同学，帮助他们解决假期存放难题</p>
      </div>
      <el-button type="warning" size="large" @click="router.push('/publish-storage?type=request')">
        <el-icon><Plus /></el-icon> 发布寄存需求
      </el-button>
    </div>

    <!-- 筛选栏 -->
    <div class="filter-bar warm">
      <div class="filter-row">
        <el-radio-group v-model="filters.item_type" @change="onFilterChange" size="small">
          <el-radio-button value="">全部类型</el-radio-button>
          <el-radio-button value="bike">🛵 电动车</el-radio-button>
          <el-radio-button value="suitcase">🧳 行李</el-radio-button>
          <el-radio-button value="book">📚 书籍</el-radio-button>
          <el-radio-button value="appliance">🔌 小型电器</el-radio-button>
          <el-radio-button value="other">📦 其他</el-radio-button>
        </el-radio-group>
      </div>
      <div class="filter-row-secondary">
        <el-select v-model="filters.campus" placeholder="选择校区" clearable style="width:140px" @change="onFilterChange">
          <el-option label="全部校区" value="" />
          <el-option label="宝山校区" value="宝山校区" />
          <el-option label="延长校区" value="延长校区" />
          <el-option label="嘉定校区" value="嘉定校区" />
          <el-option label="沪东校区" value="沪东校区" />
        </el-select>
        <el-select v-model="filters.sort" style="width:150px" @change="onFilterChange">
          <el-option label="最新发布" value="newest" />
          <el-option label="预算最低" value="budget_asc" />
        </el-select>
      </div>
    </div>

    <!-- 需求列表 -->
    <div v-loading="loading" class="list-container">
      <el-empty v-if="list.length === 0 && !loading" description="暂无寄存需求">
        <span class="empty-hint">目前还没有人发布寄存需求</span>
      </el-empty>

      <div v-else class="request-grid">
        <div v-for="item in list" :key="item.id" class="request-card">
          <div class="card-header">
            <span class="card-icon">{{ iconEmoji(item.item_type) }}</span>
            <h4>
              <el-tag v-if="item.user_id && item.user_id === userStore.user?.id" type="success" size="small" effect="dark" style="margin-right:4px">我的</el-tag>
              {{ item.title }}
            </h4>
            <el-tag v-if="item.status === 'searching'" type="warning" size="small" effect="dark">寻找中</el-tag>
            <el-tag v-else-if="item.status === 'matched'" type="success" size="small">已找到</el-tag>
            <el-tag v-else type="info" size="small">已关闭</el-tag>
          </div>

          <div class="card-body">
            <p v-if="item.description" class="desc">{{ item.description }}</p>
            <div class="meta-grid">
              <div class="meta-item">
                <span class="meta-label">📦 需要寄存</span>
                <span>{{ typeLabel(item.item_type) }}</span>
              </div>
              <div class="meta-item" v-if="item.campus">
                <span class="meta-label">📍 目标校区</span>
                <span>{{ item.campus }}</span>
              </div>
              <div class="meta-item" v-if="item.expected_start_time">
                <span class="meta-label">📅 时间</span>
                <span>{{ formatShort(item.expected_start_time) }} ~ {{ formatShort(item.expected_end_time) }}</span>
              </div>
              <div class="meta-item" v-if="item.budget">
                <span class="meta-label">💰 预算</span>
                <span class="budget">¥{{ item.budget }} 以内</span>
              </div>
            </div>
          </div>

          <div class="card-footer">
            <span class="requester">{{ item.requester_name }}</span>
            <div v-if="item.user_id !== userStore.user?.id" style="display:flex;gap:8px">
              <el-button size="small" plain @click.stop="contactRequester(item)">联系TA</el-button>
              <el-button size="small" type="warning" @click.stop="acceptRequest(item)">我能提供位置</el-button>
            </div>
            <el-tag v-else size="small" type="info">我的需求</el-tag>
          </div>
        </div>
      </div>

      <div class="pagination" v-if="total > pageSize">
        <el-pagination v-model:current-page="page" :page-size="pageSize" :total="total"
          layout="prev, pager, next" @current-change="fetchList" />
      </div>
    </div>

    <!-- 接受需求弹窗 -->
    <el-dialog v-model="acceptVisible" title="🤝 接受寄存需求" width="420px" @close="acceptItem=null">
      <el-form v-if="acceptItem" :model="acceptForm" label-width="90px">
        <el-form-item label="需求标题"><strong>{{ acceptItem.title }}</strong></el-form-item>
        <el-form-item label="需求方">{{ acceptItem.requester_name }}</el-form-item>
        <el-form-item label="你的服务">
          <el-select v-model="acceptForm.service_id" placeholder="选择你提供的寄存服务" style="width:100%">
            <el-option v-for="s in myServices" :key="s.id" :label="s.title" :value="s.id" />
          </el-select>
        </el-form-item>
        <el-form-item label="开始日期"><el-date-picker v-model="acceptForm.start_date" type="date" value-format="YYYY-MM-DD" style="width:100%" /></el-form-item>
        <el-form-item label="结束日期"><el-date-picker v-model="acceptForm.end_date" type="date" value-format="YYYY-MM-DD" style="width:100%" /></el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="acceptVisible=false">取消</el-button>
        <el-button type="primary" @click="submitAccept">确认接单</el-button>
      </template>
    </el-dialog>

    <!-- 联系方式弹窗 -->
    <el-dialog v-model="contactVisible" title="📞 联系需求方" width="380px" center>
      <div class="contact-content" v-if="contactItem">
        <div class="contact-provider">
          <p>需求方：{{ contactItem.requester_name }}</p>
          <p style="font-size:14px;color:#606266">{{ contactItem.title }}</p>
        </div>
        <div class="contact-info" v-if="contactItem.contact_info">
          <el-tag size="large" type="warning">{{ contactItem.contact_info }}</el-tag>
        </div>
        <div class="contact-info" v-else>
          <el-tag size="large" type="info">暂未填写联系方式</el-tag>
        </div>
      </div>
    </el-dialog>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { Plus } from '@element-plus/icons-vue'
import { ElMessage } from 'element-plus'
import api from '@/api'
import { useUserStore } from '@/stores/user'

const router = useRouter()
const userStore = useUserStore()
const acceptVisible = ref(false)
const acceptItem = ref(null)
const acceptForm = ref({ service_id: null, start_date: '', end_date: '' })
const myServices = ref([])

const acceptRequest = async (item) => {
  if (!userStore.isLoggedIn) return ElMessage.warning('请先登录')
  // 获取当前用户提供的寄存服务
  try {
    const res = await api.get('/storage-services', { params: { pageSize: 50 } })
    if (res.data.code === 0) {
      myServices.value = (res.data.data.list || []).filter(s => s.user_id === userStore.user?.id)
    }
  } catch (e) { /* ignore */ }
  if (myServices.value.length === 0) return ElMessage.warning('你还没有发布寄存服务，请先去发布')
  acceptItem.value = item
  acceptForm.value = {
    service_id: myServices.value[0]?.id || null,
    start_date: item.expected_start_time ? item.expected_start_time.split('T')[0] : '',
    end_date: item.expected_end_time ? item.expected_end_time.split('T')[0] : ''
  }
  acceptVisible.value = true
}

const submitAccept = async () => {
  if (!acceptForm.value.service_id || !acceptForm.value.start_date || !acceptForm.value.end_date) {
    return ElMessage.warning('请选择服务和日期')
  }
  try {
    const res = await api.post('/storage-orders', {
      storage_service_id: acceptForm.value.service_id,
      item_desc: acceptItem.value.title,
      start_date: acceptForm.value.start_date,
      end_date: acceptForm.value.end_date
    })
    if (res.data.code === 0) {
      ElMessage.success('接单成功！已创建寄存预约')
      acceptVisible.value = false
    }
  } catch (e) { ElMessage.error(e.response?.data?.message || '操作失败') }
}
const list = ref([])
const loading = ref(false)
const page = ref(1)
const pageSize = 12
const total = ref(0)
const contactVisible = ref(false)
const contactItem = ref(null)

const filters = ref({ item_type: '', campus: '', sort: 'newest' })

const iconEmoji = (t) => ({ bike: '🛵', suitcase: '🧳', book: '📚', appliance: '🔌', other: '📦' }[t] || '📦')
const typeLabel = (t) => ({ bike: '电动车', suitcase: '行李', book: '书籍', appliance: '小型电器', other: '其他' }[t] || t)

const formatShort = (d) => {
  if (!d) return ''
  const dt = new Date(d)
  return `${dt.getMonth() + 1}/${dt.getDate()}`
}

const fetchList = async () => {
  loading.value = true
  try {
    const params = { page: page.value, pageSize, sort: filters.value.sort }
    if (filters.value.item_type) params.item_type = filters.value.item_type
    if (filters.value.campus) params.campus = filters.value.campus
    const res = await api.get('/storage-requests', { params })
    if (res.data.code === 0) {
      list.value = res.data.data.list
      total.value = res.data.data.total
    }
  } catch (e) { console.error(e) }
  loading.value = false
}

const onFilterChange = () => { page.value = 1; fetchList() }

const contactRequester = (item) => {
  const userId = item.user_id
  const name = item.requester_name || '用户'
  if (userId) {
    router.push(`/messages?to=${userId}&name=${encodeURIComponent(name)}`)
  } else {
    contactItem.value = item
    contactVisible.value = true
  }
}

onMounted(fetchList)
</script>

<style scoped>
.request-page { max-width: 1000px; margin: 0 auto; }
.page-header { display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 22px; flex-wrap: wrap; gap: 14px; }
.page-header h2 { margin: 0; font-size: 22px; font-weight: 700; color: #303133; }
.header-sub { margin: 4px 0 0 0; font-size: 14px; color: #909399; line-height: 1.5; }

.filter-bar { border-radius: 12px; padding: 14px 20px; margin-bottom: 20px; box-shadow: 0 1px 4px rgba(0,0,0,0.04); }
.filter-bar.warm { background: linear-gradient(135deg, #fff9f0, #fff); }
.filter-row { margin-bottom: 10px; }
.filter-row-secondary { display: flex; gap: 10px; flex-wrap: wrap; }

.list-container { min-height: 300px; }
.empty-hint { color: #c0c4cc; font-size: 13px; display: block; margin-top: 8px; }

.request-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(310px, 1fr)); gap: 16px; }
.request-card {
  background: linear-gradient(135deg, #fffdf7, #fff8f0);
  border: 1px solid #fdebd0;
  border-radius: 14px; padding: 20px;
  transition: box-shadow 0.2s;
}
.request-card:hover { box-shadow: 0 4px 20px rgba(230,162,60,0.12); }

.card-header { display: flex; align-items: center; gap: 10px; margin-bottom: 14px; }
.card-header .card-icon { font-size: 30px; }
.card-header h4 { margin: 0; flex: 1; font-size: 15px; font-weight: 600; color: #303133; }

.desc { font-size: 13px; color: #909399; margin: 0 0 14px 0; line-height: 1.6; }

.meta-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; margin-bottom: 16px; }
.meta-item { display: flex; flex-direction: column; gap: 3px; }
.meta-label { font-size: 12px; color: #909399; }
.meta-item span:last-child { font-size: 13px; color: #303133; font-weight: 500; }
.budget { color: #e6a23c !important; font-weight: 600; }

.card-footer { display: flex; justify-content: space-between; align-items: center; padding-top: 14px; border-top: 1px solid #fdebd0; }
.requester { font-size: 13px; color: #c0c4cc; }

.pagination { display: flex; justify-content: center; margin-top: 28px; padding-bottom: 16px; }

.contact-content { text-align: center; padding: 10px 0; }
.contact-provider { margin-bottom: 14px; }
.contact-provider p { margin: 4px 0; }
.contact-info { margin-bottom: 14px; }
</style>
