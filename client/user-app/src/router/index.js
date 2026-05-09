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
        component: () => import('@/views/Home.vue'),
        meta: { keepAlive: true, preload: true } // 首页缓存和预加载
      },
      {
        path: 'item/:id',
        name: 'itemDetail',
        component: () => import('@/views/ItemDetail.vue'),
        meta: { keepAlive: true } // 商品详情缓存
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
        meta: { requiresAuth: true, keepAlive: true }, // 购物车缓存
        component: () => import('@/views/Cart.vue')
      },
      {
        path: 'orders',
        name: 'myOrders',
        meta: { requiresAuth: true, keepAlive: true }, // 订单缓存
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

// 路由预加载 - 在浏览器空闲时预加载高频页面
const preloadRoutes = ['home', 'itemDetail', 'cart']
const preloadIfIdleSupported = () => {
  if ('requestIdleCallback' in window) {
    requestIdleCallback(() => {
      preloadRoutes.forEach(name => {
        const route = routes[routes.length - 1].children.find(r => r.name === name)
        if (route && route.component) {
          route.component()
        }
      })
    })
  } else {
    // Fallback: 在 2 秒后预加载
    setTimeout(() => {
      preloadRoutes.forEach(name => {
        const route = routes[routes.length - 1].children.find(r => r.name === name)
        if (route && route.component) {
          route.component()
        }
      })
    }, 2000)
  }
}

router.isReady().then(preloadIfIdleSupported)

router.beforeEach((to) => {
  const token = localStorage.getItem('client_token')
  if (to.meta.requiresAuth && !token) {
    return { name: 'login', query: { redirect: to.fullPath } }
  }
  return true
})

export default router