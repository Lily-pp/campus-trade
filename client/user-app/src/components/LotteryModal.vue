<template>
  <el-dialog
    v-model="visible"
    title="🎉 恭喜成交！抽取校园代金券"
    width="460px"
    :close-on-click-modal="false"
    :close-on-press-escape="false"
    :show-close="!spinning"
    center
  >
    <div class="lottery-container">
      <!-- 转盘 -->
      <div class="wheel-wrapper">
        <div class="wheel-pointer">▼</div>
        <div class="wheel" :class="{ spinning }" :style="wheelStyle">
          <div
            v-for="(item, index) in segments"
            :key="index"
            class="wheel-segment"
            :style="segmentStyle(index)"
          >
            <span class="segment-label">{{ item.label }}</span>
          </div>
        </div>
      </div>

      <!-- 结果展示 -->
      <div v-if="result" class="lottery-result">
        <div class="result-amount">
          <span class="result-label">恭喜获得</span>
          <span class="result-value">¥{{ result.amount }}</span>
          <span class="result-label">校园代金券</span>
        </div>
        <div class="result-detail">
          订单金额 ¥{{ result.order_price }}，获得 {{ result.random_rate }} 代金券<br/>
          有效期 30 天，可在购买官方活动商品时使用
        </div>
      </div>

      <!-- 未抽奖状态 -->
      <div v-else class="lottery-intro">
        <p>订单已完成，快来抽取校园代金券吧！</p>
        <p class="intro-detail">随机获得成交金额的 5%~10% 代金券</p>
      </div>
    </div>

    <template #footer>
      <div v-if="!result">
        <el-button @click="handleClose" :disabled="spinning">下次再说</el-button>
        <el-button type="primary" @click="handleSpin" :loading="spinning" size="large">
          {{ spinning ? '抽奖中...' : '🎰 立即抽奖' }}
        </el-button>
      </div>
      <div v-else>
        <el-button type="primary" @click="handleClose" size="large">知道了</el-button>
      </div>
    </template>
  </el-dialog>
</template>

<script setup>
import { ref, computed, watch } from 'vue'
import api from '@/api'

const props = defineProps({
  modelValue: { type: Boolean, default: false },
  orderId: { type: [Number, String], default: null }
})

const emit = defineEmits(['update:modelValue', 'done'])

const visible = computed({
  get: () => props.modelValue,
  set: (v) => emit('update:modelValue', v)
})

const spinning = ref(false)
const result = ref(null)
const wheelAngle = ref(0)

// 8个转盘分区
const segments = [
  { label: '5%', color: '#f56c6c' },
  { label: '6%', color: '#e6a23c' },
  { label: '7%', color: '#67c23a' },
  { label: '8%', color: '#409eff' },
  { label: '9%', color: '#f56c6c' },
  { label: '10%', color: '#e6a23c' },
  { label: '5%', color: '#67c23a' },
  { label: '7%', color: '#409eff' }
]

const colors = ['#f56c6c', '#e6a23c', '#67c23a', '#409eff', '#f56c6c', '#e6a23c', '#67c23a', '#409eff']

const wheelStyle = computed(() => ({
  transform: `rotate(${wheelAngle.value}deg)`
}))

const segmentStyle = (index) => {
  const deg = 360 / segments.length
  const rotate = index * deg
  return {
    transform: `rotate(${rotate}deg)`,
    background: colors[index],
    clipPath: `polygon(0 0, ${50 - Math.tan((deg/2) * Math.PI/180) * 50}% 0, 100% 100%, 0% 100%)`
  }
}

const handleSpin = async () => {
  if (spinning.value) return
  spinning.value = true
  result.value = null

  try {
    // 调用抽奖API
    const res = await api.post(`/vouchers/lottery/${props.orderId}`)
    if (res.data.code !== 0) {
      throw new Error(res.data.message || '抽奖失败')
    }

    const data = res.data.data

    // 确定目标分区（根据随机比例匹配转盘分区）
    const targetRate = parseFloat(data.random_rate) / 100
    let targetIndex = 0
    let minDiff = Infinity
    segments.forEach((seg, i) => {
      const segRate = parseInt(seg.label) / 100
      const diff = Math.abs(segRate - targetRate)
      if (diff < minDiff) {
        minDiff = diff
        targetIndex = i
      }
    })

    // 旋转动画：至少转5圈 + 定位到目标分区
    const segmentDeg = 360 / segments.length
    const targetDeg = 360 * 5 + (360 - targetIndex * segmentDeg - segmentDeg / 2)
    wheelAngle.value += targetDeg

    // 等待动画结束
    await new Promise(resolve => setTimeout(resolve, 3000))

    result.value = {
      amount: data.voucher.amount,
      order_price: data.order_price,
      random_rate: data.random_rate
    }

    emit('done', data.voucher)
  } catch (e) {
    console.error('抽奖失败', e)
    // 即使失败也停止动画
    spinning.value = false
  }
}

const handleClose = () => {
  visible.value = false
  spinning.value = false
  result.value = null
}

watch(() => props.modelValue, (val) => {
  if (!val) {
    spinning.value = false
    result.value = null
  }
})
</script>

<style scoped>
.lottery-container {
  text-align: center;
  padding: 10px 0;
}

.wheel-wrapper {
  position: relative;
  width: 260px;
  height: 260px;
  margin: 0 auto 20px;
}

.wheel-pointer {
  position: absolute;
  top: -16px;
  left: 50%;
  transform: translateX(-50%);
  font-size: 28px;
  color: #f56c6c;
  z-index: 10;
  filter: drop-shadow(0 2px 2px rgba(0,0,0,0.3));
}

.wheel {
  width: 260px;
  height: 260px;
  border-radius: 50%;
  position: relative;
  overflow: hidden;
  border: 6px solid #f56c6c;
  box-shadow: 0 0 0 4px #fef0f0, 0 4px 20px rgba(0,0,0,0.15);
  transition: transform 3s cubic-bezier(0.17, 0.67, 0.12, 0.99);
  background: conic-gradient(
    #f56c6c 0deg 45deg,
    #e6a23c 45deg 90deg,
    #67c23a 90deg 135deg,
    #409eff 135deg 180deg,
    #f56c6c 180deg 225deg,
    #e6a23c 225deg 270deg,
    #67c23a 270deg 315deg,
    #409eff 315deg 360deg
  );
}

.wheel-segment {
  position: absolute;
  width: 100%;
  height: 100%;
  top: 0;
  left: 0;
  display: flex;
  align-items: flex-start;
  justify-content: center;
  padding-top: 18px;
}

.segment-label {
  font-size: 16px;
  font-weight: bold;
  color: #fff;
  text-shadow: 0 1px 3px rgba(0,0,0,0.3);
  transform: rotate(22.5deg);
  display: block;
  margin-top: 10px;
}

.lottery-intro p {
  margin: 8px 0;
  color: #606266;
  font-size: 15px;
}
.intro-detail {
  color: #f56c6c !important;
  font-size: 14px !important;
}

.lottery-result {
  padding: 16px 0;
}
.result-amount {
  margin-bottom: 12px;
}
.result-label {
  font-size: 15px;
  color: #606266;
}
.result-value {
  font-size: 32px;
  font-weight: bold;
  color: #f56c6c;
  margin: 0 8px;
}
.result-detail {
  font-size: 13px;
  color: #909399;
  line-height: 1.6;
}
</style>
