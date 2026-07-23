<template>
  <div class="charity-page">
    <!-- 活动头部 -->
    <div class="charity-header">
      <div class="header-bg">
        <div class="header-content">
          <h1>🎓 2026毕业季公益循环计划</h1>
          <p>帮助毕业生处理闲置物品，实现校园资源循环利用。无法出售的低价值物品可免费赠送给学弟学妹。</p>
          <div class="header-stats">
            <div class="stat-item">
              <span class="stat-num">{{ stats.total_items || 0 }}</span>
              <span class="stat-label">参与物品</span>
            </div>
            <div class="stat-item">
              <span class="stat-num">{{ stats.completed_gives || 0 }}</span>
              <span class="stat-label">成功赠送</span>
            </div>
            <div class="stat-item">
              <span class="stat-num">{{ stats.total_donations || 0 }}</span>
              <span class="stat-label">公益捐赠</span>
            </div>
          </div>
          <el-button type="warning" size="large" @click="router.push('/publish?type=charity')" style="margin-top:16px">
            🎁 我要免费赠送
          </el-button>
        </div>
      </div>
    </div>

    <!-- 免费商品列表 -->
    <div class="charity-list">
      <h3>🎁 免费赠送商品</h3>
      <div v-loading="loading">
        <el-empty v-if="items.length === 0 && !loading" description="暂无免费赠送商品" />
        <div class="charity-grid">
          <div v-for="item in items" :key="item.id" class="charity-card" @click="showDetail(item)">
            <div class="card-img">
              <img v-if="item.cover_image" v-lazy="item.cover_image.startsWith('http') ? item.cover_image : `http://localhost:3000${item.cover_image}`" class="card-img-real" />
              <div v-else class="card-img-placeholder"><el-icon :size="36"><Present /></el-icon></div>
              <span class="charity-plan-tag">公益计划</span>
              <span class="free-tag">🎁 免费赠送</span>
              <el-tag v-if="item.user_id === userStore.user?.id" type="success" size="small" effect="dark" class="my-tag">我的</el-tag>
            </div>
            <div class="card-body">
              <div class="card-title">{{ item.title }}</div>
              <div class="card-desc" v-if="item.description">{{ item.description }}</div>
              <div class="card-meta">
                <span><el-icon><User /></el-icon> {{ item.owner_name || item.owner_real_name }}</span>
                <span v-if="item.campus"><el-icon><Location /></el-icon> {{ item.campus }}</span>
              </div>
              <div class="card-bottom">
                <el-tag v-if="item.apply_count > 0" type="warning" size="small">{{ item.apply_count }} 人申请</el-tag>
                <el-button
                  v-if="item.user_id !== userStore.user?.id"
                  type="warning" size="small" @click.stop="applyItem(item)"
                >申请领取</el-button>
              </div>
            </div>
          </div>
        </div>
        <div class="pagination" v-if="total > pageSize">
          <el-pagination v-model:current-page="page" :page-size="pageSize" :total="total" layout="prev,pager,next" @current-change="fetchItems" />
        </div>
      </div>
    </div>

    <!-- 申请弹窗 -->
    <el-dialog v-model="applyVisible" title="📋 申请领取" width="420px">
      <el-form v-if="applyTarget">
        <el-form-item label="商品">{{ applyTarget.title }}</el-form-item>
        <el-form-item label="留言">
          <el-input v-model="applyMsg" type="textarea" :rows="3" placeholder="简单说明一下为什么要领取..." />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="applyVisible=false">取消</el-button>
        <el-button type="warning" @click="submitApply">确认申请</el-button>
      </template>
    </el-dialog>

    <!-- 我的申请（弹窗） -->
    <el-dialog v-model="myAppliesVisible" title="📋 我的公益申请" width="560px">
      <el-tabs v-model="applyTab">
        <el-tab-pane label="我申请的" name="applied" />
        <el-tab-pane label="别人申请我的" name="received" />
      </el-tabs>
      <div v-loading="applyLoading">
        <el-empty v-if="applies.length === 0" description="暂无申请记录" />
        <div v-for="a in applies" :key="a.id" class="apply-item">
          <div class="apply-info">
            <strong>{{ a.item_title }}</strong>
            <span>{{ applyTab === 'applied' ? '发布者：' + a.owner_name : '申请人：' + a.applicant_name }}</span>
            <el-tag :type="a.status==='pending'?'warning':a.status==='accepted'?'success':a.status==='completed'?'info':'danger'" size="small">{{ statusLabel(a.status) }}</el-tag>
          </div>
          <div class="apply-actions" v-if="applyTab === 'received' && a.status === 'pending'">
            <el-button size="small" type="success" @click="handleApply(a.id, 'accepted')">接受</el-button>
            <el-button size="small" type="danger" @click="handleApply(a.id, 'cancelled')">拒绝</el-button>
          </div>
          <div class="apply-actions" v-if="applyTab === 'received' && a.status === 'accepted'">
            <el-button size="small" type="primary" @click="handleApply(a.id, 'completed')">标记已领取</el-button>
          </div>
        </div>
      </div>
    </el-dialog>
  </div>
</template>

<script setup>
import { ref, onMounted, watch } from 'vue'
import { useRouter } from 'vue-router'
import { ElMessage } from 'element-plus'
import { User, Location, Present } from '@element-plus/icons-vue'
import { useUserStore } from '@/stores/user'
import api from '@/api'

