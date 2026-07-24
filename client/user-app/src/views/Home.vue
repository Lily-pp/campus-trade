<template>
  <div class="home-page">
    <!-- ===== 校园欢迎横幅 ===== -->
    <div v-if="!route.query.keyword" class="welcome-banner">
      <div class="welcome-bg">
        <div class="welcome-deco deco-1">📚</div>
        <div class="welcome-deco deco-2">🎓</div>
        <div class="welcome-deco deco-3">✨</div>
        <div class="welcome-deco deco-4">🌸</div>
      </div>
      <div class="welcome-content">
        <h1 class="welcome-title">欢迎来到 <span class="campus-gradient-text">CampusTrade</span></h1>
        <p class="welcome-subtitle">让闲置物品在校园里找到新主人 🌱</p>
        <div class="welcome-stats">
          <div class="stat-item">
            <span class="stat-num">🔥</span>
            <span class="stat-text">今日热卖</span>
          </div>
          <div class="stat-item">
            <span class="stat-num">🎯</span>
            <span class="stat-text">精准匹配</span>
          </div>
          <div class="stat-item">
            <span class="stat-num">💚</span>
            <span class="stat-text">绿色循环</span>
          </div>
        </div>
      </div>
    </div>

    <!-- ===== 分类与排序筛选 ===== -->
    <div class="filter-bar">
      <div class="category-filter">
        <el-radio-group v-model="filters.category_id" @change="onFilterChange">
          <el-radio-button :value="''">✨ 全部</el-radio-button>
          <el-radio-button v-for="cat in categories" :key="cat.id" :value="cat.id">
            {{ cat.name }}
          </el-radio-button>
        </el-radio-group>
      </div>
      <div class="sort-filter">
        <el-select v-model="filters.sort" @change="onFilterChange" style="width: 130px">
          <el-option label="⏰ 最新发布" value="newest" />
          <el-option label="💵 价格最低" value="price_asc" />
          <el-option label="💵 价格最高" value="price_desc" />
          <el-option label="🔥 最热门" value="hot" />
        </el-select>
      </div>
    </div>

    <!-- ===== 热门商品滚动条 ===== -->
    <div v-if="!route.query.keyword && !filters.category_id && trending.length > 0" class="trending-section">
      <div class="section-header">
        <h2 class="campus-section-title">🔥 近期热门</h2>
        <span class="section-more" @click="router.push('/')">查看更多 →</span>
      </div>
      <div class="trending-scroll">
        <div
          v-for="tItem in trending"
          :key="tItem.id"
          class="trending-card"
          @click="router.push(`/item/${tItem.id}`)"
        >
          <div class="trending-img">
            <img v-if="tItem.cover_image" v-lazy="tItem.cover_image.startsWith('http') ? tItem.cover_image : `http://localhost:3000${tItem.cover_image}`" class="trending-img-real" />
            <div v-else class="trending-img-placeholder">📦</div>
          </div>
          <div class="trending-info">
            <div class="trending-title">{{ tItem.title }}</div>
            <div class="trending-bottom">
              <span class="trending-price">¥{{ tItem.price }}</span>
              <span class="trending-views">👁️ {{ tItem.views_count || 0 }}</span>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- ===== 校园特色服务卡片 ===== -->
    <div v-if="!route.query.keyword && !filters.category_id" class="campus-services">
      <div class="section-header">
        <h2 class="campus-section-title">🎯 校园特色</h2>
      </div>
      <div class="service-grid">
        <!-- 失物招领 -->
        <div class="service-card" @click="router.push('/lost-found')">
          <div class="service-card-bg lost-bg">
            <span class="service-emoji">🔍</span>
            <h3>失物招领</h3>
            <p>寻找丢失物品</p>
          </div>
        </div>
        <!-- 毕业公益 -->
        <div class="service-card" @click="router.push('/charity')">
          <div class="service-card-bg charity-bg">
            <span class="service-emoji">🎁</span>
            <h3>毕业公益</h3>
            <p>免费赠送闲置</p>
          </div>
        </div>
        <!-- 寄存服务 -->
        <div class="service-card" @click="router.push('/storage-services')">
          <div class="service-card-bg storage-bg">
            <span class="service-emoji">📦</span>
            <h3>寄存服务</h3>
            <p>校园寄存空间</p>
          </div>
        </div>
        <!-- 校园转租 -->
        <div class="service-card" @click="router.push('/rental-items')">
          <div class="service-card-bg rental-bg">
            <span class="service-emoji">🔄</span>
            <h3>校园转租</h3>
            <p>相机/设备短租</p>
          </div>
        </div>
      </div>
    </div>

    <!-- ===== 校园活动 ===== -->
    <div v-if="!route.query.keyword && !filters.category_id && activities.length > 0" class="activity-section">
      <div class="section-header">
        <h2 class="campus-section-title">🎪 校园活动</h2>
      </div>
      <div class="activity-grid">
        <div
          v-for="act in activities"
          :key="act.id"
          class="activity-card"
          @click="router.push(`/activity/${act.id}`)"
        >
          <div class="activity-banner">
            <img v-if="act.banner_url" v-lazy="act.banner_url.startsWith('http') ? act.banner_url : `http://localhost:3000${act.banner_url}`" />
            <div v-else class="activity-banner-placeholder">🎪</div>
            <el-tag v-if="act.subsidy_enabled" class="subsidy-tag" effect="dark">官方补贴</el-tag>
          </div>
          <div class="activity-info">
            <h3>{{ act.name }}</h3>
            <p v-if="act.tagline">{{ act.tagline }}</p>
            <div class="activity-meta">
              <span>{{ act.item_count || 0 }} 件商品</span>
              <span class="activity-arrow">→</span>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- ===== 搜索提示 ===== -->
    <div v-if="route.query.keyword" class="search-tip">
      <span class="search-tip-icon">🔎</span>
      <span>搜索 "<strong>{{ route.query.keyword }}</strong>" 的结果，共 {{ total }} 件商品</span>
      <el-button class="clear-search-btn" @click="clearSearch">清除搜索 ✕</el-button>
    </div>

    <!-- ===== 商品网格 ===== -->
    <div class="section-header" v-if="items.length > 0">
      <h2 class="campus-section-title">{{ route.query.keyword ? '📋 搜索结果' : '🛍️ 全部商品' }}</h2>
    </div>
    <div class="item-grid" v-loading="loading">
      <el-empty v-if="items.length === 0 && !loading" description="还没有商品哦~ 去发布第一个吧！">
        <el-button class="empty-publish-btn" @click="router.push('/publish')">📦 去发布</el-button>
      </el-empty>
      <div
        v-for="item in items"
        :key="item.id"
        class="item-card"
        @click="router.push(`/item/${item.id}`)"
      >
        <div class="card-img">
          <img v-if="item.cover_image" v-lazy="item.cover_image.startsWith('http') ? item.cover_image : `http://localhost:3000${item.cover_image}`" class="card-img-real" />
          <div v-else class="card-img-placeholder">📸</div>
          <el-tag v-if="item.seller_user_id && item.seller_user_id === userStore.user?.id" class="my-tag">我的</el-tag>
          <span class="card-price">¥{{ item.price }}</span>
        </div>
        <div class="card-body">
          <div class="card-title">{{ item.title }}</div>
          <div class="card-tags">
            <span class="card-tag">{{ item.category_name }}</span>
          </div>
          <div class="card-footer">
            <span class="seller-info">
              <span class="seller-avatar">{{ item.seller_name?.[0] || '?' }}</span>
              <span class="seller-name">{{ item.seller_name }}</span>
              <span v-if="item.seller_campus" class="seller-campus">· {{ item.seller_campus }}</span>
            </span>
            <span class="item-stats">
              <span>👁️ {{ item.views_count || 0 }}</span>
              <span>❤️ {{ item.favorites_count || 0 }}</span>
            </span>
          </div>
        </div>
      </div>
    </div>

    <!-- ===== 分页 ===== -->
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
import { ref, onMounted, watch } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { Picture, Calendar, Search, ArrowRight } from '@element-plus/icons-vue'
import api from '@/api'
import { throttle, debounce } from '@/utils/performance'
import { useItemStore } from '@/stores/item'
import { useUserStore } from '@/stores/user'

