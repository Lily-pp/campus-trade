<template>
  <div class="profile-page">
    <!-- 用户信息卡 -->
    <el-card class="user-card" shadow="never">
      <div class="user-header">
        <el-avatar :size="64" icon="UserFilled" />
        <div class="user-meta">
          <h2>
            {{ userStore.user?.real_name || userStore.user?.username }}
            <span class="charity-badge" v-if="userStore.user?.charity_points">
              🎖️ {{ userStore.user.charity_points }} 公益积分
            </span>
          </h2>
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
                    <el-tag size="small" :type="getStatusType(item)">{{ getStatusLabel(item) }}</el-tag>
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
                      v-if="item.status === 'on_sale' || item.status === 'pending'"
                      size="small" type="warning" plain
                      :loading="item._loading"
                      @click.stop="toggleItemStatus(item, 'off')"
                    >下架</el-button>
                    <el-button
                      v-if="item.status === 'off' && item.is_approved"
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

        <!-- 我的浏览 -->
        <el-tab-pane label="我的浏览" name="history">
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

        <!-- 我的代金券 -->
        <el-tab-pane label="我的代金券" name="vouchers">
          <div v-loading="vouchersLoading">
            <el-empty v-if="vouchers.length === 0" description="还没有代金券">
              <span class="empty-hint">参加官方补贴活动，成交后即可抽取代金券</span>
            </el-empty>
            <div v-else class="voucher-list">
              <div v-for="v in vouchers" :key="v.id" class="voucher-card" :class="{ used: v.status !== 'unused', expired: v.status === 'expired' }">
                <div class="voucher-left">
                  <div class="voucher-amount">
                    <span class="voucher-symbol">¥</span>
                    <span class="voucher-value">{{ v.amount }}</span>
                  </div>
                  <div class="voucher-condition" v-if="v.status === 'unused'">
                    满任意金额可用
                  </div>
                </div>
                <div class="voucher-right">
                  <div class="voucher-source">🏷️ {{ v.activity_name || '官方活动' }}</div>
                  <div class="voucher-time">获得：{{ formatTime(v.obtained_at) }}</div>
                  <div class="voucher-time">有效期至：{{ formatTime(v.expires_at) }}</div>
                  <el-tag v-if="v.status === 'unused'" type="success" size="small">可使用</el-tag>
                  <el-tag v-else-if="v.status === 'used'" type="info" size="small">已使用</el-tag>
                  <el-tag v-else type="danger" size="small">已过期</el-tag>
                  <el-button v-if="v.status === 'unused'" type="primary" size="small" style="margin-top:6px"
                    @click="router.push('/')">去首页购买</el-button>
                </div>
              </div>
            </div>
          </div>
        </el-tab-pane>

        <!-- 我的寄存服务 -->
        <el-tab-pane label="我的寄存服务" name="myStorageServices">
          <div v-loading="storageLoading">
            <el-empty v-if="myStorageServices.length === 0" description="还没有发布寄存服务" />
            <div v-else class="my-item-list">
              <div v-for="s in myStorageServices" :key="s.id" class="my-item" @click="openServiceDetail(s)">
                <div class="my-item-left">
                  <div class="my-item-title">{{ s.title }}</div>
                  <div class="my-item-meta">
                    <el-tag size="small" type="info">{{ s.campus }}</el-tag>
                    <el-tag size="small" :type="s.status === 'available' ? 'success' : s.status === 'almost_full' ? 'warning' : 'danger'">
                      {{ s.status === 'available' ? '空余' : s.status === 'almost_full' ? '即将约满' : '已满' }}
                    </el-tag>
                  </div>
                </div>
                <div class="my-item-right">
                  <div class="my-item-price" v-if="s.price_per_month">¥{{ s.price_per_month }}/月</div>
                </div>
              </div>
            </div>
          </div>
        </el-tab-pane>

        <!-- 我的寄存需求 -->
        <el-tab-pane label="我的寄存需求" name="myStorageRequests">
          <div v-loading="storageLoading">
            <el-empty v-if="myStorageRequests.length === 0" description="还没有发布寄存需求" />
            <div v-else class="my-item-list">
              <div v-for="r in myStorageRequests" :key="r.id" class="my-item" @click="openRequestDetail(r)">
                <div class="my-item-left">
                  <div class="my-item-title">{{ r.title }}</div>
                  <div class="my-item-meta">
                    <el-tag size="small" type="info">{{ r.campus }}</el-tag>
                    <el-tag size="small" :type="r.status === 'searching' ? 'warning' : 'success'">
                      {{ r.status === 'searching' ? '寻找中' : '已找到' }}
                    </el-tag>
                  </div>
                </div>
                <div class="my-item-right">
                  <div class="my-item-price" v-if="r.budget">¥{{ r.budget }}以内</div>
                </div>
              </div>
            </div>
          </div>
        </el-tab-pane>

        <!-- 我的转租 -->
        <el-tab-pane label="我的转租" name="myRentalItems">
          <div v-loading="rentalLoading">
            <el-empty v-if="myRentalItems.length === 0" description="还没有发布转租物品" />
            <div v-else class="my-item-list">
              <div v-for="r in myRentalItems" :key="r.id" class="my-item" @click="openRentalDetail(r)">
                <div class="my-item-left">
                  <div class="my-item-title">{{ r.title }}</div>
                  <div class="my-item-meta">
                    <el-tag size="small" type="info">{{ r.campus || '未指定校区' }}</el-tag>
                    <el-tag size="small" :type="r.status === 'available' ? 'success' : 'info'">
                      {{ r.status === 'available' ? '可租' : '已租出' }}
                    </el-tag>
                  </div>
                </div>
                <div class="my-item-right">
                  <div class="my-item-price">¥{{ r.rental_price }}/天</div>
                  <span class="my-item-stats" v-if="r.deposit">押金 ¥{{ r.deposit }}</span>
                </div>
              </div>
            </div>
          </div>
        </el-tab-pane>

    <!-- 服务/需求/转租 详情与编辑弹窗 -->
    <el-dialog v-model="detailVisible" :title="detailTitle" width="520px" @close="detailItem=null">
      <el-form v-if="detailItem" :model="detailForm" label-width="90px">
        <template v-if="detailType === 'service'">
          <el-form-item label="标题"><el-input v-model="detailForm.title" /></el-form-item>
          <el-form-item label="状态">
            <el-select v-model="detailForm.status" style="width:100%">
              <el-option label="空余" value="available" />
              <el-option label="即将约满" value="almost_full" />
              <el-option label="已满" value="full" />
            </el-select>
          </el-form-item>
          <el-form-item label="剩余容量">
            <el-input-number v-model="detailForm.remain_capacity" :min="0" :max="99" />
          </el-form-item>
        </template>
        <template v-else-if="detailType === 'request'">
          <el-form-item label="标题"><el-input v-model="detailForm.title" /></el-form-item>
          <el-form-item label="状态">
            <el-select v-model="detailForm.status" style="width:100%">
              <el-option label="寻找中" value="searching" />
              <el-option label="已找到" value="matched" />
              <el-option label="已关闭" value="closed" />
            </el-select>
          </el-form-item>
        </template>
        <template v-else-if="detailType === 'rental'">
          <el-form-item label="标题"><el-input v-model="detailForm.title" /></el-form-item>
          <el-form-item label="状态">
            <el-select v-model="detailForm.status" style="width:100%">
              <el-option label="可租" value="available" />
              <el-option label="已租出" value="rented" />
            </el-select>
          </el-form-item>
        </template>
        <div class="detail-info" v-if="detailItem">
          <p><strong>校区：</strong>{{ detailItem.campus || '未指定' }}</p>
          <p v-if="detailItem.location"><strong>位置：</strong>{{ detailItem.location }}</p>
          <p v-if="detailItem.contact_info"><strong>联系方式：</strong>{{ detailItem.contact_info }}</p>
        </div>
      </el-form>
      <template #footer>
        <el-button @click="detailVisible = false">关闭</el-button>
        <el-button type="primary" @click="saveDetail">保存修改</el-button>
      </template>
    </el-dialog>

        <!-- 我的举报 -->
        <el-tab-pane label="我的举报" name="reports">
          <div class="reports-section">
            <el-button type="primary" plain @click="router.push('/reports')" class="view-reports-btn">
              查看举报历史
            </el-button>
            <p class="reports-hint">查看您的举报记录和处理状态</p>
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
const vouchers = ref([])
const vouchersLoading = ref(false)
const myStorageServices = ref([])
const myStorageRequests = ref([])
const myRentalItems = ref([])
const storageLoading = ref(false)
const rentalLoading = ref(false)

