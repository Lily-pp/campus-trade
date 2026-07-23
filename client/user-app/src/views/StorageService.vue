<template>
  <div class="storage-page">
    <!-- 页面头部 -->
    <div class="page-header">
      <div class="header-left">
        <h2>📦 寄存服务</h2>
        <p class="header-sub">浏览校园内提供的寄存空间，安全存放你的闲置物品</p>
      </div>
      <el-button type="primary" size="large" @click="router.push('/publish-storage?type=service')">
        <el-icon><Plus /></el-icon> 发布寄存服务
      </el-button>
    </div>

    <!-- 筛选栏 -->
    <div class="filter-bar">
      <div class="filter-row">
        <el-radio-group v-model="filters.storage_type" @change="onFilterChange" size="small">
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
        <el-select v-model="filters.status" placeholder="服务状态" clearable style="width:130px" @change="onFilterChange">
          <el-option label="全部状态" value="" />
          <el-option label="空余" value="available" />
          <el-option label="即将约满" value="almost_full" />
          <el-option label="已满" value="full" />
        </el-select>
        <el-select v-model="filters.sort" style="width:150px" @change="onFilterChange">
          <el-option label="推荐排序" value="newest" />
          <el-option label="价格最低" value="price_asc" />
          <el-option label="即将到期" value="ending_soon" />
        </el-select>
      </div>
    </div>

    <!-- 列表 -->
    <div v-loading="loading" class="list-container">
      <el-empty v-if="list.length === 0 && !loading" description="暂无寄存服务">
        <span class="empty-hint">附近还没有人发布寄存服务，快去发布吧</span>
      </el-empty>

      <div v-else class="service-grid">
        <div v-for="item in list" :key="item.id" class="service-card" :class="{ full: item.status === 'full' }">
          <!-- 左侧：物品类型图标 -->
          <div class="card-icon" :style="{ background: iconBg(item.storage_type) }">
            <span class="icon-emoji">{{ iconEmoji(item.storage_type) }}</span>
          </div>

          <!-- 中间：服务信息 -->
          <div class="card-body">
            <div class="card-title">
              <el-tag v-if="item.user_id && item.user_id === userStore.user?.id" type="success" size="small" effect="dark" style="margin-right:4px">我的</el-tag>
              {{ item.title }}
              <el-tag v-if="item.status === 'available'" type="success" size="small" effect="plain">空余</el-tag>
              <el-tag v-else-if="item.status === 'almost_full'" type="warning" size="small" effect="plain">即将约满</el-tag>
              <el-tag v-else type="danger" size="small" effect="plain">已满</el-tag>
            </div>

            <div class="card-meta">
              <div class="meta-item" v-if="item.campus">
                <el-icon><Location /></el-icon>{{ item.campus }}
              </div>
              <div class="meta-item" v-if="item.location">
                <el-icon><Position /></el-icon>{{ item.location }}
              </div>
              <div class="meta-item" v-if="item.start_time">
                <el-icon><Calendar /></el-icon>
                {{ formatShort(item.start_time) }} ~ {{ formatShort(item.end_time) }}
              </div>
            </div>

            <div class="card-bottom">
              <div class="bottom-left">
                <span class="price" v-if="item.price_per_month">
                  <strong>¥{{ item.price_per_month }}</strong>/月
                </span>
                <span class="capacity">
                  剩余 <strong>{{ item.remain_capacity ?? item.capacity }}</strong> / {{ item.capacity }} 个位置
                </span>
              </div>
              <div class="bottom-right">
                <span class="provider">{{ item.provider_name || item.provider_real_name }}</span>
                <el-button
                  v-if="item.user_id !== userStore.user?.id && item.status !== 'full'"
                  size="small" type="success" @click.stop="bookService(item)"
                >预约寄存</el-button>
                <el-button size="small" type="primary" plain @click.stop="contactProvider(item)"
                  :disabled="item.status === 'full'">
                  {{ item.status === 'full' ? '已满' : '联系TA' }}
                </el-button>
              </div>
            </div>
          </div>
        </div>
      </div>

      <div class="pagination" v-if="total > pageSize">
        <el-pagination v-model:current-page="page" :page-size="pageSize" :total="total"
          layout="prev, pager, next" @current-change="fetchList" />
      </div>
    </div>

    <!-- 预约弹窗 -->
    <el-dialog v-model="bookVisible" title="📋 预约寄存" width="420px" @close="bookItem=null">
      <el-form v-if="bookItem" :model="bookForm" label-width="90px">
        <el-form-item label="寄存服务"><strong>{{ bookItem.title }}</strong></el-form-item>
        <el-form-item label="提供者">{{ bookItem.provider_name || bookItem.provider_real_name }}</el-form-item>
        <el-form-item label="寄存物品"><el-input v-model="bookForm.item_desc" placeholder="如：28寸行李箱+一床被子" /></el-form-item>
        <el-form-item label="开始日期"><el-date-picker v-model="bookForm.start_date" type="date" value-format="YYYY-MM-DD" style="width:100%" /></el-form-item>
        <el-form-item label="结束日期"><el-date-picker v-model="bookForm.end_date" type="date" value-format="YYYY-MM-DD" style="width:100%" /></el-form-item>
        <el-form-item label="预估费用" v-if="bookItem.price_per_month && bookForm.start_date && bookForm.end_date">
          <span style="color:#f56c6c;font-size:18px;font-weight:700">
            ¥{{ calcStoragePrice(bookItem.price_per_month, bookForm.start_date, bookForm.end_date) }}
          </span>
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="bookVisible=false">取消</el-button>
        <el-button type="primary" @click="submitBook">确认预约</el-button>
      </template>
    </el-dialog>

    <!-- 联系方式弹窗 -->
    <el-dialog v-model="contactVisible" title="📞 联系方式" width="380px" center>
      <div class="contact-content" v-if="contactItem">
        <div class="contact-provider">
          <span>发布者：{{ contactItem.provider_name || contactItem.provider_real_name }}</span>
        </div>
        <div class="contact-info" v-if="contactItem.contact_info">
          <el-tag size="large" type="warning">{{ contactItem.contact_info }}</el-tag>
        </div>
        <div class="contact-info" v-else>
          <el-tag size="large" type="info">暂未填写联系方式</el-tag>
        </div>
        <div class="contact-tip">请主动联系寄存提供方，沟通具体寄存细节</div>
      </div>
    </el-dialog>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { ElMessage } from 'element-plus'
