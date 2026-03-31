import axios from 'axios'

const api = axios.create({
  baseURL: 'http://localhost:3000/api',
  timeout: 10000
})

api.interceptors.request.use(config => {
  const token = localStorage.getItem('client_token')
  if (token && token !== 'undefined' && token !== 'null') {
    config.headers.Authorization = `Bearer ${token}`
  }
  return config
})

api.interceptors.response.use(
  response => response,
  error => {
    if (error.response?.status === 401) {
      localStorage.removeItem('client_token')
      localStorage.removeItem('client_user')
    }
    return Promise.reject(error)
  }
)

export default api
