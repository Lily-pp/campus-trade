import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import { fileURLToPath, URL } from 'node:url'
import Components from 'unplugin-vue-components/vite'
import { ElementPlusResolver } from 'unplugin-vue-components/resolvers'
import Icons from 'unplugin-icons/vite'
import compression from 'vite-plugin-compression'

export default defineConfig({
  plugins: [
    vue(),
    Components({
      resolvers: [
        ElementPlusResolver(),
      ],
    }),
    Icons({
      autoInstall: true,
    }),
    compression({
      verbose: true,
      disable: false,
      threshold: 10240,
      algorithm: 'gzip',
      ext: '.gz',
    }),
  ],
  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./src', import.meta.url))
    }
  },
  server: {
    port: 5174,
    hmr: {
      port: 5174
    },
    proxy: {
    '/api': {
      target: 'http://localhost:3000',
      changeOrigin: true
    }
  }
  },
  build: {
    rollupOptions: {
      output: {
        manualChunks: {
          'element-plus': ['element-plus'],
          'vue-router': ['vue-router'],
          'pinia': ['pinia'],
          'axios': ['axios'],
        },
      },
    },
    chunkSizeWarningLimit: 1500,
    minify: 'terser',
    terserOptions: {
      compress: {
        drop_console: true, // 生产环境移除 console
        drop_debugger: true, // 移除 debugger
      },
      format: {
        comments: false, // 移除注释
      },
    },
    sourcemap: false, // 生产环境不生成 sourcemap
  },
})
