<template>
  <div class="detail-page" v-loading="loading">
    <el-button text :icon="ArrowLeft" @click="router.back()" style="margin-bottom:12px">返回</el-button>

    <template v-if="item">
      <el-card class="detail-card" shadow="never">
        <div class="detail-layout">
          <!-- 左侧图片 -->
          <div class="detail-image">
            <template v-if="item.images && item.images.length > 0">
              <el-carousel :interval="4000" height="380px" indicator-position="outside">
                <el-carousel-item v-for="img in item.images" :key="img.id">
                  <img :src="img.url.startsWith('http') ? img.url : `http://localhost:3000${img.url}`" class="item-img" />
                </el-carousel-item>
              </el-carousel>
            </template>
            <div v-else class="img-placeholder">
              <el-icon :size="48"><Picture /></el-icon>
              <span>暂无图片</span>
            </div>
          </div>

          <!-- 右侧信息 -->
          <div class="detail-info">
            <h1>{{ item.title }}</h1>
            <div class="price">¥{{ item.price }}</div>

            <el-descriptions :column="1" border class="info-table">
              <el-descriptions-item label="分类">{{ item.category_name }}</el-descriptions-item>
              <el-descriptions-item label="状态">
                <el-tag :type="getStatusType(item)">{{ getStatusLabel(item) }}</el-tag>
              </el-descriptions-item>
              <!-- 库存仅卖家本人可见 -->
              <el-descriptions-item v-if="isOwner" label="剩余库存">
                {{ item.quantity ?? 1 }} 件
              </el-descriptions-item>
              <el-descriptions-item label="浏览量">{{ item.views_count || 0 }}</el-descriptions-item>
              <el-descriptions-item label="收藏数">{{ item.favorites_count || 0 }}</el-descriptions-item>
              <el-descriptions-item label="发布时间">{{ formatTime(item.created_at) }}</el-descriptions-item>
            </el-descriptions>

            <div class="desc-section" v-if="item.description">
              <h3>商品描述</h3>
              <p>{{ item.description }}</p>
            </div>

            <!-- 操作按钮区 -->
            <div class="action-bar" v-if="item.status === 'on_sale'">
              <el-button
                size="large"
                :type="isFavorited ? 'warning' : 'default'"
                :icon="isFavorited ? StarFilled : Star"
                @click="toggleFavorite"
                :loading="favLoading"
              >
                {{ isFavorited ? '已收藏' : '收藏' }}
              </el-button>
              <!-- 非自己发布的商品才显示购买与购物车 -->
              <template v-if="!isOwner">
                <el-button size="large" type="primary" icon="ShoppingCart" @click="addToCart">
                  加入购物车
                </el-button>
                <el-button size="large" type="danger" @click="buyNow">
                  立即购买
                </el-button>
                <el-button size="large" type="info" plain @click="messageSeller">
                  联系卖家
                </el-button>
              </template>
            </div>
            <div class="action-bar" v-else>
              <el-tag :type="getStatusType(item)" size="large">{{ getStatusLabel(item) }}</el-tag>
            </div>
          </div>
        </div>
      </el-card>

      <!-- 卖家信息 -->
      <el-card class="seller-card" shadow="never">
        <template #header><span style="font-weight:600">卖家信息</span></template>
        <div class="seller-info">
          <el-avatar :size="48" icon="UserFilled" />
          <div class="seller-detail">
            <div class="seller-name">{{ item.seller_real_name || item.seller_name }}</div>
            <div class="seller-campus" v-if="item.seller_campus">
              <el-icon><Location /></el-icon> {{ item.seller_campus }}
            </div>
          </div>
        </div>
      </el-card>
    </template>

    <el-empty v-if="!item && !loading" description="商品不存在" />
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { ElMessage, ElMessageBox } from 'element-plus'
import { ArrowLeft, Star, StarFilled, Picture, Location } from '@element-plus/icons-vue'
import api from '@/api'
import { useUserStore } from '@/stores/user'

const router = useRouter()
const route = useRoute()
const userStore = useUserStore()

const item = ref(null)
const loading = ref(false)
const isFavorited = ref(false)
const favLoading = ref(false)

const statusMap = { on_sale: '在售', sold: '已售', off: '已下架', pending: '审核中', rejected: '审核未通过' }
const statusType = { on_sale: 'success', sold: 'info', off: 'warning', pending: '', rejected: 'danger' }

const getStatusLabel = (currentItem) => statusMap[currentItem?.status] || currentItem?.status || ''

const getStatusType = (currentItem) => statusType[currentItem?.status] || 'info'

const isOwner = computed(() => {
  return userStore.user && item.value && item.value.seller_id === userStore.user.id
})

