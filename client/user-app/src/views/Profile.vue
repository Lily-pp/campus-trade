<template>
  <div class="profile-page">
    <!-- 用户信息卡 -->
    <div class="user-profile-card">
      <div class="user-banner-bg"></div>
      <div class="user-profile-body">
        <div class="user-avatar-section">
          <div class="user-avatar-lg">
            {{ (userStore.user?.real_name || userStore.user?.username)?.[0] || 'U' }}
          </div>
          <span class="charity-badge" v-if="userStore.user?.charity_points">
            🎖️ {{ userStore.user.charity_points }} 公益积分
          </span>
        </div>
        <div class="user-meta">
          <h2>{{ userStore.user?.real_name || userStore.user?.username }}</h2>
          <div class="user-meta-info">
            <span v-if="userStore.user?.campus">📍 {{ userStore.user.campus }}</span>
            <span>@{{ userStore.user?.username }}</span>
          </div>
        </div>
        <button class="publish-btn" @click="router.push('/publish')">
          📦 发布商品
        </button>
      </div>
    </div>

    <!-- Tab 面板 -->
    <div class="profile-tab-card">
      <el-tabs v-model="activeTab" @tab-change="onTabChange">
        <!-- 我的发布 -->
        <el-tab-pane label="📋 我的发布" name="published">
          <div v-loading="loading">
            <el-empty v-if="publishedItems.length === 0 && !loading" description="还没有发布过商品 ~">
              <button class="empty-action-btn" @click="router.push('/publish')">📦 去发布</button>
            </el-empty>
            <div v-else class="my-item-list">
              <div v-for="item in publishedItems" :key="item.id" class="my-item" @click="router.push(`/item/${item.id}`)">
                <div class="my-item-left">
                  <div class="my-item-title">{{ item.title }}</div>
                  <div class="my-item-meta">
                    <span class="meta-tag">{{ item.category_name }}</span>
                    <span class="meta-tag" :class="item.status">{{ getStatusLabel(item) }}</span>
                    <span v-if="item.status === 'sold'" class="meta-tag sold">已售出</span>
                  </div>
                </div>
                <div class="my-item-right">
                  <div class="my-item-price">¥{{ item.price }}</div>
                  <div class="my-item-stats">
                    <span>📦 {{ item.quantity ?? 1 }}</span>
                    <span>👁️ {{ item.views_count || 0 }}</span>
                    <span>❤️ {{ item.favorites_count || 0 }}</span>
                  </div>
                  <div class="my-item-actions" @click.stop>
                    <button
                      v-if="item.status === 'on_sale' || item.status === 'pending'"
                      class="action-sm-btn warn-btn"
                      @click.stop="toggleItemStatus(item, 'off')"
                    >下架</button>
                    <button
                      v-if="item.status === 'off' && item.is_approved"
                      class="action-sm-btn success-btn"
                      @click.stop="toggleItemStatus(item, 'on_sale')"
                    >上架</button>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </el-tab-pane>

        <!-- 我的收藏 -->
        <el-tab-pane label="❤️ 我的收藏" name="favorites">
          <div v-loading="loading">
            <el-empty v-if="favoriteItems.length === 0 && !loading" description="还没有收藏过商品 ~">
              <button class="empty-action-btn" @click="router.push('/')">🎯 去逛逛</button>
            </el-empty>
            <div v-else class="my-item-list">
              <div v-for="item in favoriteItems" :key="item.id" class="my-item" @click="router.push(`/item/${item.id}`)">
                <div class="my-item-left">
                  <div class="my-item-title">{{ item.title }}</div>
                  <div class="my-item-meta">
                    <span class="meta-tag">{{ item.category_name }}</span>
                    <span class="meta-seller">{{ item.seller_name }}</span>
                  </div>
                </div>
                <div class="my-item-right">
                  <div class="my-item-price">¥{{ item.price }}</div>
                  <button class="unfav-btn" @click.stop="removeFavorite(item.id)">取消收藏</button>
                </div>
              </div>
            </div>
          </div>
        </el-tab-pane>

        <!-- 我的浏览 -->
        <el-tab-pane label="👁️ 我的浏览" name="history">
          <div v-loading="loading">
            <el-empty v-if="viewHistory.length === 0 && !loading" description="还没有浏览记录" />
            <div v-else class="my-item-list">
              <div v-for="item in viewHistory" :key="item.id" class="my-item" @click="router.push(`/item/${item.id}`)">
                <div class="my-item-left">
                  <div class="my-item-title">{{ item.title }}</div>
                  <div class="my-item-meta">
                    <span class="meta-tag">{{ item.category_name }}</span>
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
        <el-tab-pane label="🎫 我的代金券" name="vouchers">
          <div v-loading="vouchersLoading">
            <el-empty v-if="vouchers.length === 0" description="还没有代金券 ~">
              <span class="empty-hint">参加官方补贴活动，成交后即可抽取代金券 🎰</span>
            </el-empty>
            <div v-else class="voucher-list">
              <div v-for="v in vouchers" :key="v.id" class="voucher-card" :class="{ used: v.status !== 'unused', expired: v.status === 'expired' }">
                <div class="voucher-left">
                  <div class="voucher-amount">
                    <span class="voucher-symbol">¥</span>
                    <span class="voucher-value">{{ v.amount }}</span>
                  </div>
                </div>
                <div class="voucher-right">
                  <div class="voucher-source">{{ v.activity_name || '官方活动' }}</div>
                  <div class="voucher-time">获得：{{ formatTime(v.obtained_at) }}</div>
                  <div class="voucher-time">有效期至：{{ formatTime(v.expires_at) }}</div>
                  <div class="voucher-status">
                    <span v-if="v.status === 'unused'" class="v-status active">✅ 可使用</span>
                    <span v-else-if="v.status === 'used'" class="v-status used">已使用</span>
                    <span v-else class="v-status expired">已过期</span>
                  </div>
                  <button v-if="v.status === 'unused'" class="use-voucher-btn" @click="router.push('/')">
                    去使用 🛒
                  </button>
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

