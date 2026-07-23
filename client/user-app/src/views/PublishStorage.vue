<template>
  <div class="publish-page">
    <el-card shadow="never">
      <template #header>
        <span style="font-size:18px;font-weight:600">
          {{ pubType === 'service' ? '📦 发布寄存服务' : '🔍 发布寄存需求' }}
        </span>
      </template>

      <!-- 类型切换 -->
      <div class="type-switch">
        <el-radio-group v-model="pubType" size="large">
          <el-radio-button value="service">🏠 我提供寄存空间</el-radio-button>
          <el-radio-button value="request">🔍 我寻找寄存空间</el-radio-button>
        </el-radio-group>
      </div>

      <el-form :model="form" ref="formRef" label-width="100px" style="max-width:560px;margin-top:20px">

        <el-form-item label="标题" prop="title" required>
          <el-input v-model="form.title"
            :placeholder="pubType === 'service' ? '如：延长校区南区宿舍楼下电动车寄存' : '如：求暑假行李寄存空间'"
            maxlength="200" show-word-limit />
        </el-form-item>

        <el-form-item :label="pubType === 'service' ? '寄存类型' : '物品类型'" required>
          <el-select v-model="form.item_type" placeholder="请选择类型" style="width:100%">
            <el-option label="🛵 电动车" value="bike" />
            <el-option label="🧳 行李" value="suitcase" />
            <el-option label="📚 书籍" value="book" />
            <el-option label="🔌 小型电器" value="appliance" />
            <el-option label="📦 其他" value="other" />
          </el-select>
        </el-form-item>

        <el-form-item label="校区" required>
          <el-select v-model="form.campus" placeholder="请选择校区" style="width:100%">
            <el-option label="宝山校区" value="宝山校区" />
            <el-option label="延长校区" value="延长校区" />
            <el-option label="嘉定校区" value="嘉定校区" />
            <el-option label="沪东校区" value="沪东校区" />
          </el-select>
        </el-form-item>

        <el-form-item label="具体位置" v-if="pubType === 'service'">
          <el-input v-model="form.location" placeholder="如：南区12号楼附近" />
        </el-form-item>

        <el-form-item label="详细说明" v-if="pubType === 'service'">
          <el-input v-model="form.location_detail" type="textarea" :rows="2"
            placeholder="更详细的位置描述，如：进校门后直走200米，右手边车棚" />
        </el-form-item>

        <el-form-item label="描述">
          <el-input v-model="form.description" type="textarea" :rows="3"
            :placeholder="pubType === 'service' ? '描述你的寄存空间条件...' : '描述你需要寄存的物品和要求...'" />
        </el-form-item>

        <el-form-item :label="pubType === 'service' ? '可存时间' : '预期时间'">
          <div style="display:flex;gap:10px;align-items:center">
            <el-date-picker v-model="form.start_time" type="date" placeholder="开始日期"
              value-format="YYYY-MM-DD" style="width:170px" />
            <span>至</span>
            <el-date-picker v-model="form.end_time" type="date" placeholder="结束日期"
              value-format="YYYY-MM-DD" style="width:170px" />
          </div>
        </el-form-item>

        <el-form-item :label="pubType === 'service' ? '价格（元/月）' : '预算（元）'">
          <el-input-number v-model="form.price" :min="0" :precision="0" style="width:180px" />
          <span style="margin-left:8px;color:#909399">{{ pubType === 'service' ? '元/月' : '元以内' }}</span>
        </el-form-item>

        <el-form-item label="容量" v-if="pubType === 'service'">
          <el-input-number v-model="form.capacity" :min="1" :max="99" style="width:140px" />
          <span style="margin-left:8px;color:#909399">个位置</span>
        </el-form-item>

        <el-form-item label="联系方式">
          <el-input v-model="form.contact_info" placeholder="如：微信 campus_helper 或 手机号" maxlength="200" />
          <div class="form-tip">建议填写微信号或手机号，方便对方联系你</div>
        </el-form-item>

        <el-form-item>
          <el-button type="primary" :loading="loading" @click="handlePublish" size="large">
            {{ pubType === 'service' ? '发布寄存服务' : '发布寄存需求' }}
          </el-button>
          <el-button @click="router.back()" size="large">取消</el-button>
        </el-form-item>
      </el-form>
    </el-card>
  </div>
</template>

<script setup>
import { ref } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { ElMessage } from 'element-plus'
import api from '@/api'

const router = useRouter()
const route = useRoute()
const loading = ref(false)
const formRef = ref(null)

const pubType = ref(route.query.type === 'request' ? 'request' : 'service')

const form = ref({
  title: '', item_type: '', campus: '', location: '', location_detail: '',
  description: '', start_time: null, end_time: null, price: null,
  capacity: 1, contact_info: ''
})

const handlePublish = async () => {
  if (!form.value.title || !form.value.item_type || !form.value.campus) {
    return ElMessage.warning('请填写标题、类型和校区')
  }
  loading.value = true
  try {
    const isService = pubType.value === 'service'
    const payload = {
      title: form.value.title,
      [isService ? 'storage_type' : 'item_type']: form.value.item_type,
      campus: form.value.campus,
      description: form.value.description,
      contact_info: form.value.contact_info,
      location: form.value.location
    }

    if (isService) {
      payload.price_per_month = form.value.price || null
      payload.capacity = form.value.capacity || 1
      payload.start_time = form.value.start_time || null
      payload.end_time = form.value.end_time || null
      payload.location_detail = form.value.location_detail
    } else {
      payload.budget = form.value.price || null
      payload.expected_start_time = form.value.start_time || null
      payload.expected_end_time = form.value.end_time || null
    }

    const url = isService ? '/storage-services' : '/storage-requests'
    const res = await api.post(url, payload)
    if (res.data.code === 0) {
      ElMessage.success('发布成功！')
      router.push(isService ? '/storage-services' : '/storage-requests')
    }
  } catch (e) {
    ElMessage.error(e.response?.data?.message || '发布失败')
  }
  loading.value = false
}
</script>

<style scoped>
.publish-page { max-width: 700px; margin: 0 auto; }
.type-switch { text-align: center; margin-bottom: 8px; }
.form-tip { font-size: 12px; color: #909399; margin-top: 4px; }
</style>
