<template>
  <div class="lost-found-page">
    <!-- 顶部横幅 -->
    <div class="banner">
      <div class="banner-bg">
        <div class="banner-deco d1">🔍</div>
        <div class="banner-deco d2">❤️</div>
        <div class="banner-deco d3">🎒</div>
      </div>
      <div class="banner-content">
        <h1>🔍 失物招领</h1>
        <p>寻找丢失物品 · 发布拾到物品 · 让物品回到主人身边 💕</p>
      </div>
    </div>

    <!-- 操作区 -->
    <div class="action-bar">
      <el-radio-group v-model="activeTab" @change="loadData">
        <el-radio-button value="found">📢 招领信息</el-radio-button>
        <el-radio-button value="lost">🔎 丢失信息</el-radio-button>
      </el-radio-group>

      <div class="right-actions">
        <button class="action-bar-btn location-btn" @click="openSearchMap">
          📍 {{ searchAddress ? '重新设置位置' : '设置搜索位置' }}
        </button>
  
        <div class="search-input-wrap">
          <input
            v-model="keyword"
            placeholder="搜索物品名称 / 地点..."
            class="bar-search-input"
            @keyup.enter="loadData"
          />
          <button class="bar-search-btn" @click="loadData">🔎</button>
          <button v-if="keyword" class="bar-clear-btn" @click="keyword='';loadData()">✕</button>
        </div>

        <button class="action-bar-btn publish-lf-btn" @click="showPublish = true">
          ✏️ 发布{{ activeTab === 'found' ? '招领' : '丢失' }}信息
        </button>
      </div>
    </div>

    <div v-if="searchAddress" class="search-location-hint">
      📍 当前搜索中心：{{ searchAddress }}
      <button class="clear-location-btn" @click="clearSearchLocation">清除</button>
    </div>

    <!-- 列表 -->
    <div class="item-grid" v-loading="loading">
      <el-empty v-if="list.length === 0 && !loading" description="暂无相关信息 ~" />

      <div v-for="item in list" :key="item.id" class="item-card">
        <div class="card-img">
          <img
            v-if="item.image_url"
            v-lazy="item.image_url.startsWith('http') ? item.image_url : `http://localhost:3000${item.image_url}`"
            class="card-img-real"
          />
          <div v-else class="card-img-placeholder">📸</div>
          <div class="card-badge" :class="activeTab">
            {{ activeTab === 'found' ? '📢 招领' : '🔎 寻物' }}
          </div>
        </div>

        <div class="card-body">
          <h3 class="card-title">{{ item.title }}</h3>
          <p class="card-desc">{{ item.description || '暂无描述' }}</p>

          <div class="card-meta">
            <div class="meta-row">
              <span class="meta-icon">📍</span>
              <span>{{ activeTab === 'found' ? '找到地点' : '丢失地点' }}：{{ item.found_location || item.lost_location || '未知' }}</span>
            </div>
            <div class="meta-row">
              <span class="meta-icon">🕐</span>
              <span>{{ activeTab === 'found' ? '找到时间' : '丢失时间' }}：{{ formatTime(item.found_time || item.lost_time) }}</span>
            </div>
          </div>

    <div class="card-footer">
      <el-tag size="small" :type="statusType(item.status)">
        {{ statusText(item.status) }}
      </el-tag>

      <!-- 本人显示删除 -->
      <el-button
        v-if="isOwnItem(item)"
        type="danger"
        size="small"
        round
        plain
        @click="deleteItem(item)"
      >
        删除
      </el-button>

      <!-- 其他人显示联系对方 -->
      <el-button
        v-else
        type="primary"
        size="small"
        round
        @click="contactUser(item)"
      >
        联系对方
      </el-button>

      <span v-if="item.distance" class="distance">
        {{ formatDistance(item.distance) }}
      </span>
    </div>
  </div>
