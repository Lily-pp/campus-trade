<template>
  <div class="auth-page">
    <!-- 装饰元素 -->
    <div class="auth-deco">
      <div class="floating-circle c1"></div>
      <div class="floating-circle c2"></div>
      <div class="floating-circle c3"></div>
      <div class="auth-deco-emoji e1">🎒</div>
      <div class="auth-deco-emoji e2">🌟</div>
      <div class="auth-deco-emoji e3">🌱</div>
    </div>

    <div class="auth-card">
      <div class="auth-logo">

        <span class="auth-logo-text">CampusTrade</span>
      </div>
      <h2>加入我们 🎉</h2>
      <p class="auth-subtitle">注册成为校园大家庭的一员</p>

      <el-form :model="form" @keyup.enter="handleRegister">
        <el-form-item>
          <el-input v-model="form.username" placeholder="用户名（3-20个字符）" :prefix-icon="User" size="large" />
        </el-form-item>
        <el-form-item>
          <el-input v-model="form.password" type="password" placeholder="设置密码" :prefix-icon="Lock" show-password size="large" />
        </el-form-item>
        <el-form-item>
          <el-input v-model="form.confirmPassword" type="password" placeholder="确认密码" :prefix-icon="Lock" show-password size="large" />
        </el-form-item>
        <el-form-item>
          <el-input v-model="form.real_name" placeholder="真实姓名（选填）" size="large">
            <template #prefix><span style="font-size:16px">👤</span></template>
          </el-input>
        </el-form-item>
        <el-form-item>
          <el-input v-model="form.campus" placeholder="所在校区（选填）" size="large">
            <template #prefix><span style="font-size:16px">📍</span></template>
          </el-input>
        </el-form-item>
        <el-form-item>
          <el-button
            class="auth-submit-btn"
            :loading="loading"
            @click="handleRegister"
            size="large"
            style="width:100%"
          >
            {{ loading ? '注册中...' : '🎉 立即注册' }}
          </el-button>
        </el-form-item>
      </el-form>

      <div class="auth-footer">
        已有账号？<router-link to="/login">去登录 →</router-link>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { ElMessage } from 'element-plus'
import { User, Lock } from '@element-plus/icons-vue'
import { useUserStore } from '@/stores/user'

const router = useRouter()
const userStore = useUserStore()
const loading = ref(false)
const form = ref({
  username: '',
  password: '',
  confirmPassword: '',
  real_name: '',
  campus: ''
})

const handleRegister = async () => {
  const { username, password, confirmPassword, real_name, campus } = form.value
  if (!username || !password) {
    ElMessage.warning('用户名和密码不能为空')
    return
  }
  if (username.length < 3 || username.length > 20) {
    ElMessage.warning('用户名长度需在 3-20 个字符之间')
    return
  }
  if (password !== confirmPassword) {
    ElMessage.warning('两次密码输入不一致')
    return
  }
  loading.value = true
  try {
    const result = await userStore.register({ username, password, real_name, campus })
    if (result.code === 0) {
      ElMessage.success('🎉 注册成功！欢迎加入 CampusTrade ~')
      router.push('/')
    } else {
      ElMessage.error(result.message || '注册失败')
    }
  } catch (error) {
    ElMessage.error(error.response?.data?.message || '注册失败')
  } finally {
    loading.value = false
  }
}
</script>

<style scoped>
.auth-page {
  min-height: 100vh;
  display: flex;
  justify-content: center;
  align-items: center;
  background: linear-gradient(135deg, #FFF0EB 0%, #FFE8EE 30%, #F0E8FF 70%, #E8FFF5 100%);
  position: relative;
  overflow: hidden;
}
.auth-deco {
  position: absolute;
  inset: 0;
  pointer-events: none;
}
.floating-circle {
  position: absolute;
  border-radius: 50%;
  opacity: 0.15;
}
.c1 {
  width: 300px; height: 300px;
  background: linear-gradient(135deg, #FF7E67, #FD79A8);
  top: -80px; left: -60px;
  animation: campus-float 6s ease-in-out infinite;
}
.c2 {
  width: 200px; height: 200px;
  background: linear-gradient(135deg, #6C5CE7, #A29BFE);
  bottom: -40px; right: -60px;
  animation: campus-float 8s ease-in-out infinite reverse;
}
.c3 {
  width: 150px; height: 150px;
  background: linear-gradient(135deg, #00B894, #55EFC4);
  top: 40%; left: 60%;
  animation: campus-float 7s ease-in-out infinite 1s;
}
.auth-deco-emoji {
  position: absolute;
  font-size: 40px;
  opacity: 0.2;
}
.e1 { top: 12%; right: 10%; animation: campus-float 5s ease-in-out infinite; }
.e2 { bottom: 25%; left: 8%; animation: campus-float 6s ease-in-out infinite 0.5s; }
.e3 { top: 50%; right: 5%; animation: campus-float 4s ease-in-out infinite 1s; }

.auth-card {
  width: 420px;
  padding: 44px 40px 36px;
  background: rgba(255, 255, 255, 0.95);
  backdrop-filter: blur(20px);
  border-radius: 24px;
  box-shadow: 0 20px 60px rgba(255, 126, 103, 0.1);
  border: 1px solid rgba(255, 255, 255, 0.6);
  position: relative;
  z-index: 1;
}
.auth-logo {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  margin-bottom: 20px;
}
.auth-logo-text {
  font-size: 22px;
  font-weight: 800;
  background: linear-gradient(135deg, #FF7E67, #FD79A8);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
}
h2 {
  text-align: center;
  margin: 0 0 6px;
  color: #2D3436;
  font-size: 26px;
  font-weight: 700;
}
.auth-subtitle {
  text-align: center;
  color: #8892A0;
  font-size: 14px;
  margin: 0 0 28px;
}
.auth-page :deep(.el-input__wrapper) {
  background: #FFF8F5;
  border-radius: 14px !important;
  padding: 4px 16px;
}
.auth-page :deep(.el-input--large) {
  --el-input-height: 48px;
}
.auth-submit-btn {
  height: 48px !important;
  border-radius: 14px !important;
  font-size: 16px !important;
  font-weight: 700 !important;
  letter-spacing: 1px;
  background: linear-gradient(135deg, #FF7E67, #FD79A8) !important;
  border: none !important;
  box-shadow: 0 6px 20px rgba(255, 126, 103, 0.3) !important;
  transition: all 0.3s ease !important;
}
.auth-submit-btn:hover {
  transform: translateY(-2px) !important;
  box-shadow: 0 8px 30px rgba(255, 126, 103, 0.4) !important;
}
.auth-footer {
  text-align: center;
  margin-top: 20px;
  font-size: 14px;
  color: #8892A0;
}
.auth-footer a {
  color: #FF7E67;
  text-decoration: none;
  font-weight: 600;
  transition: all 0.2s;
}
.auth-footer a:hover { color: #FD79A8; }
</style>
