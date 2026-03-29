import { createRouter, createWebHistory } from 'vue-router'
import MainLayout from '@/layouts/MainLayout.vue'

const routes = [
  {
    path: '/login',
    name: 'login',
    component: () => import('@/views/Login.vue')
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
      }
    ]
  }
]

const router = createRouter({
  history: createWebHistory(),
  routes
})

// 新版路由守卫写法（不用 next）
router.beforeEach((to, from) => {
  const token = localStorage.getItem('token')
  
  // 需要登录的页面
  if (to.path !== '/login' && !token) {
    return '/login'
  }
  
  // 已登录用户访问登录页
  if (to.path === '/login' && token) {
    return '/'
  }
  
  // 正常放行
  return true
})

export default router