</div>
    </div>

    <!-- 发布弹窗 -->
    <el-dialog
      v-model="showPublish"
      :title="`发布${activeTab === 'found' ? '招领' : '丢失'}信息`"
      width="480px"
      destroy-on-close
    >
      <el-form label-position="top">
        <el-form-item label="物品名称" required>
          <el-input v-model="form.title" placeholder="请输入物品名称" maxlength="50" show-word-limit />
        </el-form-item>

        <el-form-item label="详细描述" required>
          <el-input
            v-model="form.description"
            type="textarea"
            :rows="3"
            placeholder="请详细描述物品特征、颜色、品牌等"
            maxlength="300"
            show-word-limit
          />
        </el-form-item>

        <el-form-item :label="activeTab === 'found' ? '找到地点' : '丢失地点'" required>
          <div style="display: flex; gap: 8px; width: 100%;">
           <el-input
             v-model="form.location"
             placeholder="请点击右侧按钮在地图上选择位置"
             readonly
            />
            <el-button type="primary" @click="openMapPicker">地图选点</el-button>
          </div>
          <div v-if="form.longitude" style="margin-top: 6px; font-size: 12px; color: #909399;">
           坐标：{{ form.longitude.toFixed(6) }}, {{ form.latitude.toFixed(6) }}
          </div>
        </el-form-item>

        <el-form-item :label="activeTab === 'found' ? '找到时间' : '丢失时间'" required>
          <el-date-picker
            v-model="form.time"
            type="datetime"
            placeholder="选择时间"
            style="width: 100%"
            value-format="YYYY-MM-DD HH:mm:ss"
          />
        </el-form-item>

        <el-form-item v-if="activeTab === 'found'" label="放置的失物招领处">
          <el-select v-model="form.placed_at_point_id" placeholder="请选择（可选）" style="width: 100%" clearable>
            <el-option v-for="p in points" :key="p.id" :label="p.name" :value="p.id" />
          </el-select>
        </el-form-item>

        <el-form-item label="联系电话">
          <el-input v-model="form.contact_phone" placeholder="选填，方便对方联系你" />
        </el-form-item>

        <el-form-item label="物品图片（可选）">
          <el-upload
          action="/api/upload"
          :headers="{ Authorization: `Bearer ${userStore.token}` }"
          :on-success="handleUploadSuccess"
          :on-remove="handleUploadRemove"
          :file-list="uploadedImages"
          list-type="picture-card"
          :limit="3"
        >
          <el-icon><Plus /></el-icon>
        </el-upload>
        <div class="upload-tip">最多上传3张图片，支持 jpg/png</div>
      </el-form-item>


      </el-form>

      <template #footer>
        <el-button @click="showPublish = false">取消</el-button>
        <el-button type="primary" :loading="submitting" @click="submitPublish">发布</el-button>
      </template>
    </el-dialog>
    <!-- 地图选点弹窗 -->
    <el-dialog
      v-model="mapDialogVisible"
      title="在地图上选择位置"
      width="700px"
      destroy-on-close
      @closed="() => { if (map) { map.destroy(); map = null; marker = null } }"
    >
      <div ref="mapContainer" style="width: 100%; height: 420px; border-radius: 8px;"></div>

      <div style="margin-top: 12px; padding: 10px; background: #f5f7fa; border-radius: 6px;">
        <div v-if="selectedAddress" style="font-size: 14px; line-height: 1.5;">
          <strong>当前选择：</strong>{{ selectedAddress }}
          <div style="font-size: 12px; color: #909399; margin-top: 4px;">
           坐标：{{ selectedLng ? selectedLng.toFixed(6) : '' }}, {{ selectedLat ? selectedLat.toFixed(6) : '' }}
          </div>
        </div>
        <div v-else style="color: #909399; font-size: 13px;">
          请在地图上点击选择位置
        </div>
      </div>
      <template #footer>
        <el-button @click="mapDialogVisible = false">取消</el-button>
        <el-button type="primary" @click="confirmMapLocation">确认位置</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup>
