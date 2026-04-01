<template>
  <div class="publish-page">
    <el-card shadow="never">
      <template #header>
        <div style="display:flex;align-items:center;gap:8px">
          <el-icon :size="20"><EditPen /></el-icon>
          <span style="font-size:18px;font-weight:600">发布商品</span>
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

        <el-form-item label="价格" prop="price">
          <el-input-number v-model="form.price" :min="0.01" :precision="2" :step="10" style="width:200px" />
          <span style="margin-left:8px;color:#909399">元</span>
        </el-form-item>

        <el-form-item label="商品数量" prop="quantity">
          <el-input-number v-model="form.quantity" :min="1" :max="999" :precision="0" :step="1" style="width:160px" />
          <span style="margin-left:8px;color:#909399">件（数量归零时自动下架）</span>
        </el-form-item>

        <el-form-item label="商品描述" prop="description">
          <el-input v-model="form.description" type="textarea" :rows="5" placeholder="详细描述你的商品，成色、购买时间、使用情况等" />
        </el-form-item>

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
          <div class="upload-tip">最多上传 5 张图片，支持 jpg/png 格式</div>
        </el-form-item>

        <el-form-item>
          <el-button type="primary" :loading="loading" @click="handlePublish" size="large">
            发布商品
          </el-button>
          <el-button @click="router.back()" size="large">取消</el-button>
        </el-form-item>
      </el-form>
    </el-card>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { ElMessage } from 'element-plus'
import { EditPen, Plus } from '@element-plus/icons-vue'
import api from '@/api'

const router = useRouter()
const formRef = ref(null)
const loading = ref(false)
const categories = ref([])
const fileList = ref([])
const uploadedImages = ref([])

const uploadUrl = 'http://localhost:3000/api/upload'
const uploadHeaders = computed(() => ({
  Authorization: `Bearer ${localStorage.getItem('client_token')}`
}))

const form = ref({
  title: '',
  category_id: '',
  price: null,
  quantity: 1,
  description: ''
})

const rules = {
  title: [{ required: true, message: '请输入商品标题', trigger: 'blur' }],
  category_id: [{ required: true, message: '请选择分类', trigger: 'change' }],
  price: [{ required: true, message: '请输入价格', trigger: 'blur' }],
  quantity: [{ required: true, message: '请输入数量', trigger: 'blur' }]
}

const fetchCategories = async () => {
  try {
    const res = await api.get('/categories')
    categories.value = res.data.code === 0 ? res.data.data : res.data
  } catch (e) {
    console.error(e)
  }
}

const handleUploadSuccess = (response) => {
  if (response.code === 0) {
    uploadedImages.value.push(response.data.url)
  } else {
    ElMessage.error('图片上传失败')
  }
}

const handleUploadRemove = (file) => {
  if (file.response?.data?.url) {
    uploadedImages.value = uploadedImages.value.filter(u => u !== file.response.data.url)
  }
}

const handlePublish = async () => {
  const valid = await formRef.value?.validate().catch(() => false)
  if (!valid) return

  loading.value = true
  try {
    const payload = { ...form.value, images: uploadedImages.value }
    const res = await api.post('/items', payload)
    if (res.data.code === 0) {
      ElMessage.success('发布成功，等待审核')
      router.push('/profile')
    } else {
      ElMessage.error(res.data.message || '发布失败')
    }
  } catch (e) {
    ElMessage.error(e.response?.data?.message || '发布失败')
  }
  loading.value = false
}

onMounted(fetchCategories)
</script>

<style scoped>
.publish-page { max-width: 800px; margin: 0 auto; }
.upload-tip { font-size: 12px; color: #909399; margin-top: 4px; }
</style>
