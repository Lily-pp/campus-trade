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
import { Picture } from '@element-plus/icons-vue'
import api from '@/api'
import { throttle, debounce } from '@/utils/performance'
import { useItemStore } from '@/stores/item'

const router = useRouter()
const route = useRoute()
const itemStore = useItemStore()

const items = ref([])
const trending = ref([])
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

onMounted(() => {
  fetchCategories()
  fetchItems()
  fetchTrending()
})
</script>

<style scoped>
.filter-bar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  background: #fff;
  padding: 16px 20px;
  border-radius: 10px;
  margin-bottom: 16px;
  flex-wrap: wrap;
  gap: 12px;
}

.search-tip {
  padding: 10px 16px;
  background: #ecf5ff;
  border-radius: 8px;
  margin-bottom: 16px;
  font-size: 14px;
  color: #606266;
}

.item-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(250px, 1fr));
  gap: 16px;
  min-height: 200px;
}

.item-card {
  background: #fff;
  border-radius: 10px;
  overflow: hidden;
  cursor: pointer;
  transition: transform 0.2s, box-shadow 0.2s;
  border: 1px solid #f0f0f0;
}

.item-card:hover {
  transform: translateY(-4px);
  box-shadow: 0 8px 24px rgba(0, 0, 0, 0.08);
}

.card-img {
  height: 180px;
  position: relative;
  overflow: hidden;
}

.card-img-real {
  width: 100%; height: 100%; object-fit: cover;
}

.card-img-placeholder {
  height: 100%;
  background: linear-gradient(135deg, #e8eaf6, #f3e5f5);
  display: flex; align-items: center; justify-content: center;
  color: #bbb;
}

.card-price {
  position: absolute;
  bottom: 10px;
  left: 10px;
  background: rgba(245, 108, 108, 0.9);
  color: #fff;
  padding: 4px 10px;
  border-radius: 16px;
  font-size: 16px;
  font-weight: bold;
}

.card-body {
  padding: 12px 14px;
}

.card-title {
  font-size: 15px;
  font-weight: 500;
  color: #303133;
  margin-bottom: 8px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.card-meta {
  margin-bottom: 8px;
}

.card-footer {
  display: flex;
  justify-content: space-between;
  align-items: center;
  font-size: 12px;
  color: #909399;
}

.seller {
  display: flex;
  align-items: center;
  gap: 3px;
}

.stats {
  display: flex;
  align-items: center;
  gap: 2px;
}

.pagination {
  display: flex;
  justify-content: center;
  margin-top: 24px;
  padding-bottom: 20px;
}

.trending-section { margin-bottom: 24px; }
.section-title {
  font-size: 16px;
  font-weight: 600;
  color: #303133;
  margin-bottom: 12px;
  padding-left: 2px;
}
.trending-grid {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 12px;
}
.trending-card {
  background: #fff;
  border-radius: 8px;
  overflow: hidden;
  cursor: pointer;
  border: 1px solid #f0f0f0;
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 10px;
  transition: box-shadow 0.2s;
}
.trending-card:hover { box-shadow: 0 4px 12px rgba(0,0,0,0.08); }
.trending-img { width: 64px; height: 64px; flex-shrink: 0; border-radius: 6px; overflow: hidden; background: #f5f5f5; }
.trending-img-real { width: 100%; height: 100%; object-fit: cover; }
.trending-img-placeholder { width: 100%; height: 100%; display: flex; align-items: center; justify-content: center; color: #bbb; }
.trending-info { flex: 1; min-width: 0; }
.trending-title { font-size: 13px; font-weight: 500; color: #303133; margin-bottom: 6px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.trending-bottom { display: flex; align-items: center; justify-content: space-between; }
.trending-price { font-size: 14px; color: #f56c6c; font-weight: bold; }
.trending-views { font-size: 12px; color: #c0c4cc; display: flex; align-items: center; gap: 2px; }
</style>
