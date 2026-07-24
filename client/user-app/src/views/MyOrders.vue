<template>
  <div class="my-orders">
    <h2>📋 我的订单</h2>
    <el-tabs v-model="activeTab" @tab-change="fetchOrders">
      <el-tab-pane label="🛒 我买到的" name="buy" />
      <el-tab-pane label="💰 我卖出的" name="sell" />
      <el-tab-pane label="📦 我预约的寄存" name="storage_rent" />
      <el-tab-pane label="📦 我接单的寄存" name="storage_provide" />
      <el-tab-pane label="🔄 我的租赁" name="rental" />
    </el-tabs>

    <!-- 商品订单 -->
    <div v-if="activeTab === 'buy' || activeTab === 'sell'" v-loading="loading">
      <el-empty v-if="orders.length === 0 && !loading" description="暂无订单 ~" />
      <div class="order-list">
        <div v-for="order in orders" :key="order.id" class="order-card">
          <div class="order-header">
            <span class="order-no">#{{ order.id }}</span>
            <span class="order-status" :class="order.status">{{ statusText(order.status) }}</span>
          </div>
          <div class="order-body">
            <div class="order-item-info">
              <h4>{{ order.item_title }}</h4>
              <span class="order-price">¥{{ order.price }}</span>
            </div>
            <div class="order-meta">
              <span v-if="activeTab === 'buy'">👤 卖家：{{ order.seller_name }}</span>
              <span v-else>👤 买家：{{ order.buyer_name }}</span>
              <span>🕐 {{ formatTime(order.created_at) }}</span>
            </div>
          </div>
          <div class="order-actions">
            <template v-if="activeTab === 'buy' && order.status === 'pending'">
              <button class="order-action-btn cancel" @click="cancelOrder(order.id)">取消订单</button>
            </template>
            <template v-if="activeTab === 'sell' && order.status === 'pending'">
              <button class="order-action-btn primary" @click="completeOrder(order.id)">确认完成</button>
            </template>
            <button
              v-if="activeTab === 'buy'"
              class="order-action-btn outline"
              @click="$router.push(`/messages?to=${order.seller_id}&name=${order.seller_name}`)"
            >💬 联系卖家</button>
            <button
              v-if="activeTab === 'buy' && order.status === 'completed' && order.activity_id"
              class="order-action-btn lottery"
              @click="openLottery(order)"
            >🎰 抽奖</button>
            <button
              v-if="activeTab === 'sell'"
              class="order-action-btn outline"
              @click="$router.push(`/messages?to=${order.buyer_id}&name=${order.buyer_name}`)"
            >💬 联系买家</button>
          </div>
        </div>
      </div>
    </div>

    <!-- 寄存预约订单 -->
    <div v-if="activeTab === 'storage_rent' || activeTab === 'storage_provide'" v-loading="storageLoading">
      <el-empty v-if="filteredStorageOrders.length === 0 && !storageLoading" :description="activeTab === 'storage_rent' ? '暂无预约寄存' : '暂无接单记录'" />
      <div class="order-list">
        <el-card v-for="so in filteredStorageOrders" :key="so.id" class="order-card" shadow="hover">
          <div class="order-header">
            <span class="order-no">预约单号：{{ so.id }}</span>
            <el-tag :type="rentalStatusType(so.status)" size="small">{{ rentalStatusText(so.status) }}</el-tag>
          </div>
          <div class="order-body">
            <div class="order-item-info">
              <h4>{{ so.service_title }}</h4>
              <span class="order-price" v-if="so.total_price">¥{{ so.total_price }}</span>
            </div>
            <div class="order-meta">
              <span>{{ activeTab === 'storage_rent' ? '提供者' : '预约人' }}：{{ activeTab === 'storage_rent' ? so.provider_name : so.renter_name }}</span>
              <span>{{ so.start_date }} ~ {{ so.end_date }}</span>
              <span v-if="so.item_desc">{{ so.item_desc }}</span>
            </div>
          </div>
        </el-card>
      </div>
    </div>

    <!-- 租赁订单 -->
    <div v-if="activeTab === 'rental'" v-loading="rentalLoading">
      <el-empty v-if="rentalOrders.length === 0 && !rentalLoading" description="暂无租赁订单" />
      <div class="order-list">
        <el-card v-for="ro in rentalOrders" :key="ro.id" class="order-card" shadow="hover">
          <div class="order-header">
            <span class="order-no">租赁单号：{{ ro.id }}</span>
            <el-tag :type="rentalStatusType(ro.status)" size="small">{{ rentalStatusText(ro.status) }}</el-tag>
          </div>
          <div class="order-body">
            <div class="order-item-info">
              <h4>{{ ro.title || '转租物品' }}</h4>
              <span class="order-price">¥{{ ro.total_price }}</span>
            </div>
            <div class="order-meta">
              <span>{{ ro.renter_id === userStore.user?.id ? '出租方' : '租用方' }}：{{ ro.owner_name || ro.renter_name }}</span>
              <span>{{ formatTime(ro.start_date) }} ~ {{ formatTime(ro.end_date) }}</span>
            </div>
          </div>
        </el-card>
      </div>
    </div>

    <LotteryModal v-model="lotteryVisible" :order-id="lotteryOrderId" @done="onLotteryDone" />
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import api from '../api'
import { ElMessage, ElMessageBox } from 'element-plus'
import { useUserStore } from '@/stores/user'
import LotteryModal from '../components/LotteryModal.vue'

