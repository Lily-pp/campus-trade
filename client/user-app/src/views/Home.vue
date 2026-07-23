<template>
  <div class="home-page">
    <!-- 分类筛选栏 -->
    <div class="filter-bar">
      <div class="category-filter">
        <el-radio-group v-model="filters.category_id" @change="onFilterChange" size="default">
          <el-radio-button :value="''">全部分类</el-radio-button>
          <el-radio-button v-for="cat in categories" :key="cat.id" :value="cat.id">
            {{ cat.name }}
          </el-radio-button>
        </el-radio-group>
      </div>
      <div class="sort-filter">
        <el-select v-model="filters.sort" @change="onFilterChange" style="width: 130px">
          <el-option label="最新发布" value="newest" />
          <el-option label="价格最低" value="price_asc" />
          <el-option label="价格最高" value="price_desc" />
          <el-option label="最热门" value="hot" />
        </el-select>
      </div>
    </div>

    <!-- 热门商品（无搜索、无分类筛选时显示） -->
    <div v-if="!route.query.keyword && !filters.category_id && trending.length > 0" class="trending-section">
      <div class="section-title">近期热门</div>
      <div class="trending-grid">
        <div
          v-for="tItem in trending"
          :key="tItem.id"
          class="trending-card"
          @click="router.push(`/item/${tItem.id}`)"
        >
          <div class="trending-img">
            <img v-if="tItem.cover_image" v-lazy="tItem.cover_image.startsWith('http') ? tItem.cover_image : `http://localhost:3000${tItem.cover_image}`" class="trending-img-real" />
            <div v-else class="trending-img-placeholder">
              <el-icon :size="24"><Picture /></el-icon>
            </div>
          </div>
          <div class="trending-info">
            <div class="trending-title">{{ tItem.title }}</div>
            <div class="trending-bottom">
              <span class="trending-price">¥{{ tItem.price }}</span>
              <span class="trending-views"><el-icon><View /></el-icon>{{ tItem.views_count || 0 }}</span>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- 校园活动专区（无搜索、无分类筛选时显示） -->
    <div v-if="!route.query.keyword && !filters.category_id" class="activity-section">
      <div class="section-title">🎓 校园活动运营</div>
      <!-- 毕业公益入口 -->
      <div class="charity-entry" @click="router.push('/charity')">
        <div class="charity-entry-bg">
          <span class="charity-entry-icon">🎁</span>
          <div>
            <div class="charity-entry-title">毕业公益循环计划</div>
            <div class="charity-entry-desc">免费赠送闲置物品，让资源在校内循环利用</div>
          </div>
          <el-icon :size="20" style="color:#fff"><ArrowRight /></el-icon>
        </div>
      </div>
      <div v-if="activities.length > 0" class="activity-grid">
        <div
          v-for="act in activities"
          :key="act.id"
          class="activity-card"
          @click="router.push(`/activity/${act.id}`)"
        >
          <div class="activity-card-banner">
            <img v-if="act.banner_url" v-lazy="act.banner_url.startsWith('http') ? act.banner_url : `http://localhost:3000${act.banner_url}`" class="activity-banner-img" />
            <div v-else class="activity-banner-placeholder">
              <el-icon :size="28"><Calendar /></el-icon>
            </div>
          </div>
          <div class="activity-card-info">
            <div class="activity-card-name">
              {{ act.name }}
              <el-tag v-if="act.subsidy_enabled" type="warning" size="small" effect="dark">官方补贴</el-tag>
            </div>
            <div class="activity-card-tagline" v-if="act.tagline">{{ act.tagline }}</div>
            <div class="activity-card-desc" v-else-if="act.description">{{ act.description }}</div>
            <div class="activity-card-count">{{ act.item_count || 0 }} 件商品</div>
          </div>
        </div>
      </div>
    </div>

    <!-- 校园生活服务入口（无搜索、无分类筛选时显示） -->
    <div v-if="!route.query.keyword && !filters.category_id" class="service-section">
      <div class="section-title">🏠 校园生活服务</div>
      <div class="service-grid">
        <div class="service-card" @click="router.push('/storage-services')">
          <div class="service-icon">📦</div>
          <div class="service-name">寄存服务</div>
          <div class="service-desc">浏览校园寄存空间</div>
        </div>
        <div class="service-card" @click="router.push('/storage-requests')">
          <div class="service-icon">🔍</div>
          <div class="service-name">寄存需求</div>
          <div class="service-desc">寻找需要寄存的同学</div>
        </div>
        <div class="service-card" @click="router.push('/rental-items')">
          <div class="service-icon">🔁</div>
          <div class="service-name">校园转租</div>
          <div class="service-desc">相机、无人机、投影仪短租</div>
        </div>
      </div>
    </div>

    <!-- 搜索提示 -->
    <div v-if="route.query.keyword" class="search-tip">
      搜索 "<strong>{{ route.query.keyword }}</strong>" 的结果，共 {{ total }} 件商品
      <el-button text type="primary" @click="clearSearch">清除搜索</el-button>
    </div>

    <!-- 商品网格 -->
    <div class="item-grid" v-loading="loading">
      <el-empty v-if="items.length === 0 && !loading" description="暂无商品" />
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
          <span class="card-price">¥{{ item.price }}</span>
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
import { ref, onMounted, watch } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { Picture, Calendar, ArrowRight } from '@element-plus/icons-vue'
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
/* ===== 通用 ===== */
.section-title {
  font-size: 18px;
  font-weight: 700;
  color: #303133;
  margin-bottom: 14px;
  padding-left: 4px;
  border-left: 3px solid #409eff;
  padding: 0 0 0 10px;
  line-height: 1.2;
}