const detailVisible = ref(false)
const detailItem = ref(null)
const detailType = ref('')
const detailTitle = ref('')
const detailForm = ref({})

const openServiceDetail = (item) => {
  detailItem.value = item; detailType.value = 'service'; detailTitle.value = '寄存服务详情'
  detailForm.value = { title: item.title, status: item.status, remain_capacity: item.remain_capacity ?? item.capacity }
  detailVisible.value = true
}
const openRequestDetail = (item) => {
  detailItem.value = item; detailType.value = 'request'; detailTitle.value = '寄存需求详情'
  detailForm.value = { title: item.title, status: item.status }
  detailVisible.value = true
}
const openRentalDetail = (item) => {
  detailItem.value = item; detailType.value = 'rental'; detailTitle.value = '转租物品详情'
  detailForm.value = { title: item.title, status: item.status }
  detailVisible.value = true
}
const saveDetail = async () => {
  try {
    let url, payload
    if (detailType.value === 'service') {
      url = `/storage-services/${detailItem.value.id}`
      payload = detailForm.value
    } else if (detailType.value === 'request') {
      url = `/storage-requests/${detailItem.value.id}`
      payload = { status: detailForm.value.status }
    } else {
      url = `/rental-items/${detailItem.value.id}`
      payload = { title: detailForm.value.title, status: detailForm.value.status }
    }
    await api.put(url, payload)
    ElMessage.success('修改成功')
    detailVisible.value = false
    fetchMyStorage(); fetchMyRental()
  } catch (e) { ElMessage.error(e.response?.data?.message || '修改失败') }
}