import { useRouter } from 'vue-router'
import { Plus, Search, Location, Clock } from '@element-plus/icons-vue'
import { ElMessage } from 'element-plus'
import api from '@/api'
import { useUserStore } from '@/stores/user'
import { ref, onMounted, watch, nextTick } from 'vue'

const mapDialogVisible = ref(false)
const mapContainer = ref(null)
let map = null
let marker = null
let geocoder = null

const selectedAddress = ref('')
const selectedLng = ref(null)
const selectedLat = ref(null)
const router = useRouter()
const userStore = useUserStore()
const activeTab = ref('found')
const keyword = ref('')
const list = ref([])
const points = ref([])
const loading = ref(false)
const showPublish = ref(false)
const submitting = ref(false)
const mapMode = ref('publish') // 'publish' | 'search'

const form = ref({
  title: '',
  description: '',
  location: '',
  longitude: null,
  latitude: null,
  time: '',
  placed_at_point_id: '',
  contact_phone: ''
})

const userLocation = ref({ lat: null, lng: null })


// 格式化距离
const formatDistance = (meters) => {
  if (!meters || meters >= 9999999) return '距离未知'
  if (meters < 1000) {
    return Math.round(meters / 100) * 100 + 'm'
  } else {
    return (meters / 1000).toFixed(1) + 'km'
  }
}


const isOwnItem = (item) => {
  if (!userStore.isLoggedIn || !userStore.user) return false
  const userId = userStore.user.id
  return (item.finder_user_id === userId) || (item.owner_user_id === userId)
}


const uploadedImages = ref([])

const handleUploadSuccess = (response, file, fileList) => {
  if (response.code === 200 || response.code === 0) {
    uploadedImages.value = fileList.map(f => f.response?.data?.url || f.url)
  }
}

const handleUploadRemove = (file) => {
  uploadedImages.value = uploadedImages.value.filter(u => u !== file.response?.data?.url)
}


const deleteItem = async (item) => {
  if (!confirm(`确定要删除这条${activeTab.value === 'found' ? '招领' : '寻物'}信息吗？`)) {
    return
  }

  try {
    const url = activeTab.value === 'found' 
      ? `/lost-found/found/${item.id}` 
      : `/lost-found/lost/${item.id}`

    const res = await api.delete(url)

    if (res.data.code === 200 || res.data.code === 0) {
      ElMessage.success('删除成功')
      loadData() // 刷新列表
    } else {
      ElMessage.error(res.data.message || '删除失败')
    }
  } catch (e) {
    console.error(e)
    ElMessage.error('删除失败')
  }
}


const formatTime = (time) => {
  if (!time) return '未知'
  return new Date(time).toLocaleString('zh-CN')
}

const statusText = (status) => {
  const map = {
    available: '可认领',
    claimed: '已认领',
    returned: '已归还',
    open: '寻找中',
    found: '已找到',
    closed: '已关闭'
  }
  return map[status] || status || '未知'
}

const statusType = (status) => {
  const map = {
    available: 'success',
    claimed: 'info',
    returned: 'info',
    open: 'warning',
    found: 'success',
    closed: 'info'
  }
  return map[status] || ''
}

const loadPoints = async () => {
  try {
    const res = await api.get('/lost-found/points')
    if (res.data.code === 200 || res.data.code === 0) {
      points.value = res.data.data || []
    }
  } catch (e) {}
}

