import { createRouter, createWebHistory } from 'vue-router'
import ClientLayout from '@/layouts/ClientLayout.vue'

const routes = [
  {
    path: '/login',
    name: 'login',
    component: () => import('@/views/Login.vue')
  },
  {
    path: '/register',
    name: 'register',
    component: () => import('@/views/Register.vue')
  },
  {
    path: '/',
    component: ClientLayout,
    children: [
      {
        path: '',
        name: 'home',
        component: () => import('@/views/Home.vue')
      },
      {
        path: 'item/:id',
        name: 'itemDetail',
        component: () => import('@/views/ItemDetail.vue')
      },
      {
        path: 'publish',
        name: 'publish',
        meta: { requiresAuth: true },
        component: () => import('@/views/Publish.vue')
      },
      {
        path: 'cart',
        name: 'cart',
        meta: { requiresAuth: true },
        component: () => import('@/views/Cart.vue')
      },
      {
        path: 'orders',
        name: 'myOrders',
        meta: { requiresAuth: true },
        component: () => import('@/views/MyOrders.vue')
      },
      {
        path: 'messages',
        name: 'messages',
        meta: { requiresAuth: true },
        component: () => import('@/views/Messages.vue')
      },
      {
        path: 'profile',
        name: 'profile',
        meta: { requiresAuth: true },
        component: () => import('@/views/Profile.vue')
      },
      {
        path: 'reports',
        name: 'myReports',
        meta: { requiresAuth: true },
        component: () => import('@/views/MyReports.vue')
      }
    ]
  }
]

const router = createRouter({
  history: createWebHistory(),
  routes
})

router.beforeEach((to) => {
  const token = localStorage.getItem('client_token')
  if (to.meta.requiresAuth && !token) {
    return { name: 'login', query: { redirect: to.fullPath } }
  }
  return true
})

export default router