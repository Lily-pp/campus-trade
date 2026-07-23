<template>
  <div class="rental-page">
    <div class="page-header">
      <h2>🔁 校园转租服务</h2>
      <p class="header-sub">相机、无人机、电动车、游戏机等短期租赁，方便又省钱</p>
    </div>

    <div class="filter-bar">
      <el-radio-group v-model="categoryFilter" @change="fetchItems" size="default">
        <el-radio-button value="">全部</el-radio-button>
        <el-radio-button value="camera">📷 相机</el-radio-button>
        <el-radio-button value="drone">🚁 无人机</el-radio-button>
        <el-radio-button value="bike">🛵 电动车</el-radio-button>
        <el-radio-button value="console">🎮 游戏机</el-radio-button>
        <el-radio-button value="projector">📽️ 投影仪</el-radio-button>
        <el-radio-button value="racket">🏸 球拍</el-radio-button>
        <el-radio-button value="other">📦 其他</el-radio-button>
      </el-radio-group>
      <el-button type="primary" @click="router.push('/publish-rental')">
        <el-icon><Plus /></el-icon> 发布转租
      </el-button>
    </div>

    <div v-loading="loading">
      <el-empty v-if="items.length === 0 && !loading" description="暂无转租物品" />
      <div class="rental-grid">
        <div v-for="item in items" :key="item.id" class="rental-card" @click="showDetail(item)">
          <div class="card-icon">{{ catEmoji(item.category) }}</div>
          <div class="card-body">
            <div class="card-top">
              <h4>
                <el-tag v-if="item.user_id && item.user_id === userStore.user?.id" type="success" size="small" effect="dark" style="margin-right:4px">我的</el-tag>
                {{ item.title }}
              </h4>
              <el-tag size="small">{{ catLabel(item.category) }}</el-tag>
            </div>
            <div class="card-mid" v-if="item.description">{{ item.description }}</div>
            <div class="card-bottom">
              <span class="price">¥{{ item.rental_price }}<small>/天</small></span>
              <span v-if="item.deposit" class="deposit">押金 ¥{{ item.deposit }}</span>
              <span class="location" v-if="item.campus">{{ item.campus }}</span>
              <div v-if="item.user_id !== userStore.user?.id" style="display:flex;gap:6px;margin-left:auto">
                <el-button size="small" plain @click.stop="contactOwner(item)">联系TA</el-button>
                <el-button size="small" type="success" @click.stop="openRentalOrder(item)">下单租赁</el-button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- 下单租赁弹窗 -->
    <el-dialog v-model="orderVisible" title="📋 下单租赁" width="420px" @close="orderItem=null">
      <el-form v-if="orderItem" :model="orderForm" label-width="90px">
        <el-form-item label="物品"><strong>{{ orderItem.title }}</strong></el-form-item>
        <el-form-item label="日租">¥{{ orderItem.rental_price }}/天</el-form-item>
        <el-form-item label="押金" v-if="orderItem.deposit">¥{{ orderItem.deposit }}</el-form-item>
        <el-form-item label="开始日期"><el-date-picker v-model="orderForm.start_date" type="date" value-format="YYYY-MM-DD" style="width:100%" /></el-form-item>
        <el-form-item label="结束日期"><el-date-picker v-model="orderForm.end_date" type="date" value-format="YYYY-MM-DD" style="width:100%" /></el-form-item>
        <el-form-item label="预估费用" v-if="orderForm.start_date && orderForm.end_date">
          <span style="color:#f56c6c;font-size:18px;font-weight:700">¥{{ calcRentalPrice() }}</span>
          <span style="font-size:12px;color:#909399">（{{ calcRentalDays() }}天 × ¥{{ orderItem.rental_price }}）</span>
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="orderVisible=false">取消</el-button>
        <el-button type="primary" @click="submitRentalOrder">确认下单</el-button>
      </template>
    </el-dialog>

    <!-- 详情弹窗 -->
    <el-dialog v-model="dialogVisible" :title="detail?.title" width="520px" @close="detail=null">
      <div v-if="detail" class="detail-content">
        <div class="detail-meta">
          <el-tag size="default" type="primary">{{ catLabel(detail.category) }}</el-tag>
          <el-tag v-if="detail.campus" size="default" type="info">{{ detail.campus }}</el-tag>
        </div>
        <p class="detail-desc" v-if="detail.description">{{ detail.description }}</p>
        <div class="detail-grid">
          <div class="detail-item">
            <span class="dl">日租价格</span>
            <span class="dv price">¥{{ detail.rental_price }}/天</span>
          </div>
          <div class="detail-item" v-if="detail.deposit">
            <span class="dl">押金</span>
            <span class="dv">¥{{ detail.deposit }}（退还）</span>
          </div>
          <div class="detail-item" v-if="detail.min_days">
            <span class="dl">最短租期</span>
            <span class="dv">{{ detail.min_days }} 天</span>
          </div>
          <div class="detail-item" v-if="detail.location">
            <span class="dl">取还位置</span>
            <span class="dv">{{ detail.location }}</span>
          </div>
          <div class="detail-item">
            <span class="dl">发布者</span>
            <span class="dv">{{ detail.owner_name || detail.owner_real_name }}</span>
          </div>
          <div class="detail-item" v-if="detail.contact_info">
            <span class="dl">联系方式</span>
            <span class="dv" style="color:#e6a23c">{{ detail.contact_info }}</span>
          </div>
        </div>
        <div v-if="detail.min_days" class="detail-tip">
          💡 最短租 {{ detail.min_days }} 天，按下单天数计算总价 = 日租 × 天数
        </div>
      </div>
      <template #footer>
        <el-button @click="dialogVisible = false">关闭</el-button>
        <el-button
          v-if="detail && detail.user_id !== userStore.user?.id"
          type="primary"
          @click="contactOwner(detail)"
        >
          <el-icon><ChatDotRound /></el-icon> 联系出租方
        </el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup>
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { ElMessage } from 'element-plus'
import { Plus, ChatDotRound } from '@element-plus/icons-vue'
import { useUserStore } from '@/stores/user'
import api from '@/api'

