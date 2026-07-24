<template>
  <div class="detail-page" v-loading="loading">
    <!-- 返回按钮 -->
    <button class="back-btn" @click="router.back()">
      <span>←</span> 返回
    </button>

    <template v-if="item">
      <!-- ===== 主卡片 ===== -->
      <div class="detail-main-card">
        <div class="detail-layout">
          <!-- 左侧图片 -->
          <div class="detail-image">
            <template v-if="item.images && item.images.length > 0">
              <el-carousel :interval="4000" height="400px" indicator-position="outside">
                <el-carousel-item v-for="img in item.images" :key="img.id">
                  <img v-lazy="img.url.startsWith('http') ? img.url : `http://localhost:3000${img.url}`" class="item-img" />
                </el-carousel-item>
              </el-carousel>
            </template>
            <div v-else class="img-placeholder">
              <span class="img-placeholder-icon">📸</span>
              <span>暂无图片</span>
            </div>
          </div>

          <!-- 右侧信息 -->
          <div class="detail-info">
            <!-- 标题栏 -->
            <div class="detail-title-bar">
              <span class="detail-badge" :class="item.status">{{ getStatusLabel(item) }}</span>
              <h1>{{ item.title }}</h1>
            </div>

            <!-- 价格 -->
            <div class="detail-price-row">
              <span class="detail-price">¥{{ item.price }}</span>
              <div class="detail-stats">
                <span>👁️ {{ item.views_count || 0 }}</span>
                <span>❤️ {{ item.favorites_count || 0 }}</span>
                <span v-if="item.review_count">⭐ {{ Number(item.avg_rating || 0).toFixed(1) }} ({{ item.review_count }}条)</span>
              </div>
            </div>

            <!-- 基本信息 -->
            <div class="detail-info-grid">
              <div class="info-item">
                <span class="info-label">分类</span>
                <span class="info-value">{{ item.category_name }}</span>
              </div>
              <div class="info-item" v-if="isOwner">
                <span class="info-label">库存</span>
                <span class="info-value">{{ item.quantity ?? 1 }} 件</span>
              </div>
              <div class="info-item">
                <span class="info-label">发布时间</span>
                <span class="info-value">{{ formatTime(item.created_at) }}</span>
              </div>
              <div class="info-item" v-if="item.expected_address">
                <span class="info-label">交易地点</span>
                <span class="info-value location-value" @click="openMapDialog">
                  📍 {{ item.expected_address }}
                </span>
              </div>
            </div>

            <!-- 描述 -->
            <div class="detail-desc" v-if="item.description">
              <h3>📝 商品描述</h3>
              <p>{{ item.description }}</p>
            </div>

            <!-- 标签 -->
            <div class="detail-tags" v-if="tags.length > 0">
              <span class="tags-label">🏷️ 标签：</span>
              <span
                v-for="tag in tags"
                :key="tag"
                class="tag-chip"
                @click="goToTagPage(tag)"
              >#{{ tag }}</span>
            </div>

            <!-- 操作按钮 -->
            <div class="detail-actions" v-if="item.status === 'on_sale'">
              <button
                class="action-btn favorite-btn"
                :class="{ active: isFavorited }"
                @click="toggleFavorite"
                :disabled="favLoading"
              >
                {{ isFavorited ? '❤️ 已收藏' : '🤍 收藏' }}
              </button>
              <button v-if="isOwner" class="action-btn edit-btn" @click="goToEdit">
                ✏️ 编辑
              </button>
              <template v-if="!isOwner">
                <button class="action-btn cart-btn" @click="addToCart">
                  🛒 加入购物车
                </button>
                <button class="action-btn buy-btn" @click="buyNow">
                  ⚡ 立即购买
                </button>
                <button class="action-btn msg-btn" @click="messageSeller">
                  💬 联系卖家
                </button>
                <button class="action-btn report-btn" @click="reportItem">
                  ⚠️ 举报
                </button>
              </template>
            </div>
            <div class="detail-actions" v-else>
              <el-tag :type="getStatusType(item)" size="large" class="status-tag">{{ getStatusLabel(item) }}</el-tag>
            </div>
          </div>
        </div>
      </div>

      <!-- ===== 卖家信息 ===== -->
      <div class="seller-card">
        <div class="seller-card-header">👤 卖家信息</div>
        <div class="seller-card-body">
          <div class="seller-avatar-lg">
            {{ (item.seller_real_name || item.seller_name)?.[0] || '?' }}
          </div>
          <div class="seller-detail">
            <div class="seller-name-lg">{{ item.seller_real_name || item.seller_name }}</div>
            <div class="seller-campus" v-if="item.seller_campus">📍 {{ item.seller_campus }}</div>
          </div>
        </div>
      </div>

      <!-- ===== 评价区 ===== -->
      <div class="reviews-section">
        <div class="reviews-header">
          <h3>⭐ 商品评价</h3>
          <span v-if="item.review_count">共 {{ item.review_count }} 条</span>
        </div>

        <!-- 发表评价 -->
        <div v-if="canReviewInfo.canReview" class="review-form-card">
          <p class="review-form-title">分享你的购买体验 ✍️</p>
          <el-rate v-model="reviewForm.rating" style="margin-bottom:10px" />
          <el-input
            v-model="reviewForm.content"
            type="textarea"
            :rows="3"
            placeholder="写下你的评价（选填）"
            maxlength="500"
            show-word-limit
          />
          <button class="submit-review-btn" :loading="submittingReview" @click="submitReview">
            {{ submittingReview ? '提交中...' : '📝 提交评价' }}
          </button>
        </div>

        <!-- 评价列表 -->
        <div v-if="reviews.length > 0" class="review-list">
          <div v-for="review in reviews" :key="review.id" class="review-item">
            <div class="review-top">
              <div class="reviewer-avatar">{{ review.reviewer_name?.[0] || '?' }}</div>
              <div class="review-meta">
                <span class="reviewer-name">{{ review.reviewer_name }}</span>
                <el-rate :model-value="review.rating" disabled size="small" />
              </div>
              <span class="review-date">{{ formatTime(review.created_at) }}</span>
              <button
                v-if="userStore.user && userStore.user.id === review.reviewer_id"
                class="delete-review-btn"
                @click="deleteReview(review.id)"
              >🗑️</button>
            </div>
            <div v-if="review.content" class="review-content">{{ review.content }}</div>
          </div>
        </div>

        <el-empty v-else-if="!canReviewInfo.canReview" description="暂无评价" :image-size="60" />
      </div>

      <!-- ===== 相关推荐 ===== -->
      <div v-if="similarItems.length > 0" class="similar-section">
        <div class="section-header">
          <h3>🔗 相关推荐</h3>
        </div>
        <div class="similar-grid">
          <div
            v-for="sItem in similarItems"
            :key="sItem.id"
            class="similar-item"
            @click="router.push(`/item/${sItem.id}`)"
          >
            <div class="similar-img">
              <img v-if="sItem.cover_image" v-lazy="sItem.cover_image.startsWith('http') ? sItem.cover_image : `http://localhost:3000${sItem.cover_image}`" class="similar-img-real" />
              <div v-else class="similar-img-placeholder">📦</div>
            </div>
            <div class="similar-info">
              <div class="similar-title">{{ sItem.title }}</div>
              <div class="similar-price">¥{{ sItem.price }}</div>
            </div>
          </div>
        </div>
      </div>
    </template>

    <el-empty v-if="!item && !loading" description="商品不存在或已下架" :image-size="80" />

    <!-- 地图路径弹窗 -->
    <el-dialog
      v-model="mapDialogVisible"
      title="📍 交易位置与路径"
      width="800px"
      destroy-on-close
      @closed="() => { if (map) { map.destroy(); map = null } }"
    >
      <div ref="mapContainer" style="width: 100%; height: 480px; border-radius: 12px;"></div>
      <div style="margin-top: 12px; font-size: 13px; color: #8892A0;">
        <div v-if="item?.expected_address">
          <strong>期望交易地址：</strong>{{ item.expected_address }}
        </div>
        <div style="margin-top: 4px;">🔵 当前位置 &nbsp; 🔴 期望交易位置</div>
      </div>
    </el-dialog>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, nextTick } from 'vue'
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
const tags = ref([])

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

      // ==================== 新增：获取商品标签 ====================
      try {
        // 临时方案：调用后端获取该商品的标签列表
        // 注意：这个接口我们后面会补充，如果目前报 404 可以先注释掉
        const tagRes = await api.get(`/items/${route.params.id}/tags`)
        if (tagRes.data.code === 0) {
          tags.value = tagRes.data.data || []
        }
      } catch (tagErr) {
        console.log('获取标签失败（接口可能还未添加）', tagErr)
        tags.value = []
      }
      // ==================== 标签获取结束 ====================
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

