<template>
  <div class="auth-page">
    <div class="auth-card">
      <h2>注册 CampusTrade</h2>
      <el-form :model="form" @keyup.enter="handleRegister">
        <el-form-item>
          <el-input v-model="form.username" placeholder="用户名（3-20个字符）" :prefix-icon="User" size="large" />
        </el-form-item>
        <el-form-item>
          <el-input v-model="form.password" type="password" placeholder="密码" :prefix-icon="Lock" show-password size="large" />
        </el-form-item>
        <el-form-item>
          <el-input v-model="form.confirmPassword" type="password" placeholder="确认密码" :prefix-icon="Lock" show-password size="large" />
        </el-form-item>
        <el-form-item>
          <el-input v-model="form.real_name" placeholder="真实姓名（选填）" size="large" />
        </el-form-item>
        <el-form-item>
          <el-input v-model="form.campus" placeholder="所在校区（选填）" size="large" />
        </el-form-item>
        <el-form-item>
          <el-button type="primary" :loading="loading" @click="handleRegister" size="large" style="width:100%">
            注册
          </el-button>
        </el-form-item>
      </el-form>
      <div class="auth-footer">
        已有账号？<router-link to="/login">去登录</router-link>
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
      ElMessage.success('注册成功')
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
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
}
.auth-card {
  width: 400px;
  padding: 40px;
  background: #fff;
  border-radius: 16px;
  box-shadow: 0 12px 40px rgba(0, 0, 0, 0.15);
}
h2 {
  text-align: center;
  margin-bottom: 32px;
  color: #333;
  font-size: 24px;
}
.auth-footer {
  text-align: center;
  margin-top: 16px;
  font-size: 14px;
  color: #666;
}
.auth-footer a {
  color: #409eff;
  text-decoration: none;
}
</style>