const userStore = useUserStore()

const activeTab = ref('buy')
const orders = ref([])
const rentalOrders = ref([])
const storageOrders = ref([])
const loading = ref(false)
const rentalLoading = ref(false)
const storageLoading = ref(false)

const filteredStorageOrders = computed(() => {
  if (activeTab.value === 'storage_rent') {
    return storageOrders.value.filter(so => so.user_id === userStore.user?.id)
  }
  if (activeTab.value === 'storage_provide') {
    return storageOrders.value.filter(so => so.provider_id === userStore.user?.id)
  }
  return storageOrders.value
})

const statusMap = {
  pending: '待交易',
  completed: '已完成',
  cancelled: '已取消'
}
const statusTypeMap = {
  pending: 'warning',
  completed: 'success',
  cancelled: 'info'
}
const statusText = (s) => statusMap[s] || s
const statusType = (s) => statusTypeMap[s] || 'info'

const fetchOrders = async () => {
  if (activeTab.value === 'storage_rent' || activeTab.value === 'storage_provide') {
    storageLoading.value = true
    try {
      const res = await api.get('/storage-orders/my')
      if (res.data.code === 0) storageOrders.value = res.data.data
      else storageOrders.value = []
    } catch (e) { console.error(e); storageOrders.value = [] }
    storageLoading.value = false
    return
  }
  if (activeTab.value === 'rental') {
    rentalLoading.value = true
    try {
      const res = await api.get('/rental-items/orders/my')
      if (res.data.code === 0) rentalOrders.value = res.data.data
      else rentalOrders.value = []
    } catch (e) { console.error(e); rentalOrders.value = [] }
    rentalLoading.value = false
    return
  }
  loading.value = true
  try {
    const url = activeTab.value === 'buy' ? '/orders/my' : '/orders/sold'
    const res = await api.get(url)
    if (res.data.code === 0) {
      orders.value = res.data.data
    }
  } catch (e) {
    console.error(e)
  } finally {
    loading.value = false
  }
}

const rentalStatusText = (s) => ({ pending: '待确认', confirmed: '已确认', active: '租赁中', completed: '已完成', cancelled: '已取消' }[s] || s)
const rentalStatusType = (s) => ({ pending: 'warning', confirmed: 'primary', active: 'success', completed: 'info', cancelled: 'danger' }[s] || 'info')

const cancelOrder = async (id) => {
  try {
    await ElMessageBox.confirm('确定取消该订单？', '提示')
    const res = await api.put(`/orders/${id}/cancel`)
    if (res.data.code === 0) {
      ElMessage.success('订单已取消')
      fetchOrders()
    }
  } catch (e) {
    if (e !== 'cancel') ElMessage.error('操作失败')
  }
}