const loadData = async () => {
  loading.value = true
  try {
    const url = activeTab.value === 'found' ? '/lost-found/found' : '/lost-found/lost'
    const res = await api.get(url, {
      params: {
        keyword: keyword.value,
        page: 1,
        pageSize: 20
      }
    })

    let data = res.data.data?.list || res.data.data || []

    // 计算距离的中心点
    const centerLat = searchLat.value || userLocation.value.lat
    const centerLng = searchLng.value || userLocation.value.lng

    console.log('===== 距离计算调试 =====')
    console.log('searchLat:', searchLat.value, 'searchLng:', searchLng.value)
    console.log('userLocation:', userLocation.value)
    console.log('最终使用的中心点:', centerLat, centerLng)

    if (centerLat && centerLng) {
      data = data.map(item => {
        const itemLat = parseFloat(item.latitude) || parseFloat(item.lat)
        const itemLng = parseFloat(item.longitude) || parseFloat(item.lng)

        let distance = 9999999
        if (itemLat && itemLng) {
          distance = getDistance(centerLat, centerLng, itemLat, itemLng)
        }

        console.log(`物品 ${item.id} | 坐标: ${itemLat}, ${itemLng} | 距离: ${distance}m`)
        return { ...item, distance }
      })

      data.sort((a, b) => a.distance - b.distance)
    } else {
      console.warn('没有可用的搜索中心位置')
    }

    list.value = data
  } catch (e) {
    console.error(e)
    ElMessage.error('获取列表失败')
  }
  loading.value = false
}

const submitPublish = async () => {
  if (!form.value.title || !form.value.description || !form.value.location || !form.value.time) {
    ElMessage.warning('请填写完整必填信息')
    return
  }
  submitting.value = true
  try {
    const url = activeTab.value === 'found' ? '/lost-found/found' : '/lost-found/lost'
    const payload = {
      title: form.value.title,
      description: form.value.description,
      contact_phone: form.value.contact_phone,
      longitude: form.value.longitude,
      latitude: form.value.latitude
    }

    if (activeTab.value === 'found') {
      payload.found_location = form.value.location
      payload.found_time = form.value.time
      payload.placed_at_point_id = form.value.placed_at_point_id || null
    } else {
      payload.lost_location = form.value.location
      payload.lost_time = form.value.time
    }

    const res = await api.post(url, payload)
    if (res.data.code === 200 || res.data.code === 0) {
      ElMessage.success('发布成功！')
      showPublish.value = false
      form.value = { title: '', description: '', location: '', time: '', placed_at_point_id: '', contact_phone: '' }
      loadData()
    } else {
      ElMessage.error(res.data.message || '发布失败')
    }
  } catch (e) {
    ElMessage.error(e.response?.data?.message || '发布失败')
  }
  submitting.value = false
}



const getCurrentLocation = () => {
  if (navigator.geolocation) {
    navigator.geolocation.getCurrentPosition(
      (position) => {
        userLocation.value = {
          lat: position.coords.latitude,
          lng: position.coords.longitude
        }
        console.log('✅ 当前定位成功:', userLocation.value)
        loadData() // 重新加载并排序
      },
      (error) => {
        console.warn('定位失败:', error.message)
        // 可选：使用默认位置（上海）
        userLocation.value = { lat: 31.2304, lng: 121.4737 }
        loadData()
      }
    )
  } else {
    console.warn('浏览器不支持定位')
  }
}

// 使用高德官方算距离（更准确）
const getDistance = (lat1, lng1, lat2, lng2) => {
  if (!window.AMap || !lat1 || !lng1 || !lat2 || !lng2) {
    return 9999999
  }
  try {
    return Math.round(AMap.GeometryUtil.distance([lng1, lat1], [lng2, lat2]))
  } catch (e) {
    console.error('距离计算失败', e)
    return 9999999
  }
}

const openMapPicker = () => {
  mapMode.value = 'publish'
  mapDialogVisible.value = true
  nextTick(() => {
    initMap()
  })
}



