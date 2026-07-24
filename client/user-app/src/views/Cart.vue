<template>
  <div class="cart-page">
    <div class="cart-container">
      <div class="cart-header">
        <h2>🛒 购物车</h2>
        <span v-if="cartItems.length" class="cart-count">{{ cartItems.length }} 件商品</span>
      </div>

      <div v-loading="loading">
        <el-empty v-if="cartItems.length === 0 && !loading" description="购物车空空的 ~ 去校园里淘点好物吧！">
          <button class="empty-shop-btn" @click="router.push('/')">🎯 去逛逛</button>
        </el-empty>

        <div v-else class="cart-content">
          <!-- 全选 -->
          <div class="cart-select-all">
            <el-checkbox v-model="allChecked" @change="toggleAll">全选</el-checkbox>
            <span class="cart-hint">勾选要结算的商品</span>
          </div>

          <!-- 商品列表 -->
          <div class="cart-list">
            <div v-for="item in cartItems" :key="item.item_id" class="cart-item">
              <el-checkbox v-model="item.checked" @change="updateAllChecked" class="item-checkbox" />
              <div class="cart-img" @click="router.push(`/item/${item.item_id}`)">
                <img v-if="item.cover_image" v-lazy="'http://localhost:3000' + item.cover_image" alt="" />
                <span v-else class="cart-img-placeholder">📸</span>
              </div>
              <div class="cart-info" @click="router.push(`/item/${item.item_id}`)">
                <div class="cart-title">{{ item.title }}</div>
                <div class="cart-meta">
                  <span class="cart-category">{{ item.category_name }}</span>
                  <span class="cart-seller">{{ item.seller_name }}</span>
                </div>
              </div>
              <div class="cart-price">¥{{ item.price }}</div>
              <button class="cart-remove" @click="removeItem(item.item_id)">
                🗑️
              </button>
            </div>
          </div>

          <!-- 结算栏 -->
          <div class="cart-checkout">
            <div class="checkout-info">
              已选 <strong>{{ checkedCount }}</strong> 件，合计：
              <span class="checkout-total">¥{{ totalPrice }}</span>
            </div>
            <button
              class="checkout-btn"
              :disabled="checkedCount === 0"
              @click="handleCheckout"
            >
              {{ checkoutLoading ? '结算中...' : `⚡ 结算 (${checkedCount})` }}
            </button>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { ElMessage, ElMessageBox } from 'element-plus'
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
      ElMessage.success('已移除 🗑️')
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
      { confirmButtonText: '✅ 确认购买', cancelButtonText: '❌ 取消' }
    )
  } catch { return }

  checkoutLoading.value = true
  try {
    const res = await api.post('/cart/checkout', {
      item_ids: items.map(i => i.item_id)
    })
    if (res.data.code === 0) {
      ElMessage.success(`🎉 购买成功！共创建 ${res.data.data.orders.length} 个订单`)
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
.cart-container {
  background: #fff;
  border-radius: 20px;
  padding: 28px;
  box-shadow: 0 4px 24px rgba(0,0,0,0.04);
  border: 1px solid rgba(240, 230, 224, 0.3);
}
.cart-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 20px;
  padding-bottom: 16px;
  border-bottom: 1px solid #F5F0EC;
}
.cart-header h2 {
  font-size: 20px;
  font-weight: 700;
  color: #2D3436;
  margin: 0;
}
.cart-count {
  font-size: 14px;
  color: #8892A0;
  background: #FFF8F5;
  padding: 4px 14px;
  border-radius: 20px;
}

/* ===== 全选 ===== */
.cart-select-all {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 8px 4px 14px;
  border-bottom: 1px solid #F5F0EC;
  margin-bottom: 4px;
}
.cart-hint {
  font-size: 12px;
  color: #B2BEC3;
}

/* ===== 商品列表 ===== */
.cart-list {
  display: flex;
  flex-direction: column;
}
.cart-item {
  display: flex;
  align-items: center;
  gap: 16px;
  padding: 16px 0;
  border-bottom: 1px solid #F8F4F0;
  transition: all 0.2s;
}
.cart-item:hover {
  background: #FFFAF8;
  margin: 0 -12px;
  padding: 16px 12px;
  border-radius: 12px;
}
.item-checkbox {
  flex-shrink: 0;
}
.cart-img {
  width: 80px;
  height: 80px;
  border-radius: 12px;
  overflow: hidden;
  background: #FFF8F5;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  flex-shrink: 0;
  font-size: 28px;
}
.cart-img img {
  width: 100%;
  height: 100%;
  object-fit: cover;
  transition: transform 0.3s;
}
.cart-img:hover img {
  transform: scale(1.06);
}
.cart-img-placeholder {
  font-size: 28px;
}
.cart-info {
  flex: 1;
  min-width: 0;
  cursor: pointer;
}
.cart-title {
  font-size: 14px;
  font-weight: 600;
  color: #2D3436;
  margin-bottom: 6px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.cart-meta {
  display: flex;
  align-items: center;
  gap: 8px;
}
.cart-category {
  display: inline-block;
  padding: 2px 10px;
  background: rgba(255, 126, 103, 0.06);
  color: #FF7E67;
  border-radius: 6px;
  font-size: 11px;
  font-weight: 600;
}
.cart-seller {
  font-size: 12px;
  color: #8892A0;
}
.cart-price {
  font-size: 18px;
  font-weight: 700;
  color: #FF7E67;
  white-space: nowrap;
  min-width: 80px;
  text-align: right;
}
.cart-remove {
  background: none;
  border: none;
  font-size: 18px;
  cursor: pointer;
  padding: 8px;
  border-radius: 8px;
  transition: all 0.2s;
  opacity: 0.4;
}
.cart-remove:hover {
  opacity: 1;
  background: rgba(255, 107, 107, 0.08);
}

/* ===== 结算栏 ===== */
.cart-checkout {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding-top: 20px;
  margin-top: 8px;
  flex-wrap: wrap;
  gap: 12px;
}
.checkout-info {
  font-size: 14px;
  color: #636E72;
}
.checkout-total {
  font-size: 24px;
  font-weight: 800;
  background: linear-gradient(135deg, #FF7E67, #FD79A8);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
  margin-left: 4px;
}
.checkout-btn {
  padding: 12px 36px;
  background: linear-gradient(135deg, #FF7E67, #FD79A8);
  color: #fff;
  border: none;
  border-radius: 14px;
  font-size: 16px;
  font-weight: 700;
  cursor: pointer;
  transition: all 0.3s ease;
  box-shadow: 0 6px 20px rgba(255, 126, 103, 0.25);
}
.checkout-btn:hover:not(:disabled) {
  transform: translateY(-2px);
  box-shadow: 0 8px 30px rgba(255, 126, 103, 0.35);
}
.checkout-btn:disabled {
  opacity: 0.4;
  cursor: not-allowed;
}

.empty-shop-btn {
  padding: 12px 32px;
  background: linear-gradient(135deg, #FF7E67, #FD79A8);
  color: #fff;
  border: none;
  border-radius: 14px;
  font-size: 15px;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.3s ease;
}
.empty-shop-btn:hover {
  transform: translateY(-2px);
  box-shadow: 0 6px 20px rgba(255, 126, 103, 0.3);
}
</style>