const router = useRouter()
const userStore = useUserStore()
const categoryFilter = ref('')
const items = ref([])
const loading = ref(false)
const dialogVisible = ref(false)
const detail = ref(null)
const orderVisible = ref(false)
const orderItem = ref(null)
const orderForm = ref({ start_date: '', end_date: '' })

const calcRentalDays = () => {
  if (!orderForm.value.start_date || !orderForm.value.end_date) return 0
  return Math.ceil((new Date(orderForm.value.end_date) - new Date(orderForm.value.start_date)) / (1000*60*60*24))
}
const calcRentalPrice = () => {
  if (!orderItem.value) return 0
  return (orderItem.value.rental_price * calcRentalDays()).toFixed(2)
}

const openRentalOrder = (item) => {
  if (!userStore.isLoggedIn) return ElMessage.warning('请先登录')
  orderItem.value = item
  orderForm.value = { start_date: '', end_date: '' }
  orderVisible.value = true
}

const submitRentalOrder = async () => {
  if (!orderForm.value.start_date || !orderForm.value.end_date) return ElMessage.warning('请选择租赁日期')
  try {
    const res = await api.post('/rental-items/orders', {
      rental_item_id: orderItem.value.id,
      start_date: orderForm.value.start_date,
      end_date: orderForm.value.end_date
    })
    if (res.data.code === 0) {
      ElMessage.success(`下单成功！共${res.data.data.days}天，¥${res.data.data.total_price}`)
      orderVisible.value = false
    }
  } catch (e) { ElMessage.error(e.response?.data?.message || '下单失败') }
}