import { Plus, Location, Position, Calendar } from '@element-plus/icons-vue'
import api from '@/api'
import { useUserStore } from '@/stores/user'

const router = useRouter()
const userStore = useUserStore()
const list = ref([])
const loading = ref(false)
const page = ref(1)
const pageSize = 12
const total = ref(0)
const contactVisible = ref(false)
const contactItem = ref(null)

const filters = ref({ storage_type: '', campus: '', status: '', sort: 'newest' })

const iconEmoji = (t) => ({ bike: '🛵', suitcase: '🧳', book: '📚', appliance: '🔌', other: '📦' }[t] || '📦')
const iconBg = (t) => ({ bike: '#e8f5e9', suitcase: '#fff3e0', book: '#e3f2fd', appliance: '#fce4ec', other: '#f5f5f5' }[t] || '#f5f5f5')

const formatShort = (d) => {
  if (!d) return ''
  const dt = new Date(d)
  return `${dt.getMonth() + 1}/${dt.getDate()}`
}

const fetchList = async () => {
  loading.value = true
  try {
    const params = { page: page.value, pageSize, sort: filters.value.sort }
    if (filters.value.storage_type) params.storage_type = filters.value.storage_type
    if (filters.value.campus) params.campus = filters.value.campus
    if (filters.value.status) params.status = filters.value.status
    const res = await api.get('/storage-services', { params })
    if (res.data.code === 0) {
      list.value = res.data.data.list
      total.value = res.data.data.total
    }
  } catch (e) { console.error(e) }
  loading.value = false
}

const onFilterChange = () => { page.value = 1; fetchList() }

const bookVisible = ref(false)
const bookItem = ref(null)
const bookForm = ref({ item_desc: '', start_date: '', end_date: '' })

