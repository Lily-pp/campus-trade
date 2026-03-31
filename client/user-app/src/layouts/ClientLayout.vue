<template>
  <div class="client-layout">
    <header class="header">
      <div class="header-inner">
        <router-link to="/" class="logo">
          <el-icon :size="22"><Shop /></el-icon>
          <span>CampusTrade</span>
        </router-link>

        <div class="search-bar">
          <el-input
            v-model="keyword"
            placeholder="搜索商品..."
            clearable
            @keyup.enter="handleSearch"
            @clear="handleClear"
          >
            <template #append>
              <el-button :icon="Search" @click="handleSearch" />
            </template>
          </el-input>
        </div>

        <nav class="nav">
          <router-link to="/" class="nav-link">
            <el-icon><HomeFilled /></el-icon> 首页
          </router-link>
          <template v-if="userStore.isLoggedIn">
            <router-link to="/publish" class="nav-link">
              <el-icon><Plus /></el-icon> 发布
            </router-link>
            <router-link to="/cart" class="nav-link">
              <el-icon><ShoppingCart /></el-icon> 购物车
            </router-link>
            <router-link to="/orders" class="nav-link">
              <el-icon><List /></el-icon> 订单
            </router-link>
            <router-link to="/messages" class="nav-link">
              <el-icon><ChatDotRound /></el-icon> 私信
            </router-link>
            <router-link to="/profile" class="nav-link">
              <el-icon><User /></el-icon> 我的
            </router-link>
            <el-dropdown @command="handleCommand">
              <span class="nav-user">
                <el-avatar :size="28" icon="UserFilled" />
                {{ userStore.user?.real_name || userStore.user?.username }}
              </span>
              <template #dropdown>
                <el-dropdown-menu>
                  <el-dropdown-item command="profile">个人中心</el-dropdown-item>
                  <el-dropdown-item command="logout" divided>退出登录</el-dropdown-item>
                </el-dropdown-menu>
              </template>
            </el-dropdown>
          </template>
          <template v-else>
            <router-link to="/login" class="nav-link login-btn">登录</router-link>
            <router-link to="/register" class="nav-link register-btn">注册</router-link>
          </template>
        </nav>
      </div>
    </header>

    <main class="main-content">
      <router-view />
    </main>

    <footer class="footer">
      <p>CampusTrade 校园二手交易平台 &copy; 2026</p>
    </footer>
  </div>
</template>

<script setup>
import { ref } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { Search } from '@element-plus/icons-vue'
import { useUserStore } from '@/stores/user'

const router = useRouter()
const route = useRoute()
const userStore = useUserStore()
const keyword = ref(route.query.keyword || '')

const handleSearch = () => {
  const kw = keyword.value.trim()
  if (kw) {
    router.push({ path: '/', query: { keyword: kw } })
  } else {
    router.push('/')
  }
}

const handleClear = () => {
  router.push('/')
}

const handleCommand = (cmd) => {
  if (cmd === 'logout') {
    userStore.logout()
    router.push('/')
  } else if (cmd === 'profile') {
    router.push('/profile')
  }
}
</script>

<style scoped>
.client-layout {
  min-height: 100vh;
  display: flex;
  flex-direction: column;
  background: #f5f7fa;
}

.header {
  background: #fff;
  box-shadow: 0 1px 6px rgba(0, 0, 0, 0.06);
  position: sticky;
  top: 0;
  z-index: 100;
}

.header-inner {
  max-width: 1200px;
  margin: 0 auto;
  padding: 0 20px;
  height: 60px;
  display: flex;
  align-items: center;
  gap: 24px;
}

.logo {
  display: flex;
  align-items: center;
  gap: 6px;
  font-size: 20px;
  font-weight: bold;
  color: #409eff;
  text-decoration: none;
  white-space: nowrap;
}

.search-bar {
  flex: 1;
  max-width: 420px;
}

.nav {
  display: flex;
  align-items: center;
  gap: 12px;
  white-space: nowrap;
  margin-left: auto;
}

.nav-link {
  display: flex;
  align-items: center;
  gap: 4px;
  text-decoration: none;
  color: #606266;
  font-size: 14px;
  padding: 6px 10px;
  border-radius: 6px;
  transition: all 0.2s;
}

.nav-link:hover {
  color: #409eff;
  background: #ecf5ff;
}

.nav-link.router-link-exact-active {
  color: #409eff;
  font-weight: 500;
}

.login-btn {
  color: #409eff;
  border: 1px solid #409eff;
}

.register-btn {
  color: #fff;
  background: #409eff;
}

.register-btn:hover {
  color: #fff;
  background: #66b1ff;
}

.nav-user {
  display: flex;
  align-items: center;
  gap: 6px;
  cursor: pointer;
  font-size: 14px;
  color: #333;
}

.main-content {
  flex: 1;
  max-width: 1200px;
  width: 100%;
  margin: 20px auto;
  padding: 0 20px;
}

.footer {
  text-align: center;
  padding: 20px;
  color: #999;
  font-size: 13px;
}
</style>