const catEmoji = (c) => ({ camera: '📷', drone: '🚁', bike: '🛵', console: '🎮', projector: '📽️', racket: '🏸', other: '📦' }[c] || '📦')
const catLabel = (c) => ({ camera: '相机', drone: '无人机', bike: '电动车', console: '游戏机', projector: '投影仪', racket: '球拍', other: '其他' }[c] || c)

const fetchItems = async () => {
  loading.value = true
  try {
    const params = {}
    if (categoryFilter.value) params.category = categoryFilter.value
    const res = await api.get('/rental-items', { params })
    if (res.data.code === 0) items.value = res.data.data.list || res.data.data
  } catch (e) { console.error(e) }
  loading.value = false
}

const showDetail = async (item) => {
  try {
    const res = await api.get(`/rental-items/${item.id}`)
    if (res.data.code === 0) {
      detail.value = res.data.data
      dialogVisible.value = true
    }
  } catch {
    detail.value = item
    dialogVisible.value = true
  }
}

const contactOwner = (item) => {
  // 支持从卡片直接调用 或 从详情弹窗调用
  const target = item || detail.value
  if (!target) return
  const userId = target.user_id
  const name = target.owner_name || target.owner_real_name || '用户'
  dialogVisible.value = false
  if (userId) {
    router.push(`/messages?to=${userId}&name=${encodeURIComponent(name)}`)
  }
}

fetchItems()
</script>

<style scoped>
.rental-page { max-width: 1000px; margin: 0 auto; }
.page-header { margin-bottom: 22px; }
.page-header h2 { margin: 0; font-size: 22px; font-weight: 700; color: #303133; }
.header-sub { margin: 6px 0 0 0; font-size: 14px; color: #909399; line-height: 1.5; }

.filter-bar { display: flex; align-items: center; justify-content: space-between; margin-bottom: 20px; gap: 12px; flex-wrap: wrap; background: #fff; padding: 14px 20px; border-radius: 12px; box-shadow: 0 1px 4px rgba(0,0,0,0.04); }

.rental-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(290px, 1fr)); gap: 16px; }
.rental-card {
  display: flex; gap: 16px;
  background: #fff; border-radius: 14px; padding: 18px;
  border: 1px solid #f0f0f0; cursor: pointer;
  transition: box-shadow 0.2s, transform 0.2s;
}
.rental-card:hover { box-shadow: 0 6px 20px rgba(0,0,0,0.1); transform: translateY(-2px); }
.card-icon { font-size: 38px; flex-shrink: 0; width: 54px; text-align: center; line-height: 1; }
.card-body { flex: 1; min-width: 0; }
.card-top { display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 8px; gap: 8px; }
.card-top h4 { margin: 0; font-size: 15px; font-weight: 600; color: #303133; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.card-mid { font-size: 13px; color: #909399; margin-bottom: 10px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; line-height: 1.5; }
.card-bottom { display: flex; gap: 12px; align-items: center; flex-wrap: wrap; }
.price { color: #f56c6c; font-weight: 700; font-size: 18px; }
.price small { font-size: 12px; font-weight: 400; }
.deposit { font-size: 12px; color: #909399; }
.location { font-size: 12px; color: #c0c4cc; margin-left: auto; }

.detail-content { padding: 4px 0; }
.detail-meta { display: flex; gap: 10px; margin-bottom: 14px; }
.detail-desc { font-size: 14px; color: #606266; line-height: 1.7; margin: 0 0 18px 0; }
.detail-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 14px; margin-bottom: 14px; }
.detail-item { display: flex; flex-direction: column; gap: 4px; }
.dl { font-size: 12px; color: #909399; }
.dv { font-size: 15px; color: #303133; font-weight: 500; }
.dv.price { color: #f56c6c; }
.detail-tip { font-size: 13px; color: #e6a23c; background: #fef0f0; padding: 12px 16px; border-radius: 10px; }
</style>
