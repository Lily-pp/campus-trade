/**
 * 节流函数 - 在一段时间内最多执行一次
 * @param {Function} func - 要执行的函数
 * @param {number} delay - 延迟时间（毫秒）
 * @returns {Function} - 节流后的函数
 */
export function throttle(func, delay = 300) {
  let lastCall = 0
  return function(...args) {
    const now = Date.now()
    if (now - lastCall >= delay) {
      lastCall = now
      func.apply(this, args)
    }
  }
}

/**
 * 防抖函数 - 在事件停止触发后的一段时间后执行
 * @param {Function} func - 要执行的函数
 * @param {number} delay - 延迟时间（毫秒）
 * @returns {Function} - 防抖后的函数
 */
export function debounce(func, delay = 300) {
  let timeout = null
  return function(...args) {
    if (timeout) clearTimeout(timeout)
    timeout = setTimeout(() => {
      func.apply(this, args)
      timeout = null
    }, delay)
  }
}

/**
 * 带立即执行选项的防抖函数
 * @param {Function} func - 要执行的函数
 * @param {number} delay - 延迟时间（毫秒）
 * @param {boolean} immediate - 是否立即执行
 * @returns {Function} - 防抖后的函数
 */
export function debounceWithImmediate(func, delay = 300, immediate = false) {
  let timeout = null
  let result
  return function(...args) {
    const callNow = immediate && !timeout
    if (timeout) clearTimeout(timeout)
    timeout = setTimeout(() => {
      timeout = null
      if (!immediate) {
        result = func.apply(this, args)
      }
    }, delay)
    if (callNow) {
      result = func.apply(this, args)
    }
    return result
  }
}

/**
 * 取消防抖/节流
 * @param {Function} func - 节流或防抖函数
 */
export function cancel(func) {
  if (func && func._timeout) {
    clearTimeout(func._timeout)
    func._timeout = null
  }
}

/**
 * 批量请求控制 - 使用 Promise.all 并行执行多个异步操作
 * @param {Array<Promise>} promises - Promise 数组
 * @returns {Promise} - 所有 Promise 完成后的结果
 */
export function batchRequests(promises) {
  return Promise.all(promises)
}

/**
 * 批量请求控制 - 使用 Promise.allSettled 获取所有结果
 * @param {Array<Promise>} promises - Promise 数组
 * @returns {Promise} - 所有 Promise 的结果状态
 */
export function batchRequestsSettled(promises) {
  return Promise.allSettled(promises)
}
