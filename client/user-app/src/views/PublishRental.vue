<template>
  <div class="publish-page">
    <el-card shadow="never">
      <template #header>
        <span style="font-size:18px;font-weight:600">📦 发布转租物品</span>
      </template>

      <el-form :model="form" ref="formRef" label-width="100px" style="max-width:500px">
        <el-form-item label="物品标题" prop="title">
          <el-input v-model="form.title" placeholder="如：索尼A7M4相机出租" maxlength="200" />
        </el-form-item>
        <el-form-item label="物品分类" prop="category">
          <el-select v-model="form.category" placeholder="请选择分类" style="width:100%">
            <el-option label="🛵 电动车" value="bike" />
            <el-option label="📷 相机" value="camera" />
            <el-option label="🚁 无人机" value="drone" />
            <el-option label="📽️ 投影仪" value="projector" />
            <el-option label="🏸 球拍" value="racket" />
            <el-option label="🎮 游戏机" value="console" />
            <el-option label="📦 其他" value="other" />
          </el-select>
        </el-form-item>
        <el-form-item label="描述">
          <el-input v-model="form.description" type="textarea" :rows="4" />
        </el-form-item>
        <el-form-item label="日租价格" prop="rental_price">
          <el-input-number v-model="form.rental_price" :min="0.01" :precision="2" style="width:200px" />
          <span style="margin-left:8px;color:#909399">元/天</span>
        </el-form-item>
        <el-form-item label="押金">
          <el-input-number v-model="form.deposit" :min="0" :precision="2" style="width:200px" />
          <span style="margin-left:8px;color:#909399">元</span>
        </el-form-item>
        <el-form-item label="最短租期">
          <el-input-number v-model="form.min_days" :min="1" :max="365" style="width:160px" />
          <span style="margin-left:8px;color:#909399">天</span>
        </el-form-item>
        <el-form-item label="校区">
          <el-input v-model="form.campus" placeholder="如：宝山校区" />
        </el-form-item>
        <el-form-item label="取还位置">
          <el-input v-model="form.location" placeholder="如：5号宿舍楼" />
        </el-form-item>
        <el-form-item>
          <el-button type="primary" :loading="loading" @click="handlePublish" size="large">发布转租</el-button>
          <el-button @click="router.back()" size="large">取消</el-button>
        </el-form-item>
      </el-form>
    </el-card>
  </div>
</template>

<script setup>
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { ElMessage } from 'element-plus'
import api from '@/api'

const router = useRouter()
const loading = ref(false)
const formRef = ref(null)
const form = ref({ title: '', category: '', description: '', rental_price: null, deposit: null, min_days: 1, campus: '', location: '' })

const handlePublish = async () => {
  if (!form.value.title || !form.value.category || form.value.rental_price === null) {
    return ElMessage.warning('请填写标题、分类和日租价格')
  }
  loading.value = true
  try {
    const res = await api.post('/rental-items', form.value)
    if (res.data.code === 0) {
      ElMessage.success('发布成功')
      router.push('/rental-items')
    }
  } catch (e) {
    ElMessage.error(e.response?.data?.message || '发布失败')
  }
  loading.value = false
}
</script>

<style scoped>
.publish-page { max-width: 700px; margin: 0 auto; }
</style>