const initMap = () => {
  if (!window.AMap) {
    ElMessage.error('地图加载失败')
    return
  }

  map = new AMap.Map(mapContainer.value, {
    zoom: 16,
    viewMode: '2D'
  })

  geocoder = new AMap.Geocoder({ city: '全国' })

  // 自动获取当前定位
  const geolocation = new AMap.Geolocation({
    enableHighAccuracy: true,
    timeout: 10000,
    buttonPosition: 'RB',
    buttonOffset: new AMap.Pixel(10, 20),
    zoomToAccuracy: true
  })

  map.addControl(geolocation)

  geolocation.getCurrentPosition((status, result) => {
    if (status === 'complete') {
      const lng = result.position.getLng()
      const lat = result.position.getLat()
      map.setCenter([lng, lat])
      console.log('当前定位成功:', lng, lat)
    } else {
      console.warn('当前定位失败，使用默认位置')
      map.setCenter([121.4737, 31.2304]) // 上海默认
    }
  })

  // 点击地图选点
  map.on('click', (e) => {
    const lng = e.lnglat.getLng()
    const lat = e.lnglat.getLat()

    selectedLng.value = lng
    selectedLat.value = lat

    if (marker) {
      marker.setPosition([lng, lat])
    } else {
      marker = new AMap.Marker({
        position: [lng, lat],
        map: map
      })
    }

    geocoder.getAddress([lng, lat], (status, result) => {
      if (status === 'complete' && result.regeocode) {
        selectedAddress.value = result.regeocode.formattedAddress || `${lng.toFixed(5)}, ${lat.toFixed(5)}`
      } else {
        selectedAddress.value = `${lng.toFixed(5)}, ${lat.toFixed(5)}`
      }
    })
  })
}

// 确认选择的位置
const confirmLocation = () => {
  if (!selectedLng.value || !selectedLat.value) {
    ElMessage.warning('请先在地图上点击选择位置')
    return
  }

  form.value.location = selectedAddress.value
  form.value.longitude = selectedLng.value
  form.value.latitude = selectedLat.value

  mapDialogVisible.value = false
  ElMessage.success('位置选择成功')
  
}


const contactUser = (item) => {
  // 1. 检查是否登录
  if (!userStore.isLoggedIn) {
    ElMessage.warning('请先登录')
    router.push({ name: 'login', query: { redirect: '/lost-found' } })
    return
  }

  // 2. 获取对方用户ID（兼容不同字段名）
  const targetUserId = item.finder_user_id || item.owner_user_id || item.user_id
  const targetUserName = item.finder_name || item.owner_name || item.user_name || '对方'

  if (!targetUserId) {
    ElMessage.warning('无法获取对方信息')
    return
  }

  // 3. 不能联系自己
  if (userStore.user && userStore.user.id === targetUserId) {
    ElMessage.warning('不能联系自己')
    return
  }

  // 4. 跳转到私信页面
  router.push({
    path: '/messages',
    query: {
      to: targetUserId,
      name: targetUserName
    }
  })
}

watch(activeTab, () => {
  keyword.value = ''
  loadData()
})



// 搜索中心位置
const searchAddress = ref('')
const searchLng = ref(null)
const searchLat = ref(null)

// 打开搜索位置地图
const openSearchMap = () => {
  mapMode.value = 'search'
  mapDialogVisible.value = true
  nextTick(() => {
    initSearchMap()
  })
}

const initSearchMap = () => {
  if (!window.AMap) {
    ElMessage.error('地图加载失败')
    return
  }

  if (map) {
    map.destroy()
    map = null
  }

  map = new AMap.Map(mapContainer.value, {
    zoom: 15,
    viewMode: '2D'
  })

  geocoder = new AMap.Geocoder({ city: '全国' })

  // 默认定位到当前
  const geolocation = new AMap.Geolocation({ enableHighAccuracy: true, timeout: 8000 })
  map.addControl(geolocation)
  geolocation.getCurrentPosition((status, result) => {
    if (status === 'complete') {
      map.setCenter([result.position.getLng(), result.position.getLat()])
    }
  })

  map.on('click', (e) => {
    const lng = e.lnglat.getLng()
    const lat = e.lnglat.getLat()
    selectedLng.value = lng
    selectedLat.value = lat

    if (marker) marker.setPosition([lng, lat])
    else marker = new AMap.Marker({ position: [lng, lat], map })

    geocoder.getAddress([lng, lat], (status, result) => {
      if (status === 'complete' && result.regeocode) {
        selectedAddress.value = result.regeocode.formattedAddress
      } else {
        selectedAddress.value = `${lng.toFixed(5)}, ${lat.toFixed(5)}`
      }
    })
  })
}

