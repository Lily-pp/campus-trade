<template>
  <div class="my-orders">
    <h2>我的订单</h2>
    <el-tabs v-model="activeTab" @tab-change="fetchOrders">
      <el-tab-pane label="我买到的" name="buy" />
      <el-tab-pane label="我卖出的" name="sell" />
    </el-tabs>

    <div v-loading="loading">
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
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import api from '../api'
import { ElMessage, ElMessageBox } from 'element-plus'

const activeTab = ref('buy')
const orders = ref([])
const loading = ref(false)

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

const cancelOrder = async (id) => {
  try {
    await ElMessageBox.confirm('确定取消该订单？', '提示')
    const res = await api.put(`/orders/${id}/status`, { status: 'cancelled' })
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
    const res = await api.put(`/orders/${id}/status`, { status: 'completed' })
    if (res.data.code === 0) {
      ElMessage.success('交易已完成')
      fetchOrders()
    }
  } catch (e) {
    if (e !== 'cancel') ElMessage.error('操作失败')
  }
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
