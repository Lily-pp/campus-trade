<template>
  <div class="client-layout">
    <!-- 顶部装饰条 -->
    <div class="top-stripe"></div>

    <header class="header">
      <div class="header-inner">
        <!-- Logo -->
        <router-link to="/" class="logo">
          <div class="logo-icon">🎒</div>
          <div class="logo-text">
            <span class="logo-main">校园跳蚤</span>
            <span class="logo-sub">CampusTrade</span>
          </div>
        </router-link>

        <!-- 搜索栏 -->
        <div class="search-bar">
          <el-input
            v-model="keyword"
            placeholder="🔍 搜搜校园里的好物..."
            clearable
            @keyup.enter="handleSearch"
            @input="debouncedSearch"
            @clear="handleClear"
          >
            <template #prefix>
              <el-icon class="search-icon"><Search /></el-icon>
            </template>
            <template #append>
              <el-button class="search-btn" @click="handleSearch">搜索</el-button>
            </template>
          </el-input>
        </div>

        <!-- 导航 -->
        <nav class="nav">
          <router-link to="/" class="nav-link" title="首页">
            <span class="nav-icon">🏠</span>
            <span class="nav-label">首页</span>
          </router-link>

          <template v-if="userStore.isLoggedIn">
            <router-link to="/publish" class="nav-link" title="发布">
              <span class="nav-icon">📦</span>
              <span class="nav-label">发布</span>
            </router-link>
            <router-link to="/cart" class="nav-link cart-link" title="购物车">
              <span class="nav-icon">🛒</span>
              <span class="nav-label">购物车</span>
            </router-link>
            <router-link to="/orders" class="nav-link" title="订单">
              <span class="nav-icon">📋</span>
              <span class="nav-label">订单</span>
            </router-link>
            <router-link to="/messages" class="nav-link" title="私信">
              <span class="nav-icon">💬</span>
              <span class="nav-label">私信</span>
            </router-link>

            <el-dropdown @command="handleCommand" class="user-dropdown">
              <span class="nav-user">
                <el-avatar :size="32" class="user-avatar">
                  {{ userStore.user?.real_name?.[0] || userStore.user?.username?.[0] || 'U' }}
                </el-avatar>
                <span class="user-name">{{ userStore.user?.real_name || userStore.user?.username }}</span>
                <el-icon class="dropdown-arrow"><ArrowDown /></el-icon>
              </span>
              <template #dropdown>
                <el-dropdown-menu>
                  <el-dropdown-item command="profile">
                    <span style="margin-right:8px">👤</span> 个人中心
                  </el-dropdown-item>
                  <el-dropdown-item command="profile" divided>
                    <span style="margin-right:8px">⭐</span> 我的收藏
                  </el-dropdown-item>
                  <el-dropdown-item command="logout" divided>
                    <span style="margin-right:8px">🚪</span> 退出登录
                  </el-dropdown-item>
                </el-dropdown-menu>
              </template>
            </el-dropdown>
          </template>
          <template v-else>
            <router-link to="/login" class="nav-btn login-btn">登录</router-link>
            <router-link to="/register" class="nav-btn register-btn">注册</router-link>
          </template>
        </nav>
      </div>
    </header>

    <!-- 主内容 -->
    <main class="main-content">
      <keep-alive :max="5">
        <router-view v-if="$route.meta.keepAlive" :key="$route.fullPath" />
      </keep-alive>
      <router-view v-if="!$route.meta.keepAlive" :key="$route.fullPath" />
    </main>

    <!-- 底部 -->
    <footer class="footer">
      <div class="footer-inner">
        <div class="footer-top">
          <div class="footer-brand">
            <div class="footer-logo">🎒 校园跳蚤</div>
            <p class="footer-desc">CampusTrade - 属于大学生的二手交易平台<br/>让闲置物品在校园里找到新主人 🎓</p>
          </div>
          <div class="footer-links">
            <div class="footer-col">
              <h4>快速链接</h4>
              <router-link to="/">首页</router-link>
              <router-link to="/lost-found">失物招领</router-link>
              <router-link to="/charity">毕业公益</router-link>
            </div>
            <div class="footer-col">
              <h4>校园服务</h4>
              <router-link to="/storage-services">寄存服务</router-link>
              <router-link to="/rental-items">校园转租</router-link>
            </div>
            <div class="footer-col">
              <h4>关于我们</h4>
              <a href="#">关于平台</a>
              <a href="#">使用帮助</a>
            </div>
          </div>
        </div>
        <div class="footer-bottom">
          <p>CampusTrade 校园二手交易平台 &copy; 2026 · 让每一件物品都承载校园记忆 🌸</p>
        </div>
      </div>
    </footer>
  </div>