// 确认搜索位置
const confirmSearchLocation = () => {
  if (!selectedLng.value) {
    ElMessage.warning('请先在地图上点击选择位置')
    return
  }
  searchAddress.value = selectedAddress.value
  searchLng.value = selectedLng.value
  searchLat.value = selectedLat.value
  mapDialogVisible.value = false
  ElMessage.success('搜索位置已设置')
  loadData()   // 重新加载并按新位置排序
}

const clearSearchLocation = () => {
  searchAddress.value = ''
  searchLng.value = null
  searchLat.value = null
  loadData()
}


const confirmMapLocation = () => {
  if (!selectedLng.value || !selectedLat.value) {
    ElMessage.warning('请先在地图上点击选择位置')
    return
  }

  if (mapMode.value === 'search') {
    // 设置搜索中心
    searchAddress.value = selectedAddress.value
    searchLng.value = selectedLng.value
    searchLat.value = selectedLat.value
    ElMessage.success('搜索位置已设置')
    loadData()
  } else {
    // 发布时选点
    form.value.location = selectedAddress.value
    form.value.longitude = selectedLng.value
    form.value.latitude = selectedLat.value
    ElMessage.success('位置选择成功')
  }

  mapDialogVisible.value = false
}

onMounted(() => {
  loadPoints()
  getCurrentLocation()   
  loadData()
})
</script>

<style scoped>
.lost-found-page {
  max-width: 1100px;
  margin: 0 auto;
}