const bookService = (item) => {
  if (!userStore.isLoggedIn) return ElMessage.warning('请先登录')
  bookItem.value = item
  bookForm.value = { item_desc: '', start_date: item.start_time ? item.start_time.split(' ')[0] : '', end_date: item.end_time ? item.end_time.split(' ')[0] : '' }
  bookVisible.value = true
}

const submitBook = async () => {
  if (!bookForm.value.start_date || !bookForm.value.end_date) return ElMessage.warning('请选择寄存时间')
  try {
    const res = await api.post('/storage-orders', {
      storage_service_id: bookItem.value.id,
      item_desc: bookForm.value.item_desc,
      start_date: bookForm.value.start_date,
      end_date: bookForm.value.end_date
    })
    if (res.data.code === 0) {
      ElMessage.success('预约成功！可在我的订单中查看')
      bookVisible.value = false
    }
  } catch (e) { ElMessage.error(e.response?.data?.message || '预约失败') }
}

const calcStoragePrice = (pricePerMonth, start, end) => {
  const days = Math.ceil((new Date(end) - new Date(start)) / (1000*60*60*24))
  const months = Math.max(1, Math.ceil(days / 30))
  return (pricePerMonth * months).toFixed(0)
}

const contactProvider = (item) => {
  const userId = item.user_id
  const name = item.provider_name || item.provider_real_name || '用户'
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
.storage-page { max-width: 1000px; margin: 0 auto; }
.page-header { display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 22px; flex-wrap: wrap; gap: 14px; }
.page-header h2 { margin: 0; font-size: 22px; font-weight: 700; color: #303133; }
.header-sub { margin: 4px 0 0 0; font-size: 14px; color: #909399; line-height: 1.5; }

.filter-bar { background: #fff; border-radius: 12px; padding: 14px 20px; margin-bottom: 20px; box-shadow: 0 1px 4px rgba(0,0,0,0.04); }
.filter-row { margin-bottom: 10px; }
.filter-row-secondary { display: flex; gap: 10px; flex-wrap: wrap; }

.list-container { min-height: 300px; }
.empty-hint { color: #c0c4cc; font-size: 13px; display: block; margin-top: 8px; }

.service-grid { display: flex; flex-direction: column; gap: 14px; }
.service-card {
  display: flex; background: #fff; border-radius: 14px; overflow: hidden;
  border: 1px solid #f0f0f0; transition: box-shadow 0.2s;
}
.service-card:hover { box-shadow: 0 4px 20px rgba(0,0,0,0.08); }
.service-card.full { opacity: 0.55; }

.card-icon {
  width: 110px; flex-shrink: 0; display: flex; align-items: center; justify-content: center;
  border-right: 1px solid #f0f0f0; min-height: 100px;
}
.icon-emoji { font-size: 38px; }

.card-body { flex: 1; padding: 16px 22px; display: flex; flex-direction: column; gap: 10px; min-width: 0; }
.card-title { font-size: 15px; font-weight: 600; color: #303133; display: flex; align-items: center; gap: 8px; flex-wrap: wrap; }
.card-meta { display: flex; flex-wrap: wrap; gap: 16px; }
.meta-item { display: flex; align-items: center; gap: 5px; font-size: 13px; color: #606266; }
.card-bottom { display: flex; justify-content: space-between; align-items: center; }
.bottom-left { display: flex; align-items: center; gap: 18px; }
.price strong { color: #f56c6c; font-size: 18px; }
.capacity { font-size: 13px; color: #909399; }
.capacity strong { color: #409eff; font-weight: 600; }
.bottom-right { display: flex; align-items: center; gap: 12px; }
.provider { font-size: 13px; color: #c0c4cc; }

.pagination { display: flex; justify-content: center; margin-top: 28px; padding-bottom: 16px; }

.contact-content { text-align: center; padding: 10px 0; }
.contact-provider { margin-bottom: 14px; font-size: 15px; color: #303133; }
.contact-info { margin-bottom: 14px; }
.contact-tip { font-size: 13px; color: #909399; }
</style>