const router = useRouter()
const route = useRoute()
const itemStore = useItemStore()
const userStore = useUserStore()

const items = ref([])
const trending = ref([])
const activities = ref([])
const categories = ref([])
const loading = ref(false)
const page = ref(1)
const pageSize = 12
const total = ref(0)
const filters = ref({
  category_id: '',
  sort: 'newest'
})

const fetchCategories = async () => {
  try {
    const res = await itemStore.fetchCategories()
    categories.value = res.code === 0 ? res.data : res
  } catch (e) {
    console.error('获取分类失败', e)
  }
}

const fetchItems = async () => {
  loading.value = true
  try {
    const res = await itemStore.fetchItems(page.value, pageSize, {
      category_id: filters.value.category_id,
      sort: filters.value.sort,
      keyword: route.query.keyword
    })
    if (res.code === 0) {
      items.value = res.data.list
      total.value = res.data.total
    }
  } catch (e) {
    console.error('获取商品失败', e)
  }
  loading.value = false
}

// 节流过滤变化 - 避免频繁切换分类和排序时的重复请求
const onFilterChange = throttle(() => {
  page.value = 1
  fetchItems()
}, 300)

const clearSearch = () => {
  router.push('/')
}

watch(() => route.query.keyword, () => {
  page.value = 1
  fetchItems()
})

