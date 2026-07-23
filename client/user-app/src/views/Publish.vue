<template>
  <div class="publish-page">
    <el-card shadow="never">
      <template #header>
        <div style="display:flex;align-items:center;gap:8px">
          <el-icon :size="20"><EditPen /></el-icon>
          <span style="font-size:18px;font-weight:600">
            {{ isEdit ? '编辑商品' : '发布商品' }}
          </span>
        </div>
      </template>

      <el-form :model="form" :rules="rules" ref="formRef" label-width="90px" style="max-width:600px">
        <el-form-item label="商品标题" prop="title">
          <el-input v-model="form.title" placeholder="请输入商品标题" maxlength="100" show-word-limit />
        </el-form-item>

        <el-form-item label="商品分类" prop="category_id">
          <el-select v-model="form.category_id" placeholder="请选择分类" style="width:100%">
            <el-option v-for="cat in categories" :key="cat.id" :label="cat.name" :value="cat.id" />
          </el-select>
        </el-form-item>

        <el-form-item label="参加活动">
          <el-select v-model="form.activity_id" placeholder="选择参加校园活动（可选）" style="width:100%" clearable>
            <el-option label="不参加活动" :value="null" />
            <el-option v-for="act in activities" :key="act.id" :label="act.name" :value="act.id" />
          </el-select>
        </el-form-item>

        <el-form-item label="价格" prop="price">
          <el-input-number v-model="form.price" :min="0.01" :precision="2" :step="10" style="width:200px" />
          <span style="margin-left:8px;color:#909399">元</span>
        </el-form-item>

        <el-form-item label="商品数量" prop="quantity">
          <el-input-number v-model="form.quantity" :min="1" :max="999" :precision="0" :step="1" style="width:160px" />
          <span style="margin-left:8px;color:#909399">件（数量归零时自动下架）</span>
        </el-form-item>

        <el-form-item label="商品描述" prop="description">
          <el-input v-model="form.description" type="textarea" :rows="5" placeholder="详细描述你的商品..." />
        </el-form-item>

        <!-- 期望收货地址 -->
        <el-form-item label="期望交易地址">
        <div style="display: flex; gap: 8px; width: 100%;">
         <el-input
           v-model="form.expected_address"
           placeholder="请点击右侧按钮在地图上选择期望交易位置"
           readonly
          />
         <el-button type="primary" @click="openMapPicker">地图选点</el-button>
        </div>
        <div v-if="form.expected_longitude" style="margin-top: 6px; font-size: 12px; color: #909399;">
         坐标：{{ form.expected_longitude.toFixed(6) }}, {{ form.expected_latitude.toFixed(6) }}
        </div>
      </el-form-item>
        <!-- 自定义标签 -->
        <el-form-item label="自定义标签">
          <div class="tag-wrapper">
            <el-tag
              v-for="(tag, index) in tags"
              :key="index"
              closable
              @close="removeTag(index)"
              style="margin-right: 8px; margin-bottom: 8px"
            >
              #{{ tag }}
            </el-tag>
            <el-input
              v-model="tagInput"
              placeholder="输入标签后回车添加"
              style="width: 200px; margin-right: 8px"
              @keyup.enter="addTag"
              :disabled="tags.length >= 5"
            />
            <el-button type="primary" @click="addTag" :disabled="tags.length >= 5 || !tagInput.trim()">
              添加
            </el-button>
          </div>
          <div style="font-size: 12px; color: #909399; margin-top: 4px;">
            最多可添加 5 个标签
          </div>
        </el-form-item>

        <!-- 商品图片 -->
        <el-form-item label="商品图片">
          <el-upload
            :action="uploadUrl"
            :headers="uploadHeaders"
            :on-success="handleUploadSuccess"
            :on-remove="handleUploadRemove"
            :file-list="fileList"
            list-type="picture-card"
            accept="image/*"
            :limit="5"
          >
            <el-icon><Plus /></el-icon>
          </el-upload>
          <div class="upload-tip">最多上传 5 张图片</div>
        </el-form-item>

        <el-form-item>
          <el-button type="primary" :loading="loading" @click="handlePublish" size="large">
            {{ isEdit ? '保存修改' : '发布商品' }}
          </el-button>
          <el-button @click="router.back()" size="large">取消</el-button>
        </el-form-item>
      </el-form>
    </el-card>
    <!-- 地图选点弹窗 -->
    <el-dialog
      v-model="mapDialogVisible"
      title="选择期望交易地址"
      width="700px"
      destroy-on-close
      @closed="() => { if (map) { map.destroy(); map = null; marker = null } }"
    >
      <div ref="mapContainer" style="width: 100%; height: 420px; border-radius: 8px;"></div>
      <div style="margin-top: 12px; padding: 10px; background: #f5f7fa; border-radius: 6px;">
        <div v-if="selectedAddress">
          <strong>当前选择：</strong>{{ selectedAddress }}
        </div>
        <div v-else style="color: #909399;">请在地图上点击选择位置</div>
      </div>
      <template #footer>
        <el-button @click="mapDialogVisible = false">取消</el-button>
        <el-button type="primary" @click="confirmLocation">确认位置</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, nextTick } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { ElMessage } from 'element-plus'
