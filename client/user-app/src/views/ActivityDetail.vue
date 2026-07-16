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
          <el-tag :type="activityTypeTag(activity.type)" size="default">{{ activity.name }}</el-tag>
          <span class="activity-time">
            <el-icon><Clock /></el-icon>
            {{ formatDate(activity.start_time) }} ~ {{ formatDate(activity.end_time) }}
          </span>
          <span class="activity-count">
            共 <strong>{{ activity.item_count || total }}</strong> 件商品
          </span>
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
import { ref, onMounted } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { Picture, Clock } from '@element-plus/icons-vue'
import api from '@/api'

const router = useRouter()
const route = useRoute()

const activity = ref(null)
const items = ref([])
const loading = ref(false)
const itemsLoading = ref(false)
const page = ref(1)
const pageSize = 12
const total = ref(0)
const sort = ref('newest')

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
</script>

<style scoped>
.activity-detail-page {
  min-height: 400px;
}

.activity-header {
  margin-bottom: 20px;
  border-radius: 10px;
  overflow: hidden;
  background: #fff;
  box-shadow: 0 1px 6px rgba(0,0,0,0.04);
}

.banner-wrap {
  width: 100%;
  height: 240px;
  overflow: hidden;
}

.banner-img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.banner-placeholder {
  width: 100%;
  height: 100%;
  background: linear-gradient(135deg, #667eea, #764ba2);
  display: flex;
  align-items: center;
  justify-content: center;
  color: rgba(255,255,255,0.5);
}

.activity-info {
  padding: 20px 24px;
}

.activity-name {
  font-size: 22px;
  font-weight: 600;
  color: #303133;
  margin: 0 0 8px 0;
}

.activity-desc {
  font-size: 14px;
  color: #909399;
  margin: 0 0 12px 0;
  line-height: 1.6;
}

.activity-meta {
  display: flex;
  align-items: center;
  gap: 16px;
  font-size: 13px;
  color: #909399;
  flex-wrap: wrap;
}

.activity-time {
  display: flex;
  align-items: center;
  gap: 4px;
}

.activity-count strong {
  color: #f56c6c;
}

.sort-bar {
  background: #fff;
  padding: 12px 20px;
  border-radius: 10px;
  margin-bottom: 16px;
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
</style>