const statusMap = { on_sale: '在售', sold: '已售', off: '已下架', pending: '审核中', rejected: '审核未通过' }
const statusType = { on_sale: 'success', sold: 'info', off: 'warning', pending: '', rejected: 'danger' }

const getStatusLabel = (item) => statusMap[item.status] || item.status

const getStatusType = (item) => statusType[item.status] || 'info'

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

const fetchVouchers = async () => {
  vouchersLoading.value = true
  try {
    const res = await api.get('/vouchers')
    if (res.data.code === 0) vouchers.value = res.data.data
  } catch (e) { console.error(e) }
  vouchersLoading.value = false
}

const fetchMyStorage = async () => {
  storageLoading.value = true
  try {
    const [sRes, rRes] = await Promise.all([
      api.get('/storage-services', { params: { pageSize: 50 } }),
      api.get('/storage-requests', { params: { pageSize: 50 } })
    ])
    if (sRes.data.code === 0) {
      myStorageServices.value = (sRes.data.data.list || []).filter(s => s.user_id === userStore.user?.id)
    }
    if (rRes.data.code === 0) {
      myStorageRequests.value = (rRes.data.data.list || []).filter(r => r.user_id === userStore.user?.id)
    }
  } catch (e) { console.error(e) }
  storageLoading.value = false
}

const fetchMyRental = async () => {
  rentalLoading.value = true
  try {
    const res = await api.get('/rental-items', { params: { pageSize: 50 } })
    if (res.data.code === 0) {
      myRentalItems.value = (res.data.data.list || []).filter(r => r.user_id === userStore.user?.id)
    }
  } catch (e) { console.error(e) }
  rentalLoading.value = false
}

const onTabChange = (tab) => {
  if (tab === 'published') fetchPublished()
  else if (tab === 'favorites') fetchFavorites()
  else if (tab === 'history') fetchViews()
  else if (tab === 'vouchers') fetchVouchers()
  else if (tab === 'myStorageServices' || tab === 'myStorageRequests') fetchMyStorage()
  else if (tab === 'myRentalItems') fetchMyRental()
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

.charity-badge {
  font-size: 13px; font-weight: 500; color: #e6a23c;
  background: linear-gradient(135deg, #fef0f0, #fdf6ec);
  padding: 3px 12px; border-radius: 20px; margin-left: 10px;
  white-space: nowrap;
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

.reports-section {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 60px 0;
  text-align: center;
}

.view-reports-btn {
  margin-bottom: 16px;
}

.reports-hint {
  color: #909399;
  font-size: 14px;
  margin: 0;
}

.empty-hint { color: #c0c4cc; font-size: 13px; display: block; margin-top: 8px; }
.detail-info { background: #f5f7fa; padding: 12px 16px; border-radius: 8px; margin-top: 12px; }
.detail-info p { margin: 6px 0; font-size: 14px; color: #606266; }

.voucher-list { display: flex; flex-direction: column; gap: 12px; }
.voucher-card {
  display: flex;
  border-radius: 10px;
  overflow: hidden;
  border: 1px solid #f0f0f0;
  background: linear-gradient(135deg, #fff5f5, #fff);
}
.voucher-card.used { opacity: 0.65; }
.voucher-card.expired { opacity: 0.5; background: #f5f5f5; }
.voucher-left {
  width: 130px;
  background: linear-gradient(135deg, #f56c6c, #e6a23c);
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 16px;
  flex-shrink: 0;
}
.voucher-left .voucher-symbol { font-size: 18px; color: rgba(255,255,255,0.8); }
.voucher-left .voucher-value { font-size: 32px; font-weight: bold; color: #fff; }
.voucher-left .voucher-condition { font-size: 11px; color: rgba(255,255,255,0.8); margin-top: 4px; }
.voucher-card.used .voucher-left,
.voucher-card.expired .voucher-left { background: linear-gradient(135deg, #c0c4cc, #909399); }
.voucher-right {
  flex: 1;
  padding: 16px;
  display: flex;
  flex-direction: column;
  justify-content: center;
  gap: 4px;
}
.voucher-source { font-size: 15px; font-weight: 600; color: #303133; }
.voucher-time { font-size: 12px; color: #909399; }
</style>