const fetchTrending = async () => {
  try {
    const res = await api.get('/recommendations/trending')
    if (res.data.code === 0) trending.value = res.data.data
  } catch (e) { /* ignore */ }
}

const fetchActivities = async () => {
  try {
    const res = await api.get('/activities')
    if (res.data.code === 0) activities.value = res.data.data
  } catch (e) { /* ignore */ }
}

onMounted(() => {
  fetchCategories()
  fetchItems()
  fetchTrending()
  fetchActivities()
})
</script>

<style scoped>
/* ===== 欢迎横幅 ===== */
.welcome-banner {
  position: relative;
  border-radius: 20px;
  overflow: hidden;
  margin-bottom: 24px;
  cursor: default;
}
.welcome-bg {
  position: absolute;
  inset: 0;
  background: linear-gradient(135deg, #FFE8E0 0%, #FFD4E0 30%, #E8E0FF 60%, #E0FFF0 100%);
}
.welcome-deco {
  position: absolute;
  font-size: 48px;
  opacity: 0.3;
  animation: campus-float 4s ease-in-out infinite;
}
.deco-1 { top: 10px; left: 10%; animation-delay: 0s; }
.deco-2 { bottom: 10px; right: 10%; animation-delay: 1s; }
.deco-3 { top: 20px; right: 20%; animation-delay: 0.5s; font-size: 32px; }
.deco-4 { bottom: 20px; left: 20%; animation-delay: 1.5s; font-size: 32px; }
.welcome-content {
  position: relative;
  padding: 40px 36px;
  z-index: 1;
}
.welcome-title {
  font-size: 32px;
  font-weight: 800;
  color: #2D3436;
  margin: 0 0 8px;
}
.welcome-subtitle {
  font-size: 16px;
  color: #8892A0;
  margin: 0 0 24px;
}
.welcome-stats {
  display: flex;
  gap: 24px;
}
.stat-item {
  display: flex;
  align-items: center;
  gap: 6px;
  font-size: 14px;
  color: #636E72;
}
.stat-num { font-size: 20px; }

/* ===== 分类筛选栏 ===== */
.filter-bar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  background: rgba(255, 255, 255, 0.8);
  backdrop-filter: blur(12px);
  padding: 14px 20px;
  border-radius: 16px;
  margin-bottom: 24px;
  flex-wrap: wrap;
  gap: 12px;
  box-shadow: 0 2px 16px rgba(255, 126, 103, 0.06);
  border: 1px solid rgba(240, 230, 224, 0.4);
}

/* ===== 搜索提示 ===== */
.search-tip {
  padding: 14px 20px;
  background: linear-gradient(135deg, rgba(255, 126, 103, 0.06), rgba(253, 121, 168, 0.06));
  border-radius: 14px;
  margin-bottom: 20px;
  font-size: 14px;
  color: #636E72;
  display: flex;
  align-items: center;
  gap: 10px;
  border: 1px solid rgba(255, 126, 103, 0.1);
}
.search-tip-icon { font-size: 20px; }
.clear-search-btn {
  margin-left: auto;
  background: transparent !important;
  border: none !important;
  color: #FF7E67 !important;
  font-weight: 600 !important;
  font-size: 13px !important;
}

/* ===== Section 头部 ===== */
.section-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 16px;
}
.section-more {
  font-size: 13px;
  color: #FF7E67;
  cursor: pointer;
  font-weight: 500;
  transition: all 0.2s;
}
.section-more:hover {
  transform: translateX(4px);
}

