<template>
  <div class="auth-page">
    <!-- 装饰元素 -->
    <div class="auth-deco">
      <div class="floating-circle c1"></div>
      <div class="floating-circle c2"></div>
      <div class="floating-circle c3"></div>
      <div class="auth-deco-emoji e1">📚</div>
      <div class="auth-deco-emoji e2">🎓</div>
      <div class="auth-deco-emoji e3">🌸</div>
    </div>

    <div class="auth-card">
      <!-- Logo -->
      <div class="auth-logo">
        <span class="auth-logo-icon">🎒</span>
        <span class="auth-logo-text">校园跳蚤</span>
      </div>
      <h2>欢迎回来 👋</h2>
      <p class="auth-subtitle">登录你的校园交易账号</p>

      <el-form :model="form" @keyup.enter="handleLogin">
        <el-form-item>
          <el-input
            v-model="form.username"
            placeholder="输入用户名"
            :prefix-icon="User"
            size="large"
          />
        </el-form-item>
        <el-form-item>
          <el-input
            v-model="form.password"
            type="password"
            placeholder="输入密码"
            :prefix-icon="Lock"
            show-password
            size="large"
          />
        </el-form-item>
        <el-form-item>
          <el-button
            class="auth-submit-btn"
            :loading="loading"
            @click="handleLogin"
            size="large"
            style="width:100%"
          >
            {{ loading ? '登录中...' : '✨ 登录' }}
          </el-button>
        </el-form-item>
      </el-form>

      <div class="auth-footer">
        还没有账号？<router-link to="/register">去注册 →</router-link>
      </div>

      <div class="demo-info">
        <span class="demo-icon">🔑</span>
        <span>测试账号：<strong>zhangsan</strong> / 123456 或 <strong>lisi</strong> / 123456</span>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { ElMessage } from 'element-plus'
import { User, Lock } from '@element-plus/icons-vue'
import { useUserStore } from '@/stores/user'

const router = useRouter()
const route = useRoute()
const userStore = useUserStore()
const loading = ref(false)
const form = ref({ username: '', password: '' })

const handleLogin = async () => {
  if (!form.value.username || !form.value.password) {
    ElMessage.warning('请输入用户名和密码')
    return
  }
  loading.value = true
  try {
    const result = await userStore.login(form.value.username, form.value.password)
    if (result.code === 0) {
      ElMessage.success('🎉 登录成功！欢迎回来 ~')
      router.push(route.query.redirect || '/')
    } else {
      ElMessage.error(result.message || '登录失败')
    }
  } catch (error) {
    ElMessage.error(error.response?.data?.message || '登录失败')
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

/* ===== 装饰元素 ===== */
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
  top: -80px; right: -60px;
  animation: campus-float 6s ease-in-out infinite;
}
.c2 {
  width: 200px; height: 200px;
  background: linear-gradient(135deg, #6C5CE7, #A29BFE);
  bottom: -40px; left: -60px;
  animation: campus-float 8s ease-in-out infinite reverse;
}
.c3 {
  width: 150px; height: 150px;
  background: linear-gradient(135deg, #00B894, #55EFC4);
  bottom: 20%; right: 10%;
  animation: campus-float 7s ease-in-out infinite 1s;
}
.auth-deco-emoji {
  position: absolute;
  font-size: 40px;
  opacity: 0.2;
}
.e1 { top: 15%; left: 8%; animation: campus-float 5s ease-in-out infinite; }
.e2 { bottom: 20%; right: 8%; animation: campus-float 6s ease-in-out infinite 0.5s; }
.e3 { top: 30%; right: 25%; animation: campus-float 4s ease-in-out infinite 1s; }

/* ===== 登录卡片 ===== */
.auth-card {
  width: 420px;
  padding: 48px 40px 36px;
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
  margin-bottom: 24px;
}
.auth-logo-icon {
  font-size: 36px;
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
  margin: 0 0 30px;
}

/* ===== 表单 ===== */
.auth-page :deep(.el-input__wrapper) {
  background: #FFF8F5;
  border-radius: 14px !important;
  padding: 4px 16px;
}
.auth-page :deep(.el-input__prefix) {
  margin-right: 8px;
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
.auth-footer a:hover {
  color: #FD79A8;
}

.demo-info {
  margin-top: 20px;
  padding: 14px 16px;
  background: #FFF8F5;
  border-radius: 12px;
  text-align: center;
  font-size: 12px;
  color: #8892A0;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 6px;
  border: 1px solid rgba(255, 126, 103, 0.08);
}
.demo-icon {
  font-size: 16px;
}
</style>