/* ===== 横幅 ===== */
.banner {
  position: relative;
  border-radius: 20px;
  overflow: hidden;
  margin-bottom: 24px;
}
.banner-bg {
  position: absolute;
  inset: 0;
  background: linear-gradient(135deg, #6C5CE7 0%, #A29BFE 50%, #FD79A8 100%);
}
.banner-deco {
  position: absolute;
  font-size: 48px;
  opacity: 0.15;
  animation: campus-float 4s ease-in-out infinite;
}
.d1 { top: 10px; right: 10%; animation-delay: 0s; }
.d2 { bottom: 10px; left: 10%; animation-delay: 1s; }
.d3 { top: 50%; right: 5%; animation-delay: 0.5s; font-size: 36px; }
.banner-content {
  position: relative;
  padding: 36px 40px;
  color: #fff;
  z-index: 1;
}
.banner-content h1 {
  margin: 0 0 8px;
  font-size: 28px;
  font-weight: 800;
}
.banner-content p {
  margin: 0;
  font-size: 15px;
  opacity: 0.9;
}

/* ===== 操作栏 ===== */
.action-bar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  background: rgba(255,255,255,0.8);
  backdrop-filter: blur(12px);
  padding: 14px 20px;
  border-radius: 16px;
  margin-bottom: 20px;
  flex-wrap: wrap;
  gap: 12px;
  border: 1px solid rgba(240, 230, 224, 0.3);
}
.right-actions {
  display: flex;
  align-items: center;
  gap: 10px;
  flex-wrap: wrap;
}
.action-bar-btn {
  padding: 8px 18px;
  border: none;
  border-radius: 12px;
  font-size: 13px;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.3s ease;
}
.action-bar-btn:hover {
  transform: translateY(-1px);
}
.location-btn {
  background: rgba(0, 184, 148, 0.08);
  color: #00B894;
  border: 1px solid rgba(0, 184, 148, 0.15);
}
.location-btn:hover {
  background: rgba(0, 184, 148, 0.15);
}
.publish-lf-btn {
  background: linear-gradient(135deg, #FF7E67, #FD79A8);
  color: #fff;
  box-shadow: 0 4px 12px rgba(255, 126, 103, 0.2);
}
.publish-lf-btn:hover {
  box-shadow: 0 6px 20px rgba(255, 126, 103, 0.35);
}
.search-input-wrap {
  position: relative;
  display: flex;
  align-items: center;
}
.bar-search-input {
  padding: 8px 38px 8px 16px;
  border: 1px solid rgba(240, 230, 224, 0.4);
  border-radius: 12px;
  font-size: 13px;
  outline: none;
  width: 200px;
  background: #FFF8F5;
  transition: all 0.3s;
}
.bar-search-input:focus {
  border-color: #FF7E67;
  box-shadow: 0 0 0 3px rgba(255, 126, 103, 0.08);
}
.bar-search-btn {
  position: absolute;
  right: 4px;
  background: none;
  border: none;
  font-size: 16px;
  cursor: pointer;
  padding: 4px 8px;
}
.bar-clear-btn {
  position: absolute;
  right: 32px;
  background: none;
  border: none;
  font-size: 12px;
  color: #B2BEC3;
  cursor: pointer;
  padding: 4px;
}
.search-location-hint {
  margin: 8px 0 14px;
  font-size: 13px;
  color: #00B894;
  display: flex;
  align-items: center;
  gap: 8px;
}
.clear-location-btn {
  background: none;
  border: none;
  color: #8892A0;
  font-size: 12px;
  cursor: pointer;
  text-decoration: underline;
}

/* ===== 卡片网格 ===== */
.item-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(340px, 1fr));
  gap: 18px;
  min-height: 200px;
}
.item-card {
  background: #fff;
  border-radius: 16px;
  border: 1px solid rgba(240, 230, 224, 0.3);
  overflow: hidden;
  transition: all 0.35s cubic-bezier(0.25, 0.46, 0.45, 0.94);
  box-shadow: 0 2px 12px rgba(0,0,0,0.03);
}
.item-card:hover {
  transform: translateY(-4px);
  box-shadow: 0 12px 36px rgba(255, 126, 103, 0.08);
  border-color: transparent;
}
.card-badge {
  position: absolute;
  top: 14px;
  right: 14px;
  padding: 4px 14px;
  border-radius: 20px;
  font-size: 12px;
  color: #fff;
  font-weight: 600;
  box-shadow: 0 2px 8px rgba(0,0,0,0.1);
}
.card-badge.found { background: linear-gradient(135deg, #00B894, #55EFC4); }
.card-badge.lost { background: linear-gradient(135deg, #FF7E67, #FD79A8); }
.card-body { padding: 20px 18px 16px; }
.card-title {
  margin: 0 0 8px;
  font-size: 17px;
  font-weight: 700;
  color: #2D3436;
  padding-right: 70px;
}
.card-desc {
  margin: 0 0 14px;
  font-size: 13px;
  color: #636E72;
  line-height: 1.6;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}
.card-meta {
  display: flex;
  flex-direction: column;
  gap: 6px;
  margin-bottom: 16px;
}
.meta-row {
  display: flex;
  align-items: center;
  gap: 6px;
  font-size: 13px;
  color: #8892A0;
}
.meta-icon { font-size: 14px; }
.distance {
  font-size: 13px;
  color: #8892A0;
  font-weight: 500;
}
.card-footer {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding-top: 12px;
  border-top: 1px solid #F5F0EC;
}
.card-img {
  height: 160px;
  position: relative;
  overflow: hidden;
  background: #FFF8F5;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 40px;
}
.card-img-real {
  width: 100%;
  height: 100%;
  object-fit: cover;
  transition: transform 0.4s;
}
.item-card:hover .card-img-real {
  transform: scale(1.06);
}
.card-img-placeholder {
  font-size: 40px;
}
</style>