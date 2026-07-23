<template>
  <div class="activity-detail-page" v-loading="loading">
    <!-- 活动头部 -->
    <div class="activity-header" v-if="activity">
      <div class="banner-wrap">
        <img
          v-if="activity.banner_url"
          :src="activity.banner_url.startsWith('http') ? activity.banner_url : `http://localhost:3000${activity.banner_url}`"
          class="banner-img"
        />
        <div v-else class="banner-placeholder">
          <el-icon :size="48"><Picture /></el-icon>
        </div>
      </div>
      <div class="activity-info">
        <h1 class="activity-name">{{ activity.name }}</h1>
        <p class="activity-desc" v-if="activity.description">{{ activity.description }}</p>
        <div class="activity-meta">
          <el-tag v-if="activity.subsidy_enabled" type="warning" size="default" effect="dark">🎓 官方补贴</el-tag>
          <el-tag :type="activityTypeTag(activity.type)" size="default">{{ activity.name }}</el-tag>
          <span class="activity-time">
            <el-icon><Clock /></el-icon>
            {{ formatDate(activity.start_time) }} ~ {{ formatDate(activity.end_time) }}
          </span>
          <span class="activity-count">
            共 <strong>{{ activity.item_count || total }}</strong> 件商品
          </span>
        </div>
        <!-- 毕业季倒计时 -->
        <div v-if="activity.type === 'graduation_sale'" class="countdown-bar">
          <el-icon><Timer /></el-icon>
          距离毕业季结束还有 <strong>{{ countdownText }}</strong>
        </div>
        <!-- 补贴说明 -->
        <div v-if="activity.subsidy_enabled" class="subsidy-banner">
          <p>{{ activity.tagline || '官方补贴活动，成交即可抽取代金券！' }}</p>
        </div>
      </div>
    </div>

    <!-- 排序栏 -->
    <div class="sort-bar">
      <el-radio-group v-model="sort" @change="onSortChange" size="default">
        <el-radio-button value="newest">最新发布</el-radio-button>
        <el-radio-button value="price_asc">价格最低</el-radio-button>
        <el-radio-button value="price_desc">价格最高</el-radio-button>
        <el-radio-button value="hot">最热门</el-radio-button>
      </el-radio-group>
    </div>

    <!-- 商品网格 -->
    <div class="item-grid" v-loading="itemsLoading">
      <el-empty v-if="items.length === 0 && !itemsLoading" description="该活动暂无商品" />
      <div
        v-for="item in items"
        :key="item.id"
        class="item-card"
        @click="router.push(`/item/${item.id}`)"
      >
        <div class="card-img">
          <img v-if="item.cover_image" v-lazy="item.cover_image.startsWith('http') ? item.cover_image : `http://localhost:3000${item.cover_image}`" class="card-img-real" />
          <div v-else class="card-img-placeholder">
            <el-icon :size="32"><Picture /></el-icon>
          </div>
          <el-tag v-if="item.seller_user_id && item.seller_user_id === userStore.user?.id" type="success" size="small" effect="dark" class="my-tag">我的</el-tag>
          <span class="card-price">¥{{ item.display_price || item.price }}</span>
        </div>
        <div class="card-body">
          <div class="card-title">{{ item.title }}</div>
          <div class="card-meta">
            <el-tag size="small" type="info">{{ item.category_name }}</el-tag>
          </div>
          <div class="card-footer">
            <span class="seller">
              <el-icon><User /></el-icon>
              {{ item.seller_name }}
              <template v-if="item.seller_campus"> · {{ item.seller_campus }}</template>
            </span>
            <span class="stats">
              <el-icon><View /></el-icon>{{ item.views_count || 0 }}
              <el-icon style="margin-left:6px"><Star /></el-icon>{{ item.favorites_count || 0 }}
            </span>
          </div>
        </div>
      </div>
    </div>

    <!-- 分页 -->
    <div class="pagination" v-if="total > pageSize">
      <el-pagination
        v-model:current-page="page"
        :page-size="pageSize"
        :total="total"
        layout="prev, pager, next"
        @current-change="fetchItems"
      />
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, onUnmounted } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { Picture, Clock, Timer } from '@element-plus/icons-vue'
import api from '@/api'
import { useUserStore } from '@/stores/user'

const router = useRouter()
const userStore = useUserStore()
const route = useRoute()

const activity = ref(null)
const items = ref([])
const loading = ref(false)
const itemsLoading = ref(false)
const page = ref(1)
const pageSize = 12
const total = ref(0)
const sort = ref('newest')

const countdownText = ref('')
let countdownTimer = null

const updateCountdown = () => {
  if (!activity.value || activity.value.type !== 'graduation_sale') return
  const end = new Date(activity.value.end_time)
  const now = new Date()
  const diff = end - now
  if (diff <= 0) {
    countdownText.value = '已结束'
    return
  }
  const days = Math.floor(diff / (1000 * 60 * 60 * 24))
  const hours = Math.floor((diff % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60))
  countdownText.value = `${days} 天 ${hours} 小时`
}

const activityTypeTag = (type) => {
  const map = {
    graduation_sale: 'warning',
    freshman_market: 'success',
    exam_materials: 'primary',
    holiday_storage: 'info'
  }
  return map[type] || 'info'
}