const goToTagPage = (tagName) => {
  router.push({
    path: '/',
    query: {
      keyword: tagName
    }
  })
}

const goToEdit = () => {
    router.push({
        path: '/publish',
        query: { id: route.params.id }
    })
}

const fetchSimilar = async () => {
  try {
    const res = await api.get(`/recommendations/similar/${route.params.id}`)
    if (res.data.code === 0) similarItems.value = res.data.data
  } catch (e) { /* ignore */ }
}


// ==================== 地图路径相关 ====================
const mapDialogVisible = ref(false)
const mapContainer = ref(null)
let map = null

const openMapDialog = () => {
  if (!item.value?.expected_longitude || !item.value?.expected_latitude) {
    ElMessage.warning('该商品暂无位置信息')
    return
  }
  mapDialogVisible.value = true
  nextTick(() => {
    initRouteMap()
  })
}

const initRouteMap = () => {
  if (!window.AMap) {
    ElMessage.error('地图加载失败')
    return
  }

  if (map) {
    map.destroy()
    map = null
  }

  const targetLng = parseFloat(item.value.expected_longitude)
  const targetLat = parseFloat(item.value.expected_latitude)

  map = new AMap.Map(mapContainer.value, {
    zoom: 14,
    viewMode: '2D'
  })

  // 期望位置标记（红色）
  const targetMarker = new AMap.Marker({
    position: [targetLng, targetLat],
    map,
    title: '期望交易位置',
    icon: 'https://webapi.amap.com/theme/v1.3/markers/n/mark_r.png'
  })

  // 获取当前位置
  const geolocation = new AMap.Geolocation({
    enableHighAccuracy: true,
    timeout: 10000
  })

  geolocation.getCurrentPosition((status, result) => {
    if (status === 'complete') {
      const currentLng = result.position.getLng()
      const currentLat = result.position.getLat()

      // 当前位置标记（蓝色）
      new AMap.Marker({
        position: [currentLng, currentLat],
        map,
        title: '当前位置',
        icon: 'https://webapi.amap.com/theme/v1.3/markers/n/mark_b.png'
      })

      // 路径规划（步行）
      AMap.plugin(['AMap.Walking'], () => {
        const walking = new AMap.Walking({
          map: map,
          hideMarkers: true
        })

        walking.search(
          [currentLng, currentLat],
          [targetLng, targetLat],
          (status, result) => {
            if (status === 'complete') {
              console.log('路径规划成功', result)
              // 自动调整视野显示整条路径
              map.setFitView()
            } else {
              console.warn('路径规划失败', result)
              // 规划失败时至少显示两个点
              map.setFitView([targetMarker])
              ElMessage.warning('暂时无法规划路径，已显示两个位置')
            }
          }
        )
      })
    } else {
      // 定位失败，只显示目标点
      map.setCenter([targetLng, targetLat])
      map.setZoom(15)
      ElMessage.warning('无法获取当前位置，仅显示期望交易位置')
    }
  })
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
.detail-page {
  max-width: 960px;
  margin: 0 auto;
}

/* ===== 返回按钮 ===== */
.back-btn {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 8px 18px;
  background: #fff;
  border: 1px solid rgba(240, 230, 224, 0.4);
  border-radius: 12px;
  font-size: 13px;
  color: #8892A0;
  cursor: pointer;
  transition: all 0.3s ease;
  margin-bottom: 16px;
  font-weight: 500;
}
.back-btn:hover {
  color: #FF7E67;
  border-color: #FF7E67;
  transform: translateX(-3px);
}

/* ===== 主卡片 ===== */
.detail-main-card {
  background: #fff;
  border-radius: 20px;
  padding: 28px;
  margin-bottom: 20px;
  box-shadow: 0 4px 24px rgba(0,0,0,0.04);
  border: 1px solid rgba(240, 230, 224, 0.3);
}
.detail-layout {
  display: flex;
  gap: 32px;
}

/* ===== 图片 ===== */
.detail-image {
  width: 400px;
  flex-shrink: 0;
}
.item-img {
  width: 100%;
  height: 400px;
  object-fit: cover;
  border-radius: 14px;
}
.detail-image :deep(.el-carousel__item) {
  border-radius: 14px;
  overflow: hidden;
}
.detail-image :deep(.el-carousel__indicator--outside) {
  padding: 0 4px;
}
.detail-image :deep(.el-carousel__button) {
  width: 24px;
  height: 4px;
  border-radius: 2px;
  background: #ddd;
}
.detail-image :deep(.el-carousel__indicator.is-active .el-carousel__button) {
  background: #FF7E67;
}
.img-placeholder {
  height: 400px;
  background: linear-gradient(135deg, #FFF8F5, #FFE8E0);
  border-radius: 14px;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  color: #B2BEC3;
  gap: 10px;
}
.img-placeholder-icon { font-size: 48px; }

/* ===== 信息区域 ===== */
.detail-info {
  flex: 1;
  min-width: 0;
}
.detail-title-bar {
  margin-bottom: 12px;
}
.detail-badge {
  display: inline-block;
  padding: 3px 12px;
  border-radius: 8px;
  font-size: 12px;
  font-weight: 600;
  margin-bottom: 8px;
}
.detail-badge.on_sale { background: rgba(0, 184, 148, 0.1); color: #00B894; }
.detail-badge.sold { background: rgba(178, 190, 195, 0.15); color: #8892A0; }
.detail-badge.off { background: rgba(255, 183, 77, 0.12); color: #E8963E; }
.detail-badge.pending { background: rgba(108, 92, 231, 0.1); color: #6C5CE7; }
.detail-title-bar h1 {
  font-size: 24px;
  font-weight: 700;
  color: #2D3436;
  margin: 0;
  line-height: 1.3;
}

/* ===== 价格和统计 ===== */
.detail-price-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 16px 0;
  border-bottom: 1px solid #F5F0EC;
  margin-bottom: 16px;
}
.detail-price {
  font-size: 36px;
  font-weight: 800;
  background: linear-gradient(135deg, #FF7E67, #FD79A8);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
}
.detail-stats {
  display: flex;
  gap: 14px;
  font-size: 13px;
  color: #8892A0;
}

/* ===== 信息网格 ===== */
.detail-info-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 10px;
  margin-bottom: 16px;
}
.info-item {
  display: flex;
  flex-direction: column;
  gap: 4px;
  padding: 10px 14px;
  background: #FFF8F5;
  border-radius: 10px;
}
.info-label {
  font-size: 11px;
  color: #B2BEC3;
  font-weight: 500;
  text-transform: uppercase;
  letter-spacing: 0.5px;
}
.info-value {
  font-size: 14px;
  color: #2D3436;
  font-weight: 500;
}
.location-value {
  color: #FF7E67;
  cursor: pointer;
  text-decoration: underline;
  text-decoration-style: dotted;
}

/* ===== 描述 ===== */
.detail-desc {
  margin-bottom: 16px;
  padding: 16px;
  background: #FFF8F5;
  border-radius: 12px;
}
.detail-desc h3 {
  font-size: 13px;
  color: #8892A0;
  margin: 0 0 8px;
}
.detail-desc p {
  font-size: 14px;
  color: #2D3436;
  line-height: 1.8;
  margin: 0;
  white-space: pre-wrap;
}

/* ===== 标签 ===== */
.detail-tags {
  display: flex;
  align-items: center;
  gap: 6px;
  flex-wrap: wrap;
  margin-bottom: 20px;
}
.tags-label {
  font-size: 13px;
  color: #8892A0;
}
.tag-chip {
  display: inline-block;
  padding: 4px 12px;
  background: rgba(255, 126, 103, 0.06);
  color: #FF7E67;
  border-radius: 20px;
  font-size: 12px;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.2s;
}
.tag-chip:hover {
  background: rgba(255, 126, 103, 0.15);
  transform: translateY(-1px);
}

/* ===== 操作按钮 ===== */
.detail-actions {
  display: flex;
  gap: 10px;
  flex-wrap: wrap;
  margin-top: 8px;
}
.action-btn {
  padding: 10px 24px;
  border-radius: 14px;
  border: none;
  font-size: 14px;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.3s cubic-bezier(0.25, 0.46, 0.45, 0.94);
  display: inline-flex;
  align-items: center;
  gap: 6px;
}
.action-btn:hover {
  transform: translateY(-2px);
}
.action-btn:active {
  transform: translateY(0);
}
.favorite-btn {
  background: #FFF0EB;
  color: #FF7E67;
  border: 1px solid rgba(255, 126, 103, 0.2);
}
.favorite-btn:hover, .favorite-btn.active {
  background: linear-gradient(135deg, #FF7E67, #FD79A8);
  color: #fff;
  box-shadow: 0 4px 15px rgba(255, 126, 103, 0.3);
}
.edit-btn {
  background: #F0E8FF;
  color: #6C5CE7;
}
.edit-btn:hover {
  background: #6C5CE7;
  color: #fff;
  box-shadow: 0 4px 15px rgba(108, 92, 231, 0.3);
}
.cart-btn {
  background: #E8FFF5;
  color: #00B894;
}
.cart-btn:hover {
  background: #00B894;
  color: #fff;
  box-shadow: 0 4px 15px rgba(0, 184, 148, 0.3);
}
.buy-btn {
  background: linear-gradient(135deg, #FF7E67, #FD79A8);
  color: #fff;
  box-shadow: 0 4px 15px rgba(255, 126, 103, 0.25);
}
.buy-btn:hover {
  box-shadow: 0 6px 25px rgba(255, 126, 103, 0.4);
}
.msg-btn {
  background: #FFF8E5;
  color: #FDCB6E;
  border: 1px solid rgba(253, 203, 110, 0.3);
}
.msg-btn:hover {
  background: #FDCB6E;
  color: #fff;
  box-shadow: 0 4px 15px rgba(253, 203, 110, 0.3);
}
.report-btn {
  background: #FFF0F0;
  color: #FF6B6B;
  border: 1px solid rgba(255, 107, 107, 0.2);
}
.report-btn:hover {
  background: #FF6B6B;
  color: #fff;
  box-shadow: 0 4px 15px rgba(255, 107, 107, 0.3);
}
.status-tag {
  border-radius: 12px !important;
  padding: 8px 20px !important;
  font-size: 14px !important;
}

/* ===== 卖家信息 ===== */
.seller-card {
  background: #fff;
  border-radius: 16px;
  padding: 20px 24px;
  margin-bottom: 20px;
  box-shadow: 0 4px 24px rgba(0,0,0,0.04);
  border: 1px solid rgba(240, 230, 224, 0.3);
}
.seller-card-header {
  font-size: 15px;
  font-weight: 700;
  color: #2D3436;
  margin-bottom: 16px;
}
.seller-card-body {
  display: flex;
  align-items: center;
  gap: 16px;
}
.seller-avatar-lg {
  width: 52px;
  height: 52px;
  border-radius: 50%;
  background: linear-gradient(135deg, #A29BFE, #6C5CE7);
  color: #fff;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 20px;
  font-weight: 700;
  flex-shrink: 0;
  box-shadow: 0 4px 12px rgba(108, 92, 231, 0.2);
}
.seller-name-lg {
  font-size: 16px;
  font-weight: 600;
  color: #2D3436;
}
.seller-campus {
  font-size: 13px;
  color: #8892A0;
  margin-top: 4px;
}

/* ===== 评价区 ===== */
.reviews-section {
  background: #fff;
  border-radius: 16px;
  padding: 24px;
  margin-bottom: 20px;
  box-shadow: 0 4px 24px rgba(0,0,0,0.04);
  border: 1px solid rgba(240, 230, 224, 0.3);
}
.reviews-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 20px;
}
.reviews-header h3 {
  font-size: 16px;
  font-weight: 700;
  color: #2D3436;
  margin: 0;
}
.reviews-header span {
  font-size: 13px;
  color: #8892A0;
}

/* 评价表单 */
.review-form-card {
  padding: 18px;
  background: #FFF8F5;
  border-radius: 14px;
  margin-bottom: 20px;
  border: 1px solid rgba(255, 126, 103, 0.06);
}
.review-form-title {
  font-size: 14px;
  font-weight: 600;
  color: #2D3436;
  margin: 0 0 12px;
}
.submit-review-btn {
  margin-top: 12px;
  padding: 8px 24px;
  background: linear-gradient(135deg, #FF7E67, #FD79A8);
  color: #fff;
  border: none;
  border-radius: 12px;
  font-size: 14px;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.3s ease;
}
.submit-review-btn:hover {
  transform: translateY(-2px);
  box-shadow: 0 4px 15px rgba(255, 126, 103, 0.3);
}

/* 评价列表 */
.review-list {
  display: flex;
  flex-direction: column;
  gap: 14px;
}
.review-item {
  padding: 16px;
  border: 1px solid #F5F0EC;
  border-radius: 14px;
  transition: all 0.2s;
}
.review-item:hover {
  border-color: rgba(255, 126, 103, 0.15);
}
.review-top {
  display: flex;
  align-items: center;
  gap: 12px;
  margin-bottom: 8px;
}
.reviewer-avatar {
  width: 36px;
  height: 36px;
  border-radius: 50%;
  background: linear-gradient(135deg, #A29BFE, #6C5CE7);
  color: #fff;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 14px;
  font-weight: 700;
  flex-shrink: 0;
}
.review-meta {
  display: flex;
  flex-direction: column;
  gap: 2px;
  flex: 1;
}
.reviewer-name {
  font-size: 14px;
  font-weight: 600;
  color: #2D3436;
}
.review-date {
  font-size: 12px;
  color: #B2BEC3;
}
.delete-review-btn {
  background: none;
  border: none;
  font-size: 16px;
  cursor: pointer;
  padding: 4px;
  border-radius: 6px;
  transition: all 0.2s;
  opacity: 0.5;
}
.delete-review-btn:hover {
  opacity: 1;
  background: rgba(255, 107, 107, 0.1);
}
.review-content {
  font-size: 14px;
  color: #636E72;
  line-height: 1.7;
  padding-left: 48px;
}

/* ===== 相关推荐 ===== */
.similar-section {
  margin-bottom: 20px;
}
.section-header h3 {
  font-size: 16px;
  font-weight: 700;
  color: #2D3436;
  margin: 0 0 16px;
}
.similar-grid {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 14px;
}
.similar-item {
  background: #fff;
  border: 1px solid rgba(240, 230, 224, 0.4);
  border-radius: 14px;
  overflow: hidden;
  cursor: pointer;
  transition: all 0.3s ease;
  box-shadow: 0 2px 8px rgba(0,0,0,0.03);
}
.similar-item:hover {
  transform: translateY(-4px);
  box-shadow: 0 8px 24px rgba(255, 126, 103, 0.1);
  border-color: transparent;
}
.similar-img {
  height: 130px;
  overflow: hidden;
  background: #FFF8F5;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 32px;
}
.similar-img-real {
  width: 100%;
  height: 100%;
  object-fit: cover;
  transition: transform 0.4s ease;
}
.similar-item:hover .similar-img-real {
  transform: scale(1.08);
}
.similar-img-placeholder {
  font-size: 32px;
}
.similar-info {
  padding: 10px 12px;
}
.similar-title {
  font-size: 13px;
  color: #2D3436;
  font-weight: 600;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  margin-bottom: 4px;
}
.similar-price {
  font-size: 15px;
  color: #FF7E67;
  font-weight: 700;
}

/* ===== 响应式 ===== */
@media (max-width: 768px) {
  .detail-layout { flex-direction: column; }
  .detail-image { width: 100%; }
  .detail-main-card { padding: 20px; }
  .item-img, .img-placeholder { height: 280px; }
  .detail-info-grid { grid-template-columns: 1fr; }
  .detail-actions { flex-direction: column; }
  .action-btn { justify-content: center; }
  .similar-grid { grid-template-columns: repeat(2, 1fr); }
}
</style>