const router = useRouter()
const userStore = useUserStore()
const items = ref([])
const loading = ref(false)
const page = ref(1)
const pageSize = 12
const total = ref(0)
const stats = ref({})
const applyVisible = ref(false)
const applyTarget = ref(null)
const applyMsg = ref('')
const myAppliesVisible = ref(false)
const applies = ref([])
const applyLoading = ref(false)
const applyTab = ref('applied')

const statusLabel = (s) => ({ pending:'待确认',accepted:'已同意',completed:'已领取',cancelled:'已拒绝' }[s]||s)

const fetchItems = async () => {
  loading.value = true
  try {
    const res = await api.get('/charity/items', { params: { page: page.value, pageSize } })
    if (res.data.code === 0) { items.value = res.data.data.list; total.value = res.data.data.total }
  } catch (e) { /* ignore */ }
  loading.value = false
}

const fetchStats = async () => {
  try {
    const res = await api.get('/charity/stats')
    if (res.data.code === 0) stats.value = res.data.data
  } catch (e) { /* ignore */ }
}

const showDetail = (item) => { /* 暂不需要详情页 */ }

const applyItem = (item) => {
  if (!userStore.isLoggedIn) return ElMessage.warning('请先登录')
  applyTarget.value = item; applyMsg.value = ''; applyVisible.value = true
}

const submitApply = async () => {
  try {
    const res = await api.post('/charity/apply', { item_id: applyTarget.value.id, message: applyMsg.value })
    if (res.data.code === 0) { ElMessage.success(res.data.message); applyVisible.value = false; fetchItems() }
  } catch (e) { ElMessage.error(e.response?.data?.message || '申请失败') }
}

const fetchApplies = async () => {
  applyLoading.value = true
  try {
    const res = await api.get('/charity/applies/my', { params: { type: applyTab.value } })
    if (res.data.code === 0) applies.value = res.data.data
  } catch (e) { /* ignore */ }
  applyLoading.value = false
}

const handleApply = async (id, status) => {
  try {
    await api.put(`/charity/apply/${id}`, { status })
    ElMessage.success(status === 'accepted' ? '已接受' : status === 'completed' ? '已完成' : '已处理')
    fetchApplies(); fetchItems()
  } catch (e) { ElMessage.error('操作失败') }
}

watch(applyTab, fetchApplies)
watch(myAppliesVisible, v => { if (v) fetchApplies() })

onMounted(() => { fetchItems(); fetchStats() })
</script>

<style scoped>
.charity-page { max-width: 1000px; margin: 0 auto; }
.charity-header { border-radius: 14px; overflow: hidden; margin-bottom: 28px; }
.header-bg { background: linear-gradient(135deg, #f093fb 0%, #f5576c 50%, #fda085 100%); padding: 40px; color: #fff; }
.header-content h1 { margin: 0 0 8px; font-size: 26px; }
.header-content p { margin: 0 0 20px; font-size: 14px; opacity: 0.9; line-height: 1.6; }
.header-stats { display: flex; gap: 32px; }
.stat-item { text-align: center; }
.stat-num { font-size: 28px; font-weight: 700; display: block; }
.stat-label { font-size: 13px; opacity: 0.85; }
.charity-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(260px, 1fr)); gap: 16px; }
.charity-card { background: #fff; border-radius: 14px; overflow: hidden; cursor: pointer; border: 1px solid #f0f0f0; transition: box-shadow 0.2s; }
.charity-card:hover { box-shadow: 0 6px 20px rgba(0,0,0,0.1); }
.card-img { height: 180px; position: relative; overflow: hidden; background: #fef0f0; }
.card-img-real { width: 100%; height: 100%; object-fit: cover; }
.card-img-placeholder { height: 100%; display: flex; align-items: center; justify-content: center; color: #f56c6c; }
.charity-plan-tag { position: absolute; top: 0; right: 0; background: linear-gradient(135deg, #667eea, #764ba2); color: #fff; padding: 5px 14px 5px 18px; border-radius: 0 14px 0 12px; font-size: 12px; font-weight: 600; z-index: 3; }
.free-tag { position: absolute; bottom: 10px; left: 10px; background: #f56c6c; color: #fff; padding: 4px 12px; border-radius: 20px; font-size: 12px; font-weight: 600; }
.my-tag { position: absolute; top: 10px; left: 10px; }
.card-body { padding: 14px 16px; }
.card-title { font-size: 15px; font-weight: 600; margin-bottom: 6px; color: #303133; }
.card-desc { font-size: 13px; color: #909399; margin-bottom: 10px; line-height: 1.5; display: -webkit-box; -webkit-line-clamp: 2; -webkit-box-orient: vertical; overflow: hidden; }
.card-meta { display: flex; gap: 14px; font-size: 12px; color: #909399; margin-bottom: 10px; align-items: center; }
.card-meta span { display: flex; align-items: center; gap: 3px; }
.card-bottom { display: flex; justify-content: space-between; align-items: center; }
.pagination { display: flex; justify-content: center; margin-top: 28px; }
.apply-item { display: flex; justify-content: space-between; align-items: center; padding: 12px 0; border-bottom: 1px solid #f5f5f5; }
.apply-info { display: flex; flex-direction: column; gap: 4px; font-size: 14px; }
.apply-actions { display: flex; gap: 6px; flex-shrink: 0; }
</style>
