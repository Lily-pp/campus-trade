import { defineStore } from 'pinia'
import { ref } from 'vue'
import api from '@/api'

// 缓存时间（毫秒）
const CACHE_DURATION = 5 * 60 * 1000 // 5 分钟

export const useItemStore = defineStore('item', () => {
  // 商品列表缓存
  const itemsCache = ref({})
  // 商品详情缓存
  const itemDetailCache = ref({})
  // 分类缓存
  const categoriesCache = ref({
    data: null,
    timestamp: 0
  })

  /**
   * 生成缓存键
   */
  const generateCacheKey = (page, pageSize, filters) => {
    return `${page}_${pageSize}_${JSON.stringify(filters)}`
  }

  /**
   * 检查缓存是否过期
   */
  const isCacheValid = (timestamp) => {
    return Date.now() - timestamp < CACHE_DURATION
  }

  /**
   * 获取商品列表（带缓存）
   */
  const fetchItems = async (page, pageSize, filters) => {
    const cacheKey = generateCacheKey(page, pageSize, filters)
    
    // 如果缓存有效，直接返回缓存
    if (itemsCache.value[cacheKey] && isCacheValid(itemsCache.value[cacheKey].timestamp)) {
      return itemsCache.value[cacheKey].data
    }

    // 否则发起请求
    try {
      const params = {
        page,
        pageSize,
        sort: filters.sort
      }
      if (filters.category_id) params.category_id = filters.category_id
      if (filters.keyword) params.keyword = filters.keyword

      const res = await api.get('/items', { params })
      
      // 缓存结果
      itemsCache.value[cacheKey] = {
        data: res.data,
        timestamp: Date.now()
      }
      
      return res.data
    } catch (error) {
      console.error('获取商品列表失败:', error)
      throw error
    }
  }

  /**
   * 获取商品详情（带缓存）
   */
  const fetchItemDetail = async (itemId) => {
    // 如果缓存有效，直接返回缓存
    if (itemDetailCache.value[itemId] && isCacheValid(itemDetailCache.value[itemId].timestamp)) {
      return itemDetailCache.value[itemId].data
    }

    // 否则发起请求
    try {
      const res = await api.get(`/items/${itemId}`)
      
      // 缓存结果
      itemDetailCache.value[itemId] = {
        data: res.data,
        timestamp: Date.now()
      }
      
      return res.data
    } catch (error) {
      console.error('获取商品详情失败:', error)
      throw error
    }
  }

  /**
   * 获取分类列表（带缓存）
   */
  const fetchCategories = async () => {
    // 如果缓存有效，直接返回缓存
    if (categoriesCache.value.data && isCacheValid(categoriesCache.value.timestamp)) {
      return categoriesCache.value.data
    }

    // 否则发起请求
    try {
      const res = await api.get('/categories')
      
      // 缓存结果
      categoriesCache.value = {
        data: res.data,
        timestamp: Date.now()
      }
      
      return res.data
    } catch (error) {
      console.error('获取分类失败:', error)
      throw error
    }
  }

  /**
   * 清除商品列表缓存（发布新商品后）
   */
  const clearItemsCache = () => {
    itemsCache.value = {}
  }

  /**
   * 清除商品详情缓存
   */
  const clearItemDetailCache = (itemId) => {
    if (itemId) {
      delete itemDetailCache.value[itemId]
    } else {
      itemDetailCache.value = {}
    }
  }

  /**
   * 清除所有缓存
   */
  const clearAllCache = () => {
    itemsCache.value = {}
    itemDetailCache.value = {}
    categoriesCache.value = { data: null, timestamp: 0 }
  }

  return {
    fetchItems,
    fetchItemDetail,
    fetchCategories,
    clearItemsCache,
    clearItemDetailCache,
    clearAllCache
  }
})
