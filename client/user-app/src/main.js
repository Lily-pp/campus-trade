import { createApp } from 'vue'
import { createPinia } from 'pinia'
import 'element-plus/dist/index.css'
import './styles/campus-theme.css'
import zhCn from 'element-plus/es/locale/lang/zh-cn'
import LazyLoad from 'vue-lazyload'
import App from './App.vue'
import router from './router'

const app = createApp(App)
const pinia = createPinia()

app.use(pinia)
app.use(router)
app.use(LazyLoad, {
  lazyComponent: true,
  preLoad: 1.3,
  error: 'data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100"><rect fill="%23f5f5f5" width="100" height="100"/><text x="50" y="50" font-size="12" text-anchor="middle" dy=".3em" fill="%23bbb">图片加载中</text></svg>',
  loading: 'data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100"><rect fill="%23f5f5f5" width="100" height="100"/><text x="50" y="50" font-size="12" text-anchor="middle" dy=".3em" fill="%23bbb">图片加载中</text></svg>',
})

app.mount('#app')