const formatTime = (t) => t ? new Date(t).toLocaleDateString('zh-CN') : ''

const fetchItem = async () => {
  loading.value = true
  try {
    const res = await api.get(`/items/${route.params.id}`)
    if (res.data.code === 0) {
      item.value = res.data.data
    }
  } catch (e) {
    console.error(e)
  }
  loading.value = false
}

const checkFavorite = async () => {
  if (!userStore.isLoggedIn) return
  try {
    const res = await api.get(`/favorites/check/${route.params.id}`)
    if (res.data.code === 0) {
      isFavorited.value = res.data.data.favorited
    }
  } catch (e) { /* ignore */ }
}

const recordView = async () => {
  try {
    await api.post('/views', { item_id: parseInt(route.params.id) })
  } catch (e) { /* ignore */ }
}

const requireLogin = () => {
  if (!userStore.isLoggedIn) {
    ElMessage.warning('请先登录')
    router.push({ name: 'login', query: { redirect: route.fullPath } })
    return false
  }
  return true
}

const toggleFavorite = async () => {
  if (!requireLogin()) return
  favLoading.value = true
  try {
    if (isFavorited.value) {
      await api.delete(`/favorites/${route.params.id}`)
      isFavorited.value = false
      if (item.value) item.value.favorites_count = Math.max((item.value.favorites_count || 1) - 1, 0)
      ElMessage.success('已取消收藏')
    } else {
      await api.post('/favorites', { item_id: parseInt(route.params.id) })
      isFavorited.value = true
      if (item.value) item.value.favorites_count = (item.value.favorites_count || 0) + 1
      ElMessage.success('收藏成功')
    }
  } catch (e) {
    ElMessage.error('操作失败')
  }
  favLoading.value = false
}

const addToCart = async () => {
  if (!requireLogin()) return
  try {
    const res = await api.post('/cart', { item_id: parseInt(route.params.id) })
    if (res.data.code === 0) {
      ElMessage.success('已加入购物车')
    } else {
      ElMessage.warning(res.data.message)
    }
  } catch (e) {
    ElMessage.error(e.response?.data?.message || '加入购物车失败')
  }
}

const buyNow = async () => {
  if (!requireLogin()) return
  try {
    await ElMessageBox.confirm(
      `确认以 ¥${item.value.price} 购买「${item.value.title}」？`,
      '确认购买',
      { confirmButtonText: '确认下单', cancelButtonText: '取消', type: 'info' }
    )
    const res = await api.post('/orders/buy', { item_id: parseInt(route.params.id) })
    if (res.data.code === 0) {
      ElMessage.success('下单成功！')
      router.push('/orders')
    } else {
      ElMessage.warning(res.data.message)
    }
  } catch (e) {
    if (e !== 'cancel') {
      ElMessage.error(e.response?.data?.message || '下单失败')
    }
  }
}

const messageSeller = () => {
  if (!requireLogin()) return
  router.push(`/messages?to=${item.value.seller_id}&name=${item.value.seller_name}`)
}

onMounted(() => {
  fetchItem()
  checkFavorite()
  recordView()
})
</script>

<style scoped>
.detail-page { max-width: 960px; margin: 0 auto; }
.detail-card { margin-bottom: 16px; }
.detail-layout { display: flex; gap: 28px; }

.detail-image { width: 380px; flex-shrink: 0; }
.item-img {
  width: 100%; height: 380px; object-fit: cover; border-radius: 8px;
}
.img-placeholder {
  height: 380px; background: linear-gradient(135deg, #e8eaf6, #f3e5f5);
  border-radius: 10px; display: flex; flex-direction: column;
  align-items: center; justify-content: center; color: #bbb; gap: 8px;
}

.detail-info { flex: 1; min-width: 0; }
.detail-info h1 { font-size: 22px; margin: 0 0 8px; color: #303133; }
.price { font-size: 32px; color: #f56c6c; font-weight: bold; margin-bottom: 16px; }
.info-table { margin-bottom: 16px; }
.desc-section h3 { font-size: 14px; color: #909399; margin: 0 0 8px; }
.desc-section p { color: #303133; line-height: 1.7; margin: 0; }

.action-bar {
  margin-top: 20px;
  display: flex; gap: 10px; flex-wrap: wrap;
}

.seller-card { margin-bottom: 16px; }
.seller-info { display: flex; align-items: center; gap: 14px; }
.seller-name { font-size: 16px; font-weight: 500; color: #303133; }
.seller-campus {
  font-size: 13px; color: #909399;
  display: flex; align-items: center; gap: 3px; margin-top: 4px;
}
</style>
