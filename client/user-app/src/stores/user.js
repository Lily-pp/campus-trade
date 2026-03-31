import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import api from '@/api'

export const useUserStore = defineStore('user', () => {
  const token = ref(localStorage.getItem('client_token') || '')
  const user = ref(JSON.parse(localStorage.getItem('client_user') || 'null'))

  const isLoggedIn = computed(() => !!token.value)

  const login = async (username, password) => {
    const res = await api.post('/auth/login', { username, password })
    if (res.data.code === 0) {
      token.value = res.data.data.token
      user.value = res.data.data.user
      localStorage.setItem('client_token', token.value)
      localStorage.setItem('client_user', JSON.stringify(user.value))
    }
    return res.data
  }

  const register = async (form) => {
    const res = await api.post('/auth/register', form)
    if (res.data.code === 0) {
      token.value = res.data.data.token
      user.value = res.data.data.user
      localStorage.setItem('client_token', token.value)
      localStorage.setItem('client_user', JSON.stringify(user.value))
    }
    return res.data
  }

  const logout = () => {
    token.value = ''
    user.value = null
    localStorage.removeItem('client_token')
    localStorage.removeItem('client_user')
  }

  return { token, user, isLoggedIn, login, register, logout }
})
