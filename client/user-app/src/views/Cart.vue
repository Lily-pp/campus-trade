<template>
  <div class="cart-page">
    <el-card shadow="never">
      <template #header>
        <div style="display:flex;align-items:center;justify-content:space-between">
          <span style="font-size:18px;font-weight:600">
            <el-icon><ShoppingCart /></el-icon> 购物车
          </span>
          <span class="cart-count" v-if="cartItems.length">共 {{ cartItems.length }} 件商品</span>
        </div>
      </template>

      <div v-loading="loading">
        <el-empty v-if="cartItems.length === 0 && !loading" description="购物车是空的">
          <el-button type="primary" @click="router.push('/')">去逛逛</el-button>
        </el-empty>

        <div v-else>
          <!-- 全选 -->
          <div class="cart-header">
            <el-checkbox v-model="allChecked" @change="toggleAll">全选</el-checkbox>
          </div>

          <!-- 商品列表 -->
          <div class="cart-list">
            <div v-for="item in cartItems" :key="item.item_id" class="cart-item">
              <el-checkbox v-model="item.checked" @change="updateAllChecked" />
              <div class="cart-img" @click="router.push(`/item/${item.item_id}`)">
                <img v-if="item.cover_image" :src="'http://localhost:3000' + item.cover_image" alt="" />
                <el-icon v-else :size="32" color="#ccc"><Picture /></el-icon>
              </div>
              <div class="cart-info" @click="router.push(`/item/${item.item_id}`)">
                <div class="cart-title">{{ item.title }}</div>
                <div class="cart-meta">
                  <el-tag size="small" type="info">{{ item.category_name }}</el-tag>
                  <span class="cart-seller">{{ item.seller_name }}</span>
                </div>
              </div>
              <div class="cart-price">¥{{ item.price }}</div>
              <el-button text type="danger" @click="removeItem(item.item_id)">
                <el-icon><Delete /></el-icon>
              </el-button>
            </div>
          </div>

          <!-- 底部结算栏 -->
          <div class="cart-footer">
            <div class="footer-left">
              已选 <strong>{{ checkedCount }}</strong> 件，合计：
              <span class="total-price">¥{{ totalPrice }}</span>
            </div>
            <el-button type="primary" size="large" :disabled="checkedCount === 0" :loading="checkoutLoading" @click="handleCheckout">
              结算 ({{ checkedCount }})
            </el-button>
          </div>
        </div>
      </div>
    </el-card>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { ElMessage, ElMessageBox } from 'element-plus'
import { ShoppingCart, Delete, Picture } from '@element-plus/icons-vue'
import api from '@/api'

const router = useRouter()
const loading = ref(false)
const checkoutLoading = ref(false)
const cartItems = ref([])
const allChecked = ref(false)

const checkedCount = computed(() => cartItems.value.filter(i => i.checked).length)
const totalPrice = computed(() => {
  return cartItems.value
    .filter(i => i.checked)
    .reduce((sum, i) => sum + Number(i.price), 0)
    .toFixed(2)
})

const fetchCart = async () => {
  loading.value = true
  try {
    const res = await api.get('/cart')
    if (res.data.code === 0) {
      cartItems.value = (res.data.data || []).map(i => ({ ...i, checked: false }))
    }
  } catch (e) {
    console.error(e)
  }
  loading.value = false
}

const toggleAll = (val) => {
  cartItems.value.forEach(i => (i.checked = val))
}

const updateAllChecked = () => {
  allChecked.value = cartItems.value.length > 0 && cartItems.value.every(i => i.checked)
}

const removeItem = async (itemId) => {
  try {
    const res = await api.delete(`/cart/${itemId}`)
    if (res.data.code === 0) {
      cartItems.value = cartItems.value.filter(i => i.item_id !== itemId)
      ElMessage.success('已移除')
    }
  } catch (e) {
    ElMessage.error('操作失败')
  }
}

const handleCheckout = async () => {
  const items = cartItems.value.filter(i => i.checked)
  if (items.length === 0) return

  try {
    await ElMessageBox.confirm(
      `确认购买选中的 ${items.length} 件商品，合计 ¥${totalPrice.value}？`,
      '确认结算',
      { confirmButtonText: '确认购买', cancelButtonText: '取消' }
    )
  } catch { return }

  checkoutLoading.value = true
  try {
    const res = await api.post('/cart/checkout', {
      item_ids: items.map(i => i.item_id)
    })
    if (res.data.code === 0) {
      ElMessage.success(`购买成功！共创建 ${res.data.data.orders.length} 个订单`)
      fetchCart()
    } else {
      ElMessage.error(res.data.message || '结算失败')
    }
  } catch (e) {
    ElMessage.error(e.response?.data?.message || '结算失败')
  }
  checkoutLoading.value = false
}

onMounted(fetchCart)
</script>

<style scoped>
.cart-page {
  max-width: 900px;
  margin: 0 auto;
}

.cart-count {
  font-size: 14px;
  color: #909399;
}

.cart-header {
  padding: 8px 0 16px;
  border-bottom: 1px solid #f0f0f0;
}

.cart-list {
  display: flex;
  flex-direction: column;
}

.cart-item {
  display: flex;
  align-items: center;
  gap: 14px;
  padding: 16px 0;
  border-bottom: 1px solid #f5f5f5;
}

.cart-img {
  width: 80px;
  height: 80px;
  border-radius: 8px;
  overflow: hidden;
  background: #f5f5f5;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  flex-shrink: 0;
}

.cart-img img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.cart-info {
  flex: 1;
  min-width: 0;
  cursor: pointer;
}

.cart-title {
  font-size: 15px;
  font-weight: 500;
  color: #303133;
  margin-bottom: 8px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.cart-meta {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 12px;
  color: #909399;
}

.cart-price {
  font-size: 20px;
  font-weight: bold;
  color: #f56c6c;
  flex-shrink: 0;
  width: 100px;
  text-align: right;
}

.cart-footer {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 20px 0 0;
  margin-top: 8px;
  border-top: 2px solid #f0f0f0;
}

.footer-left {
  font-size: 14px;
  color: #606266;
}

.total-price {
  font-size: 24px;
  font-weight: bold;
  color: #f56c6c;
  margin-left: 4px;
}
</style>
