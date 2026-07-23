<template>
  <div class="my-orders">
    <h2>我的订单</h2>
    <el-tabs v-model="activeTab" @tab-change="fetchOrders">
      <el-tab-pane label="我买到的" name="buy" />
      <el-tab-pane label="我卖出的" name="sell" />
      <el-tab-pane label="我预约的寄存" name="storage_rent" />
      <el-tab-pane label="我接单的寄存" name="storage_provide" />
      <el-tab-pane label="我的租赁" name="rental" />
    </el-tabs>

    <!-- 商品订单 -->
    <div v-if="activeTab === 'buy' || activeTab === 'sell'" v-loading="loading">
      <el-empty v-if="orders.length === 0 && !loading" description="暂无订单" />
      <div class="order-list">
        <el-card v-for="order in orders" :key="order.id" class="order-card" shadow="hover">
          <div class="order-header">
            <span class="order-no">订单号：{{ order.id }}</span>
            <el-tag :type="statusType(order.status)" size="small">{{ statusText(order.status) }}</el-tag>
          </div>
          <div class="order-body">
            <div class="order-item-info">
              <h4>{{ order.item_title }}</h4>
              <span class="order-price">¥{{ order.price }}</span>
            </div>
            <div class="order-meta">
              <span v-if="activeTab === 'buy'">卖家：{{ order.seller_name }}</span>
              <span v-else>买家：{{ order.buyer_name }}</span>
              <span>{{ formatTime(order.created_at) }}</span>
            </div>
          </div>
          <div class="order-actions">
            <!-- 买家：待交易时可取消 -->
            <template v-if="activeTab === 'buy' && order.status === 'pending'">
              <el-button size="small" @click="cancelOrder(order.id)">取消订单</el-button>
            </template>
            <!-- 卖家：待交易时可确认完成 -->
            <template v-if="activeTab === 'sell' && order.status === 'pending'">
              <el-button type="primary" size="small" @click="completeOrder(order.id)">确认完成</el-button>
            </template>
            <!-- 买家可私信卖家 -->
            <el-button
              v-if="activeTab === 'buy'"
              size="small"
              type="info"
              plain
              @click="$router.push(`/messages?to=${order.seller_id}&name=${order.seller_name}`)"
            >联系卖家</el-button>
            <!-- 补贴活动订单完成 → 抽奖按钮 -->
            <el-button
              v-if="activeTab === 'buy' && order.status === 'completed' && order.activity_id"
              size="small"
              type="warning"
              @click="openLottery(order)"
            >🎰 抽奖</el-button>
            <el-button
              v-if="activeTab === 'sell'"
              size="small"
              type="info"
              plain
              @click="$router.push(`/messages?to=${order.buyer_id}&name=${order.buyer_name}`)"
            >联系买家</el-button>
          </div>
        </el-card>
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
h2 { margin-bottom: 16px; }
.order-list { display: flex; flex-direction: column; gap: 12px; }
.order-card { border-radius: 8px; }
.order-header {
  display: flex; justify-content: space-between; align-items: center;
  margin-bottom: 12px;
}
.order-no { font-size: 13px; color: #999; }
.order-body { margin-bottom: 12px; }
.order-item-info {
  display: flex; justify-content: space-between; align-items: center;
}
.order-item-info h4 { margin: 0; font-size: 16px; }
.order-price { font-size: 18px; color: #f56c6c; font-weight: 600; }
.order-meta {
  display: flex; justify-content: space-between;
  font-size: 13px; color: #999; margin-top: 8px;
}
.order-actions {
  display: flex; gap: 8px; justify-content: flex-end;
  padding-top: 12px; border-top: 1px solid #f0f0f0;
}
</style>