/* ===== 筛选栏 ===== */
.filter-bar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  background: #fff;
  padding: 14px 20px;
  border-radius: 12px;
  margin-bottom: 20px;
  flex-wrap: wrap;
  gap: 12px;
  box-shadow: 0 1px 4px rgba(0,0,0,0.04);
}
.search-tip {
  padding: 12px 18px;
  background: #ecf5ff;
  border-radius: 10px;
  margin-bottom: 20px;
  font-size: 14px;
  color: #606266;
  display: flex;
  align-items: center;
  gap: 12px;
}

/* ===== 商品网格 ===== */
.item-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(240px, 1fr));
  gap: 18px;
  min-height: 200px;
}
.item-card {
  background: #fff;
  border-radius: 12px;
  overflow: hidden;
  cursor: pointer;
  transition: transform 0.2s, box-shadow 0.2s;
  border: 1px solid #f0f0f0;
}
.item-card:hover {
  transform: translateY(-4px);
  box-shadow: 0 8px 24px rgba(0,0,0,0.1);
}
.card-img {
  height: 180px;
  position: relative;
  overflow: hidden;
  background: #f5f5f5;
}
.card-img-real { width: 100%; height: 100%; object-fit: cover; }
.card-img-placeholder {
  height: 100%;
  background: linear-gradient(135deg, #e8eaf6, #f3e5f5);
  display: flex; align-items: center; justify-content: center;
  color: #bbb;
}
.my-tag { position: absolute; top: 8px; left: 8px; z-index: 2; }
.card-price {
  position: absolute;
  bottom: 10px; left: 10px;
  background: rgba(245,108,108,0.92);
  color: #fff;
  padding: 4px 12px;
  border-radius: 20px;
  font-size: 15px;
  font-weight: 700;
}
.card-body { padding: 14px 16px; }
.card-title {
  font-size: 14px; font-weight: 500; color: #303133;
  margin-bottom: 8px;
  overflow: hidden; text-overflow: ellipsis; white-space: nowrap;
}
.card-meta { margin-bottom: 8px; }
.card-footer {
  display: flex; justify-content: space-between; align-items: center;
  font-size: 12px; color: #909399;
}
.seller { display: flex; align-items: center; gap: 4px; }
.stats { display: flex; align-items: center; gap: 3px; }
.pagination { display: flex; justify-content: center; margin-top: 28px; padding-bottom: 24px; }

/* ===== 近期热门 ===== */
.trending-section { margin-bottom: 28px; }
.trending-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(260px, 1fr));
  gap: 14px;
}
.trending-card {
  background: #fff;
  border-radius: 12px;
  overflow: hidden;
  cursor: pointer;
  border: 1px solid #f0f0f0;
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 12px;
  transition: box-shadow 0.2s;
}
.trending-card:hover { box-shadow: 0 4px 16px rgba(0,0,0,0.08); }
.trending-img {
  width: 72px; height: 72px; flex-shrink: 0;
  border-radius: 8px; overflow: hidden; background: #f5f5f5;
}
.trending-img-real { width: 100%; height: 100%; object-fit: cover; }
.trending-img-placeholder {
  width: 100%; height: 100%;
  display: flex; align-items: center; justify-content: center; color: #bbb;
}
.trending-info { flex: 1; min-width: 0; }
.trending-title {
  font-size: 14px; font-weight: 500; color: #303133;
  margin-bottom: 6px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;
}
.trending-bottom { display: flex; align-items: center; justify-content: space-between; }
.trending-price { font-size: 15px; color: #f56c6c; font-weight: 700; }
.trending-views { font-size: 12px; color: #c0c4cc; display: flex; align-items: center; gap: 3px; }

/* ===== 毕业公益入口 ===== */
.charity-entry { margin-bottom: 14px; border-radius: 14px; overflow: hidden; cursor: pointer; }
.charity-entry-bg {
  background: linear-gradient(135deg, #f093fb, #f5576c);
  padding: 18px 22px; display: flex; align-items: center; gap: 14px;
  transition: opacity 0.2s;
}
.charity-entry-bg:hover { opacity: 0.9; }
.charity-entry-icon { font-size: 36px; }
.charity-entry-title { font-size: 16px; font-weight: 700; color: #fff; }
.charity-entry-desc { font-size: 13px; color: rgba(255,255,255,0.85); margin-top: 2px; }

/* ===== 校园活动运营 ===== */
.activity-section { margin-bottom: 28px; }
.activity-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(360px, 1fr));
  gap: 14px;
}
.activity-card {
  background: #fff;
  border-radius: 12px;
  overflow: hidden;
  cursor: pointer;
  border: 1px solid #f0f0f0;
  display: flex;
  min-height: 100px;
  transition: box-shadow 0.2s;
}
.activity-card:hover { box-shadow: 0 4px 16px rgba(0,0,0,0.08); }
.activity-card-banner {
  width: 150px; flex-shrink: 0; overflow: hidden; background: #f5f5f5;
}
.activity-banner-img { width: 100%; height: 100%; object-fit: cover; }
.activity-banner-placeholder {
  width: 100%; height: 100%;
  background: linear-gradient(135deg, #667eea, #764ba2);
  display: flex; align-items: center; justify-content: center;
  color: rgba(255,255,255,0.5);
}
.activity-card-info {
  flex: 1; padding: 14px 18px;
  display: flex; flex-direction: column; justify-content: center; min-width: 0;
}
.activity-card-name {
  font-size: 15px; font-weight: 600; color: #303133;
  margin-bottom: 6px; display: flex; align-items: center; gap: 8px;
}
.activity-card-tagline {
  font-size: 12px; color: #e6a23c; margin-bottom: 6px;
  overflow: hidden; text-overflow: ellipsis; white-space: nowrap;
}
.activity-card-desc {
  font-size: 12px; color: #909399; margin-bottom: 6px;
  overflow: hidden; text-overflow: ellipsis; white-space: nowrap;
}
.activity-card-count { font-size: 13px; color: #f56c6c; font-weight: 500; }

/* ===== 校园生活服务 ===== */
.service-section { margin-bottom: 28px; }
.service-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 16px;
}
.service-card {
  background: #fff;
  border-radius: 12px;
  padding: 28px 20px;
  cursor: pointer;
  border: 1px solid #f0f0f0;
  text-align: center;
  transition: box-shadow 0.2s, transform 0.2s;
}
.service-card:hover { box-shadow: 0 6px 20px rgba(0,0,0,0.08); transform: translateY(-3px); }
.service-icon { font-size: 40px; margin-bottom: 10px; }
.service-name { font-size: 16px; font-weight: 600; color: #303133; margin-bottom: 6px; }
.service-desc { font-size: 13px; color: #909399; line-height: 1.5; }
</style>
