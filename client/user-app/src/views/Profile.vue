<template>
  <div class="profile-page">
    <!-- 用户信息卡 -->
    <el-card class="user-card" shadow="never">
      <div class="user-header">
        <el-avatar :size="64" icon="UserFilled" />
        <div class="user-meta">
          <h2>{{ userStore.user?.real_name || userStore.user?.username }}</h2>
          <p v-if="userStore.user?.campus">
            <el-icon><Location /></el-icon> {{ userStore.user.campus }}
          </p>
          <p class="user-id">@{{ userStore.user?.username }}</p>
        </div>
        <el-button type="primary" plain @click="router.push('/publish')" class="publish-btn">
          <el-icon><Plus /></el-icon> 发布商品
        </el-button>
      </div>
    </el-card>

    <!-- Tab 面板 -->
    <el-card shadow="never" class="tab-card">
      <el-tabs v-model="activeTab" @tab-change="onTabChange">
        <!-- 我的发布 -->
        <el-tab-pane label="我的发布" name="published">
          <div v-loading="loading">
            <el-empty v-if="publishedItems.length === 0 && !loading" description="还没有发布过商品">
              <el-button type="primary" @click="router.push('/publish')">去发布</el-button>
            </el-empty>
            <div v-else class="my-item-list">
              <div v-for="item in publishedItems" :key="item.id" class="my-item" @click="router.push(`/item/${item.id}`)">
                <div class="my-item-left">
                  <div class="my-item-title">{{ item.title }}</div>
                  <div class="my-item-meta">
                    <el-tag size="small" type="info">{{ item.category_name }}</el-tag>
                    <el-tag size="small" :type="statusType[item.status]">{{ statusMap[item.status] }}</el-tag>
                    <el-tag v-if="item.status === 'sold'" size="small" type="danger">已售出</el-tag>
                  </div>
                </div>
                <div class="my-item-right">
                  <div class="my-item-price">¥{{ item.price }}</div>
                  <div class="my-item-stats">
                    <span style="color:#606266">库存：{{ item.quantity ?? 1 }}</span>
                    <span><el-icon><View /></el-icon>{{ item.views_count || 0 }}</span>
                    <span><el-icon><Star /></el-icon>{{ item.favorites_count || 0 }}</span>
                  </div>
                  <div class="my-item-actions" @click.stop>
                    <el-button
                      v-if="item.status === 'on_sale'"
                      size="small" type="warning" plain
                      :loading="item._loading"
                      @click.stop="toggleItemStatus(item, 'off')"
                    >下架</el-button>
                    <el-button
                      v-if="item.status === 'off'"
                      size="small" type="success" plain
                      :loading="item._loading"
                      @click.stop="toggleItemStatus(item, 'on_sale')"
                    >重新上架</el-button>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </el-tab-pane>

        <!-- 我的收藏 -->
        <el-tab-pane label="我的收藏" name="favorites">
          <div v-loading="loading">
            <el-empty v-if="favoriteItems.length === 0 && !loading" description="还没有收藏过商品">
              <el-button type="primary" @click="router.push('/')">去逛逛</el-button>
            </el-empty>
            <div v-else class="my-item-list">
              <div v-for="item in favoriteItems" :key="item.id" class="my-item" @click="router.push(`/item/${item.id}`)">
                <div class="my-item-left">
                  <div class="my-item-title">{{ item.title }}</div>
                  <div class="my-item-meta">
                    <el-tag size="small" type="info">{{ item.category_name }}</el-tag>
                    <span class="meta-seller">{{ item.seller_name }}</span>
                  </div>
                </div>
                <div class="my-item-right">
                  <div class="my-item-price">¥{{ item.price }}</div>
                  <el-button
                    size="small" type="danger" text
                    @click.stop="removeFavorite(item.id)"
                  >取消收藏</el-button>
                </div>
              </div>
            </div>
          </div>
        </el-tab-pane>

        <!-- 浏览记录 -->
        <el-tab-pane label="浏览记录" name="history">
          <div v-loading="loading">
            <el-empty v-if="viewHistory.length === 0 && !loading" description="还没有浏览记录" />
            <div v-else class="my-item-list">
              <div v-for="item in viewHistory" :key="item.id" class="my-item" @click="router.push(`/item/${item.id}`)">
                <div class="my-item-left">
                  <div class="my-item-title">{{ item.title }}</div>
                  <div class="my-item-meta">
                    <el-tag size="small" type="info">{{ item.category_name }}</el-tag>
                    <span class="meta-time">{{ formatTime(item.viewed_at) }}</span>
                  </div>
                </div>
                <div class="my-item-right">
                  <div class="my-item-price">¥{{ item.price }}</div>
                </div>
              </div>
            </div>
          </div>
        </el-tab-pane>
      </el-tabs>
    </el-card>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { ElMessage } from 'element-plus'