import { EditPen, Plus } from '@element-plus/icons-vue'
import api from '@/api'

const router = useRouter()
const route = useRoute()

const formRef = ref(null)
const loading = ref(false)
const categories = ref([])
const activities = ref([])
const fileList = ref([])
const uploadedImages = ref([])
const tags = ref([])
const tagInput = ref('')

const uploadUrl = 'http://localhost:3000/api/upload'
const uploadHeaders = computed(() => ({
  Authorization: `Bearer ${localStorage.getItem('client_token')}`
}))

const form = ref({
  title: '',
  category_id: '',
  activity_id: null,
  price: null,
  quantity: 1,
  description: '',
  expected_address: '',
  expected_longitude: null,
  expected_latitude: null
})
const rules = {
  title: [{ required: true, message: '请输入商品标题', trigger: 'blur' }],
  category_id: [{ required: true, message: '请选择分类', trigger: 'change' }],
  price: [{ required: true, message: '请输入价格', trigger: 'blur' }],
  quantity: [{ required: true, message: '请输入数量', trigger: 'blur' }]
}

const isEdit = computed(() => !!route.query.id)
const editItemId = computed(() => route.query.id)

const fetchCategories = async () => {
  try {
    const res = await api.get('/categories')
    categories.value = res.data.code === 0 ? res.data.data : res.data
  } catch (e) {
    console.error(e)
  }
}

const fetchActivities = async () => {
  try {
    const res = await api.get('/activities')
    if (res.data.code === 0) activities.value = res.data.data
  } catch (e) { /* ignore */ }
}


// 加载商品用于编辑
const loadItemForEdit = async () => {
  if (!editItemId.value) return
  loading.value = true
  try {
    const res = await api.get(`/items/${editItemId.value}`)
    if (res.data.code === 0 && res.data.data) {
      const item = res.data.data

      form.value = {
        title: item.title || '',
        category_id: item.category_id || '',
        activity_id: item.activity_id || null,
        price: item.price || null,
        quantity: item.quantity || 1,
        description: item.description || '',
        expected_address: item.expected_address || '',
        expected_longitude: item.expected_longitude || null,
        expected_latitude: item.expected_latitude || null
      }

      if (item.images && item.images.length > 0) {
        uploadedImages.value = item.images.map(img => img.url || img)
        fileList.value = item.images.map((img, index) => ({
          name: `img${index}`,
          url: (img.url || img).startsWith('http') 
            ? (img.url || img) 
            : `http://localhost:3000${img.url || img}`
        }))
      }

      // 加载标签
      try {
        const tagRes = await api.get(`/items/${editItemId.value}/tags`)
        if (tagRes.data.code === 0) {
          tags.value = tagRes.data.data || []
        }
      } catch (e) {}
    } else {
      ElMessage.error('商品不存在')
      router.back()
    }
  } catch (e) {
    ElMessage.error('加载商品失败')
    router.back()
  } finally {
    loading.value = false
  }
}

const handleUploadSuccess = (response) => {
  if (response.code === 0) uploadedImages.value.push(response.data.url)
}