/* ===== 商品卡片网格 ===== */
.item-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(250px, 1fr));
  gap: 20px;
  min-height: 200px;
}
.item-card {
  background: #fff;
  border-radius: 16px;
  overflow: hidden;
  cursor: pointer;
  transition: all 0.35s cubic-bezier(0.25, 0.46, 0.45, 0.94);
  box-shadow: 0 2px 12px rgba(0,0,0,0.04);
  border: 1px solid rgba(240, 230, 224, 0.4);
}
.item-card:hover {
  transform: translateY(-6px);
  box-shadow: 0 12px 40px rgba(255, 126, 103, 0.12);
  border-color: transparent;
}
.card-img {
  height: 190px;
  position: relative;
  overflow: hidden;
  background: #FFF8F5;
}
.card-img-real {
  width: 100%;
  height: 100%;
  object-fit: cover;
  transition: transform 0.4s ease;
}
.item-card:hover .card-img-real {
  transform: scale(1.06);
}
.card-img-placeholder {
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 40px;
}
.my-tag {
  position: absolute;
  top: 10px;
  left: 10px;
  z-index: 2;
  background: linear-gradient(135deg, #00B894, #55EFC4) !important;
  border: none !important;
  color: #fff !important;
  font-weight: 600 !important;
  border-radius: 8px !important;
}
.card-price {
  position: absolute;
  bottom: 12px;
  left: 12px;
  background: linear-gradient(135deg, #FF7E67, #FD79A8);
  color: #fff;
  padding: 5px 14px;
  border-radius: 20px;
  font-size: 15px;
  font-weight: 700;
  box-shadow: 0 4px 12px rgba(255, 126, 103, 0.3);
}
.card-body {
  padding: 14px 16px 16px;
}
.card-title {
  font-size: 14px;
  font-weight: 600;
  color: #2D3436;
  margin-bottom: 8px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  line-height: 1.4;
}
.card-tags {
  margin-bottom: 10px;
}
.card-tag {
  display: inline-block;
  padding: 2px 10px;
  background: rgba(255, 126, 103, 0.06);
  color: #FF7E67;
  border-radius: 6px;
  font-size: 11px;
  font-weight: 600;
}
.card-footer {
  display: flex;
  justify-content: space-between;
  align-items: center;
  font-size: 12px;
  color: #8892A0;
  padding-top: 10px;
  border-top: 1px solid #F5F0EC;
}
.seller-info {
  display: flex;
  align-items: center;
  gap: 6px;
  min-width: 0;
}
.seller-avatar {
  width: 20px;
  height: 20px;
  border-radius: 50%;
  background: linear-gradient(135deg, #A29BFE, #6C5CE7);
  color: #fff;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 10px;
  font-weight: 700;
  flex-shrink: 0;
}
.seller-name {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  max-width: 80px;
}
.seller-campus {
  color: #B2BEC3;
  font-size: 11px;
}
.item-stats {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 11px;
}

/* ===== 分页 ===== */
.pagination {
  display: flex;
  justify-content: center;
  margin-top: 32px;
  padding-bottom: 24px;
}

/* ===== 热门商品滚动 ===== */
.trending-section {
  margin-bottom: 32px;
}
.trending-scroll {
  display: flex;
  gap: 12px;
  overflow-x: auto;
  padding: 4px 0 8px;
  scroll-snap-type: x mandatory;
  -webkit-overflow-scrolling: touch;
}
.trending-scroll::-webkit-scrollbar {
  height: 4px;
}
.trending-scroll::-webkit-scrollbar-thumb {
  background: #F0E6E0;
  border-radius: 2px;
}
.trending-card {
  flex: 0 0 280px;
  scroll-snap-align: start;
  background: #fff;
  border-radius: 14px;
  cursor: pointer;
  border: 1px solid rgba(240, 230, 224, 0.4);
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 12px;
  transition: all 0.3s ease;
  box-shadow: 0 2px 8px rgba(0,0,0,0.03);
}
.trending-card:hover {
  box-shadow: 0 8px 24px rgba(255, 126, 103, 0.1);
  transform: translateY(-2px);
  border-color: transparent;
}
.trending-img {
  width: 72px;
  height: 72px;
  flex-shrink: 0;
  border-radius: 10px;
  overflow: hidden;
  background: #FFF8F5;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 28px;
}
.trending-img-real {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.trending-img-placeholder {
  font-size: 28px;
}
.trending-info {
  flex: 1;
  min-width: 0;
}
.trending-title {
  font-size: 14px;
  font-weight: 600;
  color: #2D3436;
  margin-bottom: 6px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.trending-bottom {
  display: flex;
  align-items: center;
  justify-content: space-between;
}
.trending-price {
  font-size: 16px;
  color: #FF7E67;
  font-weight: 700;
}
.trending-views {
  font-size: 12px;
  color: #B2BEC3;
}

/* ===== 校园特色服务 ===== */
.campus-services {
  margin-bottom: 32px;
}
.service-grid {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 16px;
}
@media (max-width: 768px) {
  .service-grid { grid-template-columns: repeat(2, 1fr); }
}
.service-card {
  border-radius: 16px;
  overflow: hidden;
  cursor: pointer;
  transition: all 0.35s cubic-bezier(0.25, 0.46, 0.45, 0.94);
}
.service-card:hover {
  transform: translateY(-4px);
}
.service-card-bg {
  padding: 28px 20px;
  text-align: center;
  transition: all 0.3s;
}
.service-card:hover .service-card-bg {
  padding: 32px 20px 24px;
}
.service-emoji {
  font-size: 40px;
  display: block;
  margin-bottom: 12px;
}
.service-card-bg h3 {
  font-size: 16px;
  font-weight: 700;
  color: #fff;
  margin: 0 0 6px;
}
.service-card-bg p {
  font-size: 13px;
  color: rgba(255,255,255,0.8);
  margin: 0;
}
.lost-bg { background: linear-gradient(135deg, #6C5CE7, #A29BFE); }
.charity-bg { background: linear-gradient(135deg, #FF7E67, #FD79A8); }
.storage-bg { background: linear-gradient(135deg, #00B894, #55EFC4); }
.rental-bg { background: linear-gradient(135deg, #FDCB6E, #FFB74D); }

/* ===== 校园活动 ===== */
.activity-section {
  margin-bottom: 32px;
}
.activity-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(320px, 1fr));
  gap: 16px;
}
.activity-card {
  background: #fff;
  border-radius: 16px;
  overflow: hidden;
  cursor: pointer;
  transition: all 0.35s ease;
  box-shadow: 0 2px 12px rgba(0,0,0,0.04);
  border: 1px solid rgba(240, 230, 224, 0.4);
}
.activity-card:hover {
  transform: translateY(-4px);
  box-shadow: 0 12px 36px rgba(255, 126, 103, 0.1);
  border-color: transparent;
}
.activity-banner {
  height: 140px;
  position: relative;
  background: linear-gradient(135deg, #FFE8E0, #FFD4E0);
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 48px;
  overflow: hidden;
}
.activity-banner img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.activity-banner-placeholder {
  font-size: 48px;
}
.subsidy-tag {
  position: absolute;
  top: 12px;
  right: 12px;
  background: linear-gradient(135deg, #FDCB6E, #FFB74D) !important;
  border: none !important;
  color: #fff !important;
  font-weight: 600 !important;
  border-radius: 8px !important;
}
.activity-info {
  padding: 16px 18px;
}
.activity-info h3 {
  font-size: 15px;
  font-weight: 600;
  color: #2D3436;
  margin: 0 0 6px;
}
.activity-info p {
  font-size: 12px;
  color: #8892A0;
  margin: 0 0 10px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.activity-meta {
  display: flex;
  justify-content: space-between;
  align-items: center;
  font-size: 13px;
  color: #FF7E67;
  font-weight: 500;
}
.activity-arrow {
  font-size: 18px;
  transition: transform 0.2s;
}
.activity-card:hover .activity-arrow {
  transform: translateX(4px);
}

/* ===== 空状态 ===== */
.empty-publish-btn {
  background: linear-gradient(135deg, #FF7E67, #FD79A8) !important;
  border: none !important;
  color: #fff !important;
  border-radius: 12px !important;
  font-weight: 600 !important;
  padding: 12px 28px !important;
  font-size: 15px !important;
}

/* ===== 响应式 ===== */
@media (max-width: 768px) {
  .welcome-title { font-size: 24px; }
  .welcome-content { padding: 28px 24px; }
  .welcome-stats { flex-wrap: wrap; gap: 16px; }
  .service-grid { grid-template-columns: repeat(2, 1fr); }
  .item-grid { grid-template-columns: repeat(auto-fill, minmax(160px, 1fr)); gap: 14px; }
  .card-img { height: 150px; }
}
</style>