/* ===== 用户资料卡片 ===== */
.user-profile-card {
  background: #fff;
  border-radius: 20px;
  overflow: hidden;
  margin-bottom: 20px;
  box-shadow: 0 4px 24px rgba(0,0,0,0.04);
  border: 1px solid rgba(240, 230, 224, 0.3);
}
.user-banner-bg {
  height: 80px;
  background: linear-gradient(135deg, #FFE8E0 0%, #FFD4E0 50%, #F0E8FF 100%);
}
.user-profile-body {
  display: flex;
  align-items: center;
  gap: 20px;
  padding: 0 28px 24px;
  margin-top: -32px;
}
.user-avatar-section {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 8px;
}
.user-avatar-lg {
  width: 72px;
  height: 72px;
  border-radius: 50%;
  background: linear-gradient(135deg, #FF7E67, #FD79A8);
  color: #fff;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 28px;
  font-weight: 700;
  border: 4px solid #fff;
  box-shadow: 0 4px 16px rgba(255, 126, 103, 0.2);
}
.charity-badge {
  font-size: 11px;
  font-weight: 600;
  color: #E8963E;
  background: rgba(253, 203, 110, 0.15);
  padding: 3px 12px;
  border-radius: 20px;
  white-space: nowrap;
}
.user-meta {
  flex: 1;
}
.user-meta h2 {
  margin: 0 0 4px;
  font-size: 22px;
  font-weight: 700;
  color: #2D3436;
}
.user-meta-info {
  display: flex;
  gap: 12px;
  font-size: 13px;
  color: #8892A0;
  flex-wrap: wrap;
}
.publish-btn {
  padding: 10px 24px;
  background: linear-gradient(135deg, #FF7E67, #FD79A8);
  color: #fff;
  border: none;
  border-radius: 14px;
  font-size: 14px;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.3s ease;
  box-shadow: 0 4px 15px rgba(255, 126, 103, 0.2);
  white-space: nowrap;
}
.publish-btn:hover {
  transform: translateY(-2px);
  box-shadow: 0 6px 25px rgba(255, 126, 103, 0.35);
}

/* ===== Tab 面板 ===== */
.profile-tab-card {
  background: #fff;
  border-radius: 20px;
  padding: 20px 24px;
  box-shadow: 0 4px 24px rgba(0,0,0,0.04);
  border: 1px solid rgba(240, 230, 224, 0.3);
  min-height: 300px;
}

/* ===== 列表 ===== */
.my-item-list {
  display: flex;
  flex-direction: column;
  gap: 8px;
}
.my-item {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 14px 18px;
  background: #FFFAF8;
  border-radius: 14px;
  cursor: pointer;
  transition: all 0.2s;
  border: 1px solid transparent;
}
.my-item:hover {
  background: #FFF0EB;
  border-color: rgba(255, 126, 103, 0.1);
}
.my-item-left {
  min-width: 0;
  flex: 1;
}
.my-item-title {
  font-size: 15px;
  font-weight: 600;
  color: #2D3436;
  margin-bottom: 6px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.my-item-meta {
  display: flex;
  align-items: center;
  gap: 6px;
  flex-wrap: wrap;
}
.meta-tag {
  display: inline-block;
  padding: 2px 10px;
  border-radius: 6px;
  font-size: 11px;
  font-weight: 600;
  background: rgba(255, 126, 103, 0.06);
  color: #FF7E67;
}
.meta-tag.on_sale { background: rgba(0, 184, 148, 0.1); color: #00B894; }
.meta-tag.sold { background: rgba(178, 190, 195, 0.15); color: #8892A0; }
.meta-tag.off { background: rgba(255, 183, 77, 0.12); color: #E8963E; }
.meta-tag.pending { background: rgba(108, 92, 231, 0.1); color: #6C5CE7; }
.meta-seller, .meta-time {
  font-size: 12px;
  color: #8892A0;
}
.my-item-right {
  text-align: right;
  flex-shrink: 0;
  margin-left: 20px;
}
.my-item-price {
  font-size: 18px;
  font-weight: 700;
  color: #FF7E67;
  margin-bottom: 4px;
}
.my-item-stats {
  display: flex;
  gap: 8px;
  font-size: 11px;
  color: #B2BEC3;
  justify-content: flex-end;
}
.my-item-actions {
  margin-top: 6px;
  display: flex;
  gap: 6px;
  justify-content: flex-end;
}
.action-sm-btn {
  padding: 4px 14px;
  border: none;
  border-radius: 8px;
  font-size: 12px;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.2s;
}
.warn-btn {
  background: rgba(255, 183, 77, 0.12);
  color: #E8963E;
}
.warn-btn:hover {
  background: #E8963E;
  color: #fff;
}
.success-btn {
  background: rgba(0, 184, 148, 0.1);
  color: #00B894;
}
.success-btn:hover {
  background: #00B894;
  color: #fff;
}
.unfav-btn {
  background: none;
  border: none;
  font-size: 12px;
  color: #FF6B6B;
  cursor: pointer;
  padding: 4px 8px;
  border-radius: 6px;
  font-weight: 500;
  transition: all 0.2s;
}
.unfav-btn:hover {
  background: rgba(255, 107, 107, 0.08);
}

/* ===== 举报区 ===== */
.reports-section {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 60px 0;
  text-align: center;
}
.reports-hint {
  color: #8892A0;
  font-size: 14px;
  margin: 12px 0 0;
}

/* ===== 空状态 ===== */
.empty-hint {
  color: #B2BEC3;
  font-size: 13px;
  display: block;
  margin-top: 8px;
}
.empty-action-btn {
  padding: 10px 28px;
  background: linear-gradient(135deg, #FF7E67, #FD79A8);
  color: #fff;
  border: none;
  border-radius: 12px;
  font-size: 14px;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.3s ease;
}
.empty-action-btn:hover {
  transform: translateY(-2px);
  box-shadow: 0 6px 20px rgba(255, 126, 103, 0.3);
}

/* ===== 代金券 ===== */
.voucher-list {
  display: flex;
  flex-direction: column;
  gap: 12px;
}
.voucher-card {
  display: flex;
  border-radius: 14px;
  overflow: hidden;
  border: 1px solid rgba(240, 230, 224, 0.4);
  background: #fff;
  transition: all 0.2s;
}
.voucher-card:hover {
  box-shadow: 0 4px 16px rgba(0,0,0,0.04);
}
.voucher-card.used { opacity: 0.6; }
.voucher-card.expired { opacity: 0.45; }
.voucher-left {
  width: 120px;
  background: linear-gradient(135deg, #FF7E67, #FD79A8);
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 16px;
  flex-shrink: 0;
}
.voucher-left .voucher-symbol {
  font-size: 16px;
  color: rgba(255,255,255,0.8);
}
.voucher-left .voucher-value {
  font-size: 30px;
  font-weight: 800;
  color: #fff;
}
.voucher-card.used .voucher-left,
.voucher-card.expired .voucher-left {
  background: linear-gradient(135deg, #B2BEC3, #8892A0);
}
.voucher-right {
  flex: 1;
  padding: 16px 18px;
  display: flex;
  flex-direction: column;
  justify-content: center;
  gap: 3px;
}
.voucher-source {
  font-size: 15px;
  font-weight: 600;
  color: #2D3436;
}
.voucher-time {
  font-size: 12px;
  color: #8892A0;
}
.voucher-status {
  margin-top: 4px;
}
.v-status {
  font-size: 12px;
  font-weight: 600;
}
.v-status.active { color: #00B894; }
.v-status.used { color: #8892A0; }
.v-status.expired { color: #B2BEC3; }
.use-voucher-btn {
  margin-top: 6px;
  padding: 6px 16px;
  background: linear-gradient(135deg, #FF7E67, #FD79A8);
  color: #fff;
  border: none;
  border-radius: 10px;
  font-size: 12px;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.2s;
  align-self: flex-start;
}
.use-voucher-btn:hover {
  transform: translateY(-1px);
  box-shadow: 0 4px 12px rgba(255, 126, 103, 0.3);
}

/* ===== 服务/需求详情 ===== */
.detail-info {
  background: #FFF8F5;
  padding: 12px 16px;
  border-radius: 10px;
  margin-top: 12px;
}
.detail-info p {
  margin: 6px 0;
  font-size: 14px;
  color: #636E72;
}
</style>