const handleUploadRemove = (file) => {
  if (file.response?.data?.url) {
    uploadedImages.value = uploadedImages.value.filter(u => u !== file.response.data.url)
  }
}

const addTag = () => {
  const value = tagInput.value.trim()
  if (!value || tags.value.includes(value)) return
  if (tags.value.length >= 5) return ElMessage.warning('最多只能添加 5 个标签')
  tags.value.push(value)
  tagInput.value = ''
}

const removeTag = (index) => {
  tags.value.splice(index, 1)
}

const handlePublish = async () => {
  const valid = await formRef.value?.validate().catch(() => false)
  if (!valid) return

  loading.value = true
  try {
    const payload = {
      ...form.value,
      activity_id: form.value.activity_id || null,
      images: uploadedImages.value,
      tags: tags.value
    }

    console.log('【前端提交】payload 中的地址信息：', {
  expected_address: payload.expected_address,
  expected_longitude: payload.expected_longitude,
  expected_latitude: payload.expected_latitude
})

    let res
    if (isEdit.value) {
      res = await api.put(`/items/${editItemId.value}`, payload)
    } else {
      res = await api.post('/items', payload)
    }

    if (res.data.code === 0) {
      ElMessage.success(isEdit.value ? '修改成功，等待重新审核' : '发布成功，等待审核')
      router.push('/profile')
    } else {
      ElMessage.error(res.data.message || '操作失败')
    }
  } catch (e) {
    ElMessage.error(e.response?.data?.message || '操作失败')
  } finally {
    loading.value = false
  }
}

// ==================== 地图选点相关 ====================
const mapDialogVisible = ref(false)
const mapContainer = ref(null)
let map = null
let marker = null
let geocoder = null
const selectedAddress = ref('')
const selectedLng = ref(null)
const selectedLat = ref(null)

const openMapPicker = () => {
  mapDialogVisible.value = true
  nextTick(() => {
    initMap()
  })
}

const initMap = () => {
  if (!window.AMap) {
    ElMessage.error('地图加载失败，请检查高德Key')
    return
  }

  if (map) {
    map.destroy()
    map = null
  }

  map = new AMap.Map(mapContainer.value, {
    zoom: 16,
    viewMode: '2D'
  })

  geocoder = new AMap.Geocoder({ city: '全国' })

  // 自动定位到当前位置
  const geolocation = new AMap.Geolocation({
    enableHighAccuracy: true,
    timeout: 10000
  })
  map.addControl(geolocation)
  geolocation.getCurrentPosition((status, result) => {
    if (status === 'complete') {
      map.setCenter([result.position.getLng(), result.position.getLat()])
    } else {
      map.setCenter([121.4737, 31.2304]) // 上海默认
    }
  })

  map.on('click', (e) => {
    const lng = e.lnglat.getLng()
    const lat = e.lnglat.getLat()
    selectedLng.value = lng
    selectedLat.value = lat

    if (marker) {
      marker.setPosition([lng, lat])
    } else {
      marker = new AMap.Marker({ position: [lng, lat], map })
    }

    geocoder.getAddress([lng, lat], (status, result) => {
      if (status === 'complete' && result.regeocode) {
        selectedAddress.value = result.regeocode.formattedAddress
      } else {
        selectedAddress.value = `${lng.toFixed(5)}, ${lat.toFixed(5)}`
      }
    })
  })
}

const confirmLocation = () => {
  if (!selectedLng.value) {
    ElMessage.warning('请先在地图上点击选择位置')
    return
  }
  form.value.expected_address = selectedAddress.value
  form.value.expected_longitude = selectedLng.value
  form.value.expected_latitude = selectedLat.value
  mapDialogVisible.value = false
  ElMessage.success('位置选择成功')
}


onMounted(() => {
  fetchCategories()
  fetchActivities()
  if (isEdit.value) {
    loadItemForEdit()
  }
})
</script>

<style scoped>
.publish-page { max-width: 800px; margin: 0 auto; }
.upload-tip { font-size: 12px; color: #909399; margin-top: 4px; }
.tag-wrapper { display: flex; flex-wrap: wrap; align-items: center; gap: 8px; }
</style>