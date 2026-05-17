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
                  <img v-lazy="img.url.startsWith('http') ? img.url : `http://localhost:3000${img.url}`" class="item-img" />
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
              <el-descriptions-item v-if="item.review_count" label="评分">
                <el-rate :model-value="Number(item.avg_rating || 0)" disabled show-score />
                <span style="color:#909399;font-size:12px;margin-left:4px">({{ item.review_count }}条)</span>
              </el-descriptions-item>
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
                <el-button size="large" type="warning" plain @click="reportItem">
                  举报
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

    <!-- 商品评价 -->
    <el-card v-if="item" class="reviews-card" shadow="never">
      <template #header>
        <div class="reviews-header">
          <span style="font-weight:600">商品评价</span>
          <span v-if="item.review_count" style="color:#909399;font-size:13px;margin-left:8px">共 {{ item.review_count }} 条</span>
          <el-rate v-if="item.avg_rating" :model-value="Number(item.avg_rating)" disabled show-score style="margin-left:auto" />
        </div>
      </template>

      <!-- 发表评价表单 -->
      <div v-if="canReviewInfo.canReview" class="review-form">
        <div class="review-form-title">发表评价</div>
        <el-rate v-model="reviewForm.rating" style="margin-bottom:8px" />
        <el-input
          v-model="reviewForm.content"
          type="textarea"
          :rows="3"
          placeholder="分享你的购买体验（选填）"
          maxlength="500"
          show-word-limit
        />
        <el-button type="primary" style="margin-top:10px" :loading="submittingReview" @click="submitReview">
          提交评价
        </el-button>
      </div>

      <!-- 评价列表 -->
      <div v-if="reviews.length > 0" class="review-list">
        <div v-for="review in reviews" :key="review.id" class="review-item">
          <div class="review-top">
            <el-avatar :size="32" icon="UserFilled" />
            <div class="review-meta">
              <span class="reviewer-name">{{ review.reviewer_name }}</span>
              <el-rate :model-value="review.rating" disabled size="small" />
            </div>
            <span class="review-date">{{ formatTime(review.created_at) }}</span>
            <el-button
              v-if="userStore.user && userStore.user.id === review.reviewer_id"
              text type="danger" size="small"
              @click="deleteReview(review.id)"
            >删除</el-button>
          </div>
          <div v-if="review.content" class="review-content">{{ review.content }}</div>
        </div>
      </div>

      <el-empty v-else-if="!canReviewInfo.canReview" description="暂无评价" :image-size="60" />
    </el-card>

    <!-- 相关推荐 -->
    <el-card v-if="similarItems.length > 0" class="similar-card" shadow="never">
      <template #header><span style="font-weight:600">相关推荐</span></template>
      <div class="similar-grid">
        <div
          v-for="sItem in similarItems"
          :key="sItem.id"
          class="similar-item"
          @click="router.push(`/item/${sItem.id}`)"
        >
          <div class="similar-img">
            <img v-if="sItem.cover_image" v-lazy="sItem.cover_image.startsWith('http') ? sItem.cover_image : `http://localhost:3000${sItem.cover_image}`" class="similar-img-real" />
            <div v-else class="similar-img-placeholder"><el-icon :size="24"><Picture /></el-icon></div>
          </div>
          <div class="similar-info">
            <div class="similar-title">{{ sItem.title }}</div>
            <div class="similar-price">¥{{ sItem.price }}</div>
          </div>
        </div>
      </div>
    </el-card>

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
import { useItemStore } from '@/stores/item'

const router = useRouter()
const route = useRoute()
const userStore = useUserStore()
const itemStore = useItemStore()

const item = ref(null)
const loading = ref(false)
const isFavorited = ref(false)
const favLoading = ref(false)

