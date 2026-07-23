<template>
  <div class="storage-page">
    <h2>🏠 寒暑假闲置寄存</h2>
    <el-tabs v-model="activeTab" @tab-change="fetchData">
      <el-tab-pane label="寄存服务" name="services" />
      <el-tab-pane label="寄存需求" name="requests" />
    </el-tabs>

    <div class="filter-bar">
      <el-radio-group v-model="typeFilter" @change="fetchData" size="default">
        <el-radio-button value="">全部</el-radio-button>
        <el-radio-button value="bike">🛵 电动车</el-radio-button>
        <el-radio-button value="suitcase">🧳 行李</el-radio-button>
        <el-radio-button value="fridge">❄️ 冰箱</el-radio-button>
        <el-radio-button value="other">📦 其他</el-radio-button>
      </el-radio-group>
      <el-button type="primary" @click="router.push('/publish-storage')">
        <el-icon><Plus /></el-icon> 发布
      </el-button>
    </div>

    <div v-loading="loading">
      <el-empty v-if="list.length === 0 && !loading" description="暂无数据" />
      <div class="list-grid">
        <el-card v-for="item in list" :key="item.id" class="list-card" shadow="hover">
          <div class="card-top">
            <h4>{{ item.title }}</h4>
            <el-tag size="small">{{ typeLabel(activeTab === 'services' ? item.storage_type : item.item_type) }}</el-tag>
          </div>
          <div class="card-mid" v-if="item.description">{{ item.description }}</div>
          <div class="card-meta">
            <span v-if="activeTab === 'services' && item.price_per_month">
              <strong>¥{{ item.price_per_month }}/月</strong>
            </span>
            <span v-if="activeTab === 'requests' && item.budget">
              预算 <strong>¥{{ item.budget }}</strong>
            </span>
            <span>{{ item.campus || (activeTab === 'services' ? item.provider_campus : item.requester_campus) }}</span>
            <span>{{ activeTab === 'services' ? item.provider_name : item.requester_name }}</span>
          </div>
        </el-card>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { Plus } from '@element-plus/icons-vue'
import api from '@/api'

const router = useRouter()
const activeTab = ref('services')
const typeFilter = ref('')
const list = ref([])
const loading = ref(false)

const typeLabel = (t) => ({ bike: '电动车', suitcase: '行李', fridge: '冰箱', other: '其他' }[t] || t)

const fetchData = async () => {
  loading.value = true
  try {
    const baseUrl = activeTab.value === 'services' ? '/storage-services' : '/storage-services/requests'
    const params = {}
    if (typeFilter.value) {
      params[activeTab.value === 'services' ? 'storage_type' : 'item_type'] = typeFilter.value
    }
    const res = await api.get(baseUrl, { params })
    if (res.data.code === 0) list.value = res.data.data.list || res.data.data
  } catch (e) { console.error(e) }
  loading.value = false
}

fetchData()
</script>

<style scoped>
.storage-page { max-width: 1000px; margin: 0 auto; }
.filter-bar { display: flex; align-items: center; justify-content: space-between; margin-bottom: 16px; gap: 12px; }
.list-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(300px, 1fr)); gap: 12px; }
.list-card { cursor: default; }
.card-top { display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px; }
.card-top h4 { margin: 0; font-size: 15px; }
.card-mid { font-size: 13px; color: #909399; margin-bottom: 8px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.card-meta { display: flex; gap: 12px; font-size: 12px; color: #c0c4cc; }
.card-meta strong { color: #f56c6c; }
</style>