const completeOrder = async (id) => {
  try {
    await ElMessageBox.confirm('确认交易完成？', '提示')
    const res = await api.put(`/orders/${id}/complete`)
    if (res.data.code === 0) {
      ElMessage.success('交易已完成')
      fetchOrders()
    }
  } catch (e) {
    if (e !== 'cancel') ElMessage.error('操作失败')
  }
}

const lotteryVisible = ref(false)
const lotteryOrderId = ref(null)

const openLottery = (order) => {
  lotteryOrderId.value = order.id
  lotteryVisible.value = true
}

const onLotteryDone = () => {
  ElMessage.success('代金券已发放到您的账户')
}

const formatTime = (t) => {
  if (!t) return ''
  return new Date(t).toLocaleString('zh-CN')
}

onMounted(() => fetchOrders())
</script>

<style scoped>
.my-orders { max-width: 800px; margin: 0 auto; }
h2 {
  font-size: 22px;
  font-weight: 700;
  color: #2D3436;
  margin: 0 0 20px;
}
.order-list { display: flex; flex-direction: column; gap: 14px; }
.order-card {
  background: #fff;
  border: 1px solid rgba(240, 230, 224, 0.4);
  border-radius: 16px;
  padding: 20px 24px;
  transition: all 0.3s ease;
  box-shadow: 0 2px 12px rgba(0,0,0,0.03);
}
.order-card:hover {
  border-color: transparent;
  box-shadow: 0 6px 24px rgba(255, 126, 103, 0.08);
}
.order-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 14px;
}
.order-no {
  font-size: 13px;
  color: #B2BEC3;
  font-weight: 500;
  font-family: monospace;
}
.order-status {
  display: inline-block;
  padding: 3px 12px;
  border-radius: 8px;
  font-size: 12px;
  font-weight: 600;
}
.order-status.pending { background: rgba(255, 183, 77, 0.12); color: #E8963E; }
.order-status.completed { background: rgba(0, 184, 148, 0.1); color: #00B894; }
.order-status.cancelled { background: rgba(178, 190, 195, 0.15); color: #8892A0; }
.order-body { margin-bottom: 14px; }
.order-item-info {
  display: flex;
  justify-content: space-between;
  align-items: center;
}
.order-item-info h4 {
  margin: 0;
  font-size: 16px;
  font-weight: 600;
  color: #2D3436;
}
.order-price {
  font-size: 20px;
  color: #FF7E67;
  font-weight: 700;
}
.order-meta {
  display: flex;
  justify-content: space-between;
  font-size: 13px;
  color: #8892A0;
  margin-top: 8px;
  flex-wrap: wrap;
  gap: 4px;
}
.order-actions {
  display: flex;
  gap: 8px;
  justify-content: flex-end;
  flex-wrap: wrap;
  padding-top: 14px;
  border-top: 1px solid #F5F0EC;
}
.order-action-btn {
  padding: 7px 18px;
  border: none;
  border-radius: 10px;
  font-size: 13px;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.25s ease;
}
.order-action-btn:hover {
  transform: translateY(-1px);
}
.order-action-btn.primary {
  background: linear-gradient(135deg, #FF7E67, #FD79A8);
  color: #fff;
  box-shadow: 0 4px 12px rgba(255, 126, 103, 0.2);
}
.order-action-btn.primary:hover {
  box-shadow: 0 6px 20px rgba(255, 126, 103, 0.35);
}
.order-action-btn.outline {
  background: rgba(255, 126, 103, 0.06);
  color: #FF7E67;
  border: 1px solid rgba(255, 126, 103, 0.15);
}
.order-action-btn.outline:hover {
  background: rgba(255, 126, 103, 0.12);
}
.order-action-btn.cancel {
  background: rgba(255, 107, 107, 0.06);
  color: #FF6B6B;
}
.order-action-btn.cancel:hover {
  background: rgba(255, 107, 107, 0.12);
}
.order-action-btn.lottery {
  background: linear-gradient(135deg, #FDCB6E, #FFB74D);
  color: #fff;
  box-shadow: 0 4px 12px rgba(253, 203, 110, 0.3);
}
.order-action-btn.lottery:hover {
  box-shadow: 0 6px 20px rgba(253, 203, 110, 0.4);
}
</style>