import { Location, Plus } from '@element-plus/icons-vue'
import api from '@/api'
import { useUserStore } from '@/stores/user'

const router = useRouter()
const userStore = useUserStore()

const activeTab = ref('published')
const loading = ref(false)
const publishedItems = ref([])
const favoriteItems = ref([])
const viewHistory = ref([])

const statusMap = { on_sale: '在售', sold: '已售', off: '已下架', pending: '审核中' }
const statusType = { on_sale: 'success', sold: 'info', off: 'warning', pending: '' }

const formatTime = (t) => t ? new Date(t).toLocaleString('zh-CN') : ''

const fetchPublished = async () => {
  loading.value = true
  try {
    const res = await api.get('/items/my')
    if (res.data.code === 0) publishedItems.value = res.data.data
  } catch (e) { console.error(e) }
  loading.value = false
}

const fetchFavorites = async () => {
  loading.value = true
  try {
    const res = await api.get('/favorites')
    if (res.data.code === 0) favoriteItems.value = res.data.data
  } catch (e) { console.error(e) }
  loading.value = false
}

const fetchViews = async () => {
  loading.value = true
  try {
    const res = await api.get('/views')
    if (res.data.code === 0) viewHistory.value = res.data.data
  } catch (e) { console.error(e) }
  loading.value = false
}

const removeFavorite = async (itemId) => {
  try {
    await api.delete(`/favorites/${itemId}`)
    ElMessage.success('已取消收藏')
    favoriteItems.value = favoriteItems.value.filter(i => i.id !== itemId)
  } catch (e) {
    ElMessage.error('操作失败')
  }
}

const toggleItemStatus = async (item, newStatus) => {
  item._loading = true
  const labelMap = { off: '下架', on_sale: '上架' }
  try {
    const res = await api.put(`/items/${item.id}/status`, { status: newStatus })
    if (res.data.code === 0) {
      item.status = newStatus
      ElMessage.success(`商品已${labelMap[newStatus]}`)
    } else {
      ElMessage.error(res.data.message || '操作失败')
    }
  } catch (e) {
    ElMessage.error(e.response?.data?.message || '操作失败')
  }
  item._loading = false
}

const onTabChange = (tab) => {
  if (tab === 'published') fetchPublished()
  else if (tab === 'favorites') fetchFavorites()
  else if (tab === 'history') fetchViews()
}

onMounted(fetchPublished)
</script>

<style scoped>
.profile-page {
  max-width: 900px;
  margin: 0 auto;
}

.user-card {
  margin-bottom: 16px;
}

.user-header {
  display: flex;
  align-items: center;
  gap: 16px;
}

.user-meta {
  flex: 1;
}

.user-meta h2 {
  margin: 0;
  font-size: 20px;
  color: #303133;
}

.user-meta p {
  margin: 4px 0 0;
  font-size: 13px;
  color: #909399;
  display: flex;
  align-items: center;
  gap: 3px;
}

.user-id {
  color: #c0c4cc !important;
}

.publish-btn {
  margin-left: auto;
}

.tab-card {
  min-height: 300px;
}

.my-item-list {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.my-item {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 14px 16px;
  background: #fafafa;
  border-radius: 8px;
  cursor: pointer;
  transition: background 0.2s;
}

.my-item:hover {
  background: #f0f7ff;
}

.my-item-left {
  min-width: 0;
  flex: 1;
}

.my-item-title {
  font-size: 15px;
  font-weight: 500;
  color: #303133;
  margin-bottom: 6px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.my-item-meta {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 12px;
  color: #909399;
}

.meta-seller, .meta-time {
  font-size: 12px;
  color: #909399;
}

.my-item-right {
  text-align: right;
  flex-shrink: 0;
  margin-left: 16px;
}

.my-item-price {
  font-size: 18px;
  font-weight: bold;
  color: #f56c6c;
  margin-bottom: 4px;
}

.my-item-stats {
  display: flex;
  gap: 10px;
  font-size: 12px;
  color: #c0c4cc;
  justify-content: flex-end;
}

.my-item-stats span {
  display: flex;
  align-items: center;
  gap: 2px;
}

.my-item-actions {
  margin-top: 6px;
  display: flex;
  justify-content: flex-end;
}
</style>
