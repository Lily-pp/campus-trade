import { createRouter, createWebHistory } from 'vue-router'
import MainLayout from '@/layouts/MainLayout.vue'
import Login from '@/views/Login.vue'

const routes = [
  {
    path: '/login',
    name: 'login',
    component: Login   // 静态导入，避免首次跳转动态加载失败
  },
  {
    path: '/',
    component: MainLayout,
    redirect: '/dashboard',
    children: [
      {
        path: 'dashboard',
        name: 'dashboard',
        component: () => import('@/views/Dashboard.vue')
      },
      {
        path: 'items',
        name: 'items',
        component: () => import('@/views/Items.vue')
      },
      {
        path: 'categories',
        name: 'categories',
        component: () => import('@/views/Categories.vue')
      },
      {
        path: 'users',
        name: 'users',
        meta: { requiresAdmin: true },
        component: () => import('@/views/Users.vue')
      },
      {
        path: 'orders',
        name: 'orders',
        meta: { requiresAdmin: true },
        component: () => import('@/views/Orders.vue')
      },
      {
        path: 'reports',
        name: 'reports',
        meta: { requiresAdmin: true },
        component: () => import('@/views/Reports.vue')
      },
      {
        path: 'logs',
        name: 'logs',
        meta: { requiresAdmin: true },
        component: () => import('@/views/Logs.vue')
      },
      {
        path: 'activities',
        name: 'activities',
        component: () => import('@/views/Activities.vue')
      },
      {
        path: 'campus-services',
        name: 'campusServices',
        component: () => import('@/views/CampusServices.vue')
      },
      {
        path: 'charity',
        name: 'charityManagement',
        component: () => import('@/views/CharityManagement.vue')
      }
    ]
  }
]

const router = createRouter({
  history: createWebHistory(),
  routes
})

// 路由守卫：登录校验 + 角色权限
router.beforeEach((to) => {
  const token = localStorage.getItem('token')

  // 未登录 → 跳登录页
  if (to.path !== '/login' && !token) {
    return '/login'
  }

  // 已登录访问登录页 → 跳首页
  if (to.path === '/login' && token) {
    return '/'
  }

  // admin-only 页面：运营人员拦截
  if (to.meta.requiresAdmin) {
    let user = null
    try {
      const userStr = localStorage.getItem('user')
      if (userStr && userStr !== 'undefined') user = JSON.parse(userStr)
    } catch { /* ignore */ }
    if (!user || user.role !== 'admin') {
      return '/dashboard'
    }
  }

  return true
})

export default router