</template>

<script setup>
import { ref } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { Search, ArrowDown } from '@element-plus/icons-vue'
import { useUserStore } from '@/stores/user'
import { debounce } from '@/utils/performance'

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

const debouncedSearch = debounce(handleSearch, 500)

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
/* ===== 顶部装饰条 ===== */
.top-stripe {
  height: 4px;
  background: linear-gradient(90deg, #FF7E67, #FD79A8, #A29BFE, #55EFC4, #FDCB6E);
  position: sticky;
  top: 0;
  z-index: 101;
}

/* ===== 头部 ===== */
.header {
  background: rgba(255, 255, 255, 0.95);
  backdrop-filter: blur(20px);
  -webkit-backdrop-filter: blur(20px);
  box-shadow: 0 2px 20px rgba(255, 126, 103, 0.06);
  position: sticky;
  top: 4px;
  z-index: 100;
  border-bottom: 1px solid rgba(240, 230, 224, 0.5);
}
.header-inner {
  max-width: 1200px;
  margin: 0 auto;
  padding: 0 24px;
  height: 64px;
  display: flex;
  align-items: center;
  gap: 28px;
}

/* ===== Logo ===== */
.logo {
  display: flex;
  align-items: center;
  gap: 10px;
  text-decoration: none;
  flex-shrink: 0;
}
.logo-icon {
  font-size: 32px;
  line-height: 1;
  animation: campus-float 3s ease-in-out infinite;
}
.logo-text {
  display: flex;
  flex-direction: column;
}
.logo-main {
  font-size: 20px;
  font-weight: 800;
  background: linear-gradient(135deg, #FF7E67, #FD79A8);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
  line-height: 1.2;
}
.logo-sub {
  font-size: 11px;
  color: #B2BEC3;
  font-weight: 500;
  letter-spacing: 1px;
  text-transform: uppercase;
}

/* ===== 搜索栏 ===== */
.search-bar {
  flex: 1;
  max-width: 480px;
}
.search-bar :deep(.el-input__wrapper) {
  background: #FFF8F5;
  border-radius: 24px !important;
  padding-left: 16px;
  box-shadow: 0 2px 8px rgba(255, 126, 103, 0.06) inset !important;
}
.search-bar :deep(.el-input__wrapper.is-focus) {
  box-shadow: 0 0 0 2px rgba(255, 126, 103, 0.2) inset !important;
}
.search-bar :deep(.el-input__inner) {
  font-size: 14px;
}
.search-icon {
  color: #B2BEC3;
  font-size: 16px;
}
.search-bar :deep(.el-input-group__append) {
  background: transparent;
  border: none;
}
.search-btn {
  background: linear-gradient(135deg, #FF7E67, #FD79A8) !important;
  color: #fff !important;
  border: none !important;
  border-radius: 20px !important;
  padding: 8px 20px !important;
  font-size: 13px !important;
  font-weight: 600 !important;
  margin-right: 4px;
  transition: all 0.3s ease !important;
}
.search-btn:hover {
  transform: scale(1.04);
  box-shadow: 0 4px 15px rgba(255, 126, 103, 0.3) !important;
}

/* ===== 导航 ===== */
.nav {
  display: flex;
  align-items: center;
  gap: 4px;
  margin-left: auto;
  flex-shrink: 0;
}
.nav-link {
  display: flex;
  align-items: center;
  gap: 6px;
  text-decoration: none;
  color: #8892A0;
  font-size: 13px;
  font-weight: 500;
  padding: 8px 14px;
  border-radius: 12px;
  transition: all 0.25s cubic-bezier(0.25, 0.46, 0.45, 0.94);
  position: relative;
}
.nav-link:hover {
  color: #FF7E67;
  background: rgba(255, 126, 103, 0.06);
  transform: translateY(-1px);
}
.nav-link.router-link-exact-active {
  color: #FF7E67;
  background: rgba(255, 126, 103, 0.08);
}
.nav-link.router-link-exact-active::after {
  content: '';
  position: absolute;
  bottom: 2px;
  left: 50%;
  transform: translateX(-50%);
  width: 16px;
  height: 3px;
  background: linear-gradient(90deg, #FF7E67, #FD79A8);
  border-radius: 2px;
}
.nav-icon {
  font-size: 18px;
  line-height: 1;
}
.nav-label {
  font-size: 13px;
}

/* ===== 登录/注册按钮 ===== */
.nav-btn {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  text-decoration: none;
  font-size: 13px;
  font-weight: 600;
  padding: 8px 22px;
  border-radius: 20px;
  transition: all 0.3s ease;
}
.login-btn {
  color: #FF7E67;
  background: rgba(255, 126, 103, 0.08);
  border: 1px solid rgba(255, 126, 103, 0.2);
}
.login-btn:hover {
  background: rgba(255, 126, 103, 0.15);
  transform: translateY(-1px);
}
.register-btn {
  color: #fff;
  background: linear-gradient(135deg, #FF7E67, #FD79A8);
  border: none;
  box-shadow: 0 4px 12px rgba(255, 126, 103, 0.25);
}
.register-btn:hover {
  transform: translateY(-2px);
  box-shadow: 0 6px 20px rgba(255, 126, 103, 0.35);
}

/* ===== 用户下拉 ===== */
.user-dropdown {
  cursor: pointer;
}
.nav-user {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 4px 8px 4px 4px;
  border-radius: 20px;
  transition: all 0.3s ease;
}
.nav-user:hover {
  background: rgba(255, 126, 103, 0.06);
}
.user-avatar {
  background: linear-gradient(135deg, #FF7E67, #FD79A8) !important;
  font-size: 13px !important;
  font-weight: 700 !important;
  border: 2px solid #fff;
  box-shadow: 0 2px 8px rgba(255, 126, 103, 0.2);
}
.user-name {
  font-size: 13px;
  font-weight: 600;
  color: #2D3436;
  max-width: 80px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.dropdown-arrow {
  font-size: 12px;
  color: #B2BEC3;
}

/* ===== 主内容 ===== */
.main-content {
  flex: 1;
  max-width: 1200px;
  width: 100%;
  margin: 24px auto;
  padding: 0 24px;
}

/* ===== 底部 ===== */
.footer {
  background: #2D3436;
  color: #B2BEC3;
  margin-top: 60px;
}
.footer-inner {
  max-width: 1200px;
  margin: 0 auto;
  padding: 48px 24px 24px;
}
.footer-top {
  display: flex;
  justify-content: space-between;
  gap: 48px;
  flex-wrap: wrap;
  margin-bottom: 32px;
}
.footer-brand {
  max-width: 300px;
}
.footer-logo {
  font-size: 24px;
  font-weight: 800;
  margin-bottom: 12px;
  color: #fff;
}
.footer-desc {
  font-size: 13px;
  line-height: 1.8;
  color: #8892A0;
}
.footer-links {
  display: flex;
  gap: 48px;
  flex-wrap: wrap;
}
.footer-col h4 {
  color: #fff;
  font-size: 14px;
  font-weight: 600;
  margin: 0 0 16px;
}
.footer-col a {
  display: block;
  color: #8892A0;
  text-decoration: none;
  font-size: 13px;
  margin-bottom: 10px;
  transition: color 0.2s;
}
.footer-col a:hover {
  color: #FF7E67;
}
.footer-bottom {
  border-top: 1px solid rgba(255, 255, 255, 0.06);
  padding-top: 20px;
  text-align: center;
  font-size: 12px;
  color: #636E72;
}
</style>