const reviews = ref([])
const similarItems = ref([])
const canReviewInfo = ref({ canReview: false, reason: '', orderId: null })
const reviewForm = ref({ rating: 5, content: '' })
const submittingReview = ref(false)

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
    const res = await itemStore.fetchItemDetail(route.params.id)
    if (res.code === 0) {
      item.value = res.data
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

const reportItem = async () => {
  if (!requireLogin()) return
  try {
    const { value: reason } = await ElMessageBox.prompt(
      '请输入举报原因',
      '举报商品',
      {
        confirmButtonText: '提交举报',
        cancelButtonText: '取消',
        inputPlaceholder: '请详细描述举报原因',
        inputValidator: (value) => {
          if (!value || value.trim().length < 5) {
            return '举报原因至少5个字符'
          }
          return true
        }
      }
    )
    const res = await api.post('/reports', {
      target_type: 'item',
      target_id: parseInt(route.params.id),
      reason: reason.trim()
    })
    if (res.data.code === 0) {
      ElMessage.success('举报成功，我们会尽快处理')
    } else {
      ElMessage.warning(res.data.message)
    }
  } catch (e) {
    if (e !== 'cancel') {
      ElMessage.error(e.response?.data?.message || '举报失败')
    }
  }
}

const fetchReviews = async () => {
  try {
    const res = await api.get(`/reviews/item/${route.params.id}`)
    if (res.data.code === 0) reviews.value = res.data.data
  } catch (e) { /* ignore */ }
}

const checkCanReview = async () => {
  if (!userStore.isLoggedIn) return
  try {
    const res = await api.get(`/reviews/can-review/${route.params.id}`)
    if (res.data.code === 0) canReviewInfo.value = res.data.data
  } catch (e) { /* ignore */ }
}

const submitReview = async () => {
  if (!reviewForm.value.rating) return ElMessage.warning('请选择评分')
  submittingReview.value = true
  try {
    const res = await api.post('/reviews', {
      item_id: parseInt(route.params.id),
      order_id: canReviewInfo.value.orderId,
      rating: reviewForm.value.rating,
      content: reviewForm.value.content
    })
    if (res.data.code === 0) {
      ElMessage.success('评价成功')
      canReviewInfo.value = { canReview: false, reason: 'already_reviewed', orderId: null }
      reviewForm.value = { rating: 5, content: '' }
      await fetchReviews()
      await fetchItem()
    } else {
      ElMessage.warning(res.data.message)
    }
  } catch (e) {
    ElMessage.error(e.response?.data?.message || '评价失败')
  }
  submittingReview.value = false
}

const deleteReview = async (reviewId) => {
  try {
    await ElMessageBox.confirm('确认删除这条评价？', '删除评价', {
      confirmButtonText: '删除', cancelButtonText: '取消', type: 'warning'
    })
    const res = await api.delete(`/reviews/${reviewId}`)
    if (res.data.code === 0) {
      ElMessage.success('已删除')
      await fetchReviews()
      await fetchItem()
      canReviewInfo.value = { canReview: true, orderId: canReviewInfo.value.orderId }
    }
  } catch (e) {
    if (e !== 'cancel') ElMessage.error('删除失败')
  }
}

const fetchSimilar = async () => {
  try {
    const res = await api.get(`/recommendations/similar/${route.params.id}`)
    if (res.data.code === 0) similarItems.value = res.data.data
  } catch (e) { /* ignore */ }
}

onMounted(() => {
  fetchItem()
  checkFavorite()
  recordView()
  fetchReviews()
  checkCanReview()
  fetchSimilar()
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

.reviews-card { margin-bottom: 16px; }
.reviews-header { display: flex; align-items: center; }

.review-form { padding: 12px; background: #f9f9f9; border-radius: 8px; margin-bottom: 16px; }
.review-form-title { font-weight: 500; margin-bottom: 8px; }

.review-list { display: flex; flex-direction: column; gap: 12px; }
.review-item { padding: 12px; border: 1px solid #f0f0f0; border-radius: 8px; }
.review-top { display: flex; align-items: center; gap: 10px; margin-bottom: 6px; }
.review-meta { display: flex; flex-direction: column; gap: 2px; flex: 1; }
.reviewer-name { font-size: 14px; font-weight: 500; color: #303133; }
.review-date { font-size: 12px; color: #c0c4cc; margin-left: auto; }
.review-content { font-size: 14px; color: #606266; line-height: 1.6; padding-left: 42px; }

.similar-card { margin-bottom: 16px; }
.similar-grid {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 12px;
}
.similar-item {
  border: 1px solid #f0f0f0;
  border-radius: 8px;
  overflow: hidden;
  cursor: pointer;
  transition: transform 0.2s, box-shadow 0.2s;
}
.similar-item:hover { transform: translateY(-3px); box-shadow: 0 6px 16px rgba(0,0,0,0.08); }
.similar-img { height: 120px; overflow: hidden; background: #f5f5f5; }
.similar-img-real { width: 100%; height: 100%; object-fit: cover; }
.similar-img-placeholder {
  height: 100%; display: flex; align-items: center; justify-content: center; color: #bbb;
}
.similar-info { padding: 8px 10px; }
.similar-title {
  font-size: 13px; color: #303133; font-weight: 500;
  overflow: hidden; text-overflow: ellipsis; white-space: nowrap; margin-bottom: 4px;
}
.similar-price { font-size: 14px; color: #f56c6c; font-weight: bold; }
</style>