const formatDate = (dateStr) => {
  if (!dateStr) return ''
  const d = new Date(dateStr)
  return `${d.getMonth() + 1}/${d.getDate()}`
}

const fetchActivity = async () => {
  loading.value = true
  try {
    const res = await api.get(`/activities/${route.params.id}`)
    if (res.data.code === 0) {
      activity.value = res.data.data
      updateCountdown()
      if (activity.value.type === 'graduation_sale') {
        countdownTimer = setInterval(updateCountdown, 60000)
      }
    }
  } catch (e) {
    console.error('获取活动信息失败', e)
  }
  loading.value = false
}

const fetchItems = async () => {
  itemsLoading.value = true
  try {
    const res = await api.get(`/activities/${route.params.id}/items`, {
      params: { page: page.value, pageSize, sort: sort.value }
    })
    if (res.data.code === 0) {
      items.value = res.data.data.list
      total.value = res.data.data.total
    }
  } catch (e) {
    console.error('获取活动商品失败', e)
  }
  itemsLoading.value = false
}

const onSortChange = () => {
  page.value = 1
  fetchItems()
}

onMounted(() => {
  fetchActivity()
  fetchItems()
})

onUnmounted(() => {
  if (countdownTimer) clearInterval(countdownTimer)
})
</script>

<style scoped>
.activity-detail-page { min-height: 400px; }

/* ===== 活动头部 ===== */
.activity-header {
  margin-bottom: 24px;
  border-radius: 14px;
  overflow: hidden;
  background: #fff;
  box-shadow: 0 2px 8px rgba(0,0,0,0.06);
}
.banner-wrap { width: 100%; height: 200px; overflow: hidden; }
.banner-img { width: 100%; height: 100%; object-fit: cover; }
.banner-placeholder {
  width: 100%; height: 100%;
  background: linear-gradient(135deg, #667eea, #764ba2);
  display: flex; align-items: center; justify-content: center;
  color: rgba(255,255,255,0.4);
}
.activity-info { padding: 20px 24px; }
.activity-name { font-size: 22px; font-weight: 700; color: #303133; margin: 0 0 8px 0; }
.activity-desc { font-size: 14px; color: #606266; margin: 0 0 14px 0; line-height: 1.7; }
.activity-meta { display: flex; align-items: center; gap: 14px; font-size: 13px; color: #909399; flex-wrap: wrap; }
.activity-time { display: flex; align-items: center; gap: 4px; }
.activity-count strong { color: #f56c6c; font-size: 16px; }
.countdown-bar {
  margin-top: 14px; padding: 12px 18px;
  background: linear-gradient(135deg, #fef0f0, #fdf6ec);
  border-radius: 10px; font-size: 14px; color: #e6a23c;
  display: flex; align-items: center; gap: 8px;
}
.countdown-bar strong { color: #f56c6c; font-size: 16px; }
.subsidy-banner {
  margin-top: 14px; padding: 12px 18px;
  background: linear-gradient(135deg, #fef0f0, #fff5f5);
  border-radius: 10px; border-left: 4px solid #f56c6c;
}
.subsidy-banner p { margin: 0; font-size: 14px; color: #e6a23c; }

/* ===== 排序栏 ===== */
.sort-bar {
  background: #fff; padding: 12px 20px;
  border-radius: 12px; margin-bottom: 20px;
  box-shadow: 0 1px 4px rgba(0,0,0,0.04);
}

/* ===== 商品网格 ===== */
.item-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(240px, 1fr));
  gap: 18px; min-height: 200px;
}
.item-card {
  background: #fff; border-radius: 12px; overflow: hidden;
  cursor: pointer; border: 1px solid #f0f0f0;
  transition: transform 0.2s, box-shadow 0.2s;
}
.item-card:hover { transform: translateY(-4px); box-shadow: 0 8px 24px rgba(0,0,0,0.1); }
.card-img { height: 180px; position: relative; overflow: hidden; background: #f5f5f5; }
.card-img-real { width: 100%; height: 100%; object-fit: cover; }
.card-img-placeholder {
  height: 100%; background: linear-gradient(135deg, #e8eaf6, #f3e5f5);
  display: flex; align-items: center; justify-content: center; color: #bbb;
}
.my-tag { position: absolute; top: 8px; left: 8px; z-index: 2; }
.card-price {
  position: absolute; bottom: 10px; left: 10px;
  background: rgba(245,108,108,0.92); color: #fff;
  padding: 4px 12px; border-radius: 20px; font-size: 15px; font-weight: 700;
}
.card-body { padding: 14px 16px; }
.card-title {
  font-size: 14px; font-weight: 500; color: #303133;
  margin-bottom: 8px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;
}
.card-meta { margin-bottom: 8px; }
.card-footer {
  display: flex; justify-content: space-between; align-items: center;
  font-size: 12px; color: #909399;
}
.seller { display: flex; align-items: center; gap: 4px; }
.stats { display: flex; align-items: center; gap: 3px; }
.pagination { display: flex; justify-content: center; margin-top: 28px; padding-bottom: 24px; }
</style>
