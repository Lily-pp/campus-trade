<template>
  <div class="messages-page">
    <div class="msg-container">
      <!-- 左侧会话列表 -->
      <div class="conv-list">
        <div class="conv-list-header">
          <h3>💬 消息</h3>
        </div>
        <div
          v-for="conv in conversations"
          :key="conv.user_id"
          :class="['conv-item', { active: currentChat?.user_id === conv.user_id }]"
          @click="selectConversation(conv)"
        >
          <div class="conv-avatar">{{ conv.username?.[0] || '?' }}</div>
          <div class="conv-info">
            <div class="conv-top">
              <span class="conv-name">{{ conv.username }}</span>
              <span class="conv-time">{{ formatTime(conv.last_time) }}</span>
            </div>
            <div class="conv-last">{{ conv.last_message }}</div>
          </div>
          <div v-if="conv.unread > 0" class="conv-badge">{{ conv.unread }}</div>
        </div>
        <el-empty v-if="conversations.length === 0" description="暂无消息" :image-size="60" />
      </div>

      <!-- 右侧聊天窗口 -->
      <div class="chat-area" v-if="currentChat">
        <div class="chat-header">
          <div class="chat-header-avatar">{{ currentChat.username?.[0] || '?' }}</div>
          <span>{{ currentChat.username }}</span>
        </div>
        <div class="chat-messages" ref="msgListRef">
          <div
            v-for="msg in chatMessages"
            :key="msg.id"
            :class="['chat-bubble', msg.sender_id === userId ? 'mine' : 'theirs']"
          >
            <div class="bubble-content">{{ msg.content }}</div>
            <div class="bubble-time">{{ formatTime(msg.created_at) }}</div>
          </div>
        </div>
        <div class="chat-input">
          <input
            v-model="newMessage"
            placeholder="输入消息..."
            @keyup.enter="sendMessage"
            maxlength="500"
            class="chat-input-field"
          />
          <button class="send-btn" @click="sendMessage" :disabled="!newMessage.trim()">
            发送
          </button>
        </div>
      </div>
      <div class="chat-area empty-chat" v-else>
        <div class="empty-chat-content">
          <span class="empty-chat-icon">💬</span>
          <p>选择一个会话开始聊天</p>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, nextTick, onUnmounted } from 'vue'
import { useRoute } from 'vue-router'
import { io } from 'socket.io-client'
import api from '../api'
import { ElMessage } from 'element-plus'

const route = useRoute()
const userId = JSON.parse(localStorage.getItem('client_user') || '{}').id
const conversations = ref([])
const currentChat = ref(null)
const chatMessages = ref([])
const newMessage = ref('')
const msgListRef = ref(null)
let socket = null

const fetchConversations = async () => {
  try {
    const res = await api.get('/messages/conversations')
    if (res.data.code === 0) {
      conversations.value = res.data.data
    }
  } catch (e) {
    console.error(e)
  }
}

const selectConversation = async (conv) => {
  currentChat.value = conv
  await fetchMessages(conv.user_id)
}

const fetchMessages = async (otherUserId) => {
  try {
    const res = await api.get(`/messages/${otherUserId}`)
    if (res.data.code === 0) {
      chatMessages.value = res.data.data
      await nextTick()
      scrollToBottom()
    }
  } catch (e) {
    console.error(e)
  }
}

const sendMessage = async () => {
  if (!newMessage.value.trim() || !currentChat.value) return
  try {
    const res = await api.post('/messages', {
      receiver_id: currentChat.value.user_id,
      content: newMessage.value.trim()
    })
    if (res.data.code === 0) {
      newMessage.value = ''
      await fetchMessages(currentChat.value.user_id)
      await fetchConversations()
    }
  } catch (e) {
    ElMessage.error('发送失败')
  }
}

const scrollToBottom = () => {
  if (msgListRef.value) {
    msgListRef.value.scrollTop = msgListRef.value.scrollHeight
  }
}

const formatTime = (t) => {
  if (!t) return ''
  const d = new Date(t)
  const now = new Date()
  if (d.toDateString() === now.toDateString()) {
    return d.toLocaleTimeString('zh-CN', { hour: '2-digit', minute: '2-digit' })
  }
  return d.toLocaleDateString('zh-CN', { month: '2-digit', day: '2-digit' }) + ' ' +
    d.toLocaleTimeString('zh-CN', { hour: '2-digit', minute: '2-digit' })
}

onMounted(async () => {
  await fetchConversations()
  // 如果 URL 带了 ?to=userId，自动打开该会话
  const toUser = route.query.to
  if (toUser) {
    const existing = conversations.value.find(c => c.user_id === parseInt(toUser))
    if (existing) {
      await selectConversation(existing)
    } else {
      // 新会话，先获取用户名
      try {
        const res = await api.get(`/messages/${toUser}`)
        if (res.data.code === 0) {
          currentChat.value = { user_id: parseInt(toUser), username: route.query.name || '用户' }
          chatMessages.value = res.data.data
        }
      } catch (e) {
        console.error(e)
      }
    }
  }
  // Socket.io 实时连接
  const token = localStorage.getItem('client_token')
  socket = io('http://localhost:3000', { auth: { token } })

  socket.on('message:receive', async (msg) => {
    await fetchConversations()
    if (currentChat.value && currentChat.value.user_id === msg.sender_id) {
      chatMessages.value.push(msg)
      await nextTick()
      scrollToBottom()
    }
  })
})

onUnmounted(() => {
  if (socket) socket.disconnect()
})
</script>

<style scoped>
.messages-page { padding: 0; }
.msg-container {
  display: flex;
  height: calc(100vh - 100px);
  border: 1px solid rgba(240, 230, 224, 0.3);
  border-radius: 16px;
  overflow: hidden;
  background: #fff;
  box-shadow: 0 4px 24px rgba(0,0,0,0.04);
}

/* ===== 左侧会话列表 ===== */
.conv-list {
  width: 300px;
  border-right: 1px solid #F5F0EC;
  overflow-y: auto;
  flex-shrink: 0;
}
.conv-list-header {
  padding: 18px 20px;
  border-bottom: 1px solid #F5F0EC;
}
.conv-list-header h3 {
  margin: 0;
  font-size: 17px;
  font-weight: 700;
  color: #2D3436;
}
.conv-item {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 14px 20px;
  cursor: pointer;
  border-bottom: 1px solid #F8F4F0;
  position: relative;
  transition: all 0.2s;
}
.conv-item:hover { background: #FFFAF8; }
.conv-item.active { background: #FFF0EB; }
.conv-avatar {
  width: 40px;
  height: 40px;
  border-radius: 50%;
  background: linear-gradient(135deg, #A29BFE, #6C5CE7);
  color: #fff;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 16px;
  font-weight: 700;
  flex-shrink: 0;
}
.conv-info {
  flex: 1;
  min-width: 0;
}
.conv-top {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 4px;
}
.conv-name {
  font-weight: 600;
  font-size: 14px;
  color: #2D3436;
}
.conv-time {
  font-size: 11px;
  color: #B2BEC3;
}
.conv-last {
  font-size: 12px;
  color: #8892A0;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.conv-badge {
  position: absolute;
  top: 14px;
  right: 16px;
  min-width: 20px;
  height: 20px;
  background: linear-gradient(135deg, #FF7E67, #FD79A8);
  color: #fff;
  border-radius: 10px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 11px;
  font-weight: 700;
  padding: 0 6px;
}

/* ===== 右侧聊天区 ===== */
.chat-area {
  flex: 1;
  display: flex;
  flex-direction: column;
}
.empty-chat {
  justify-content: center;
  align-items: center;
}
.empty-chat-content {
  text-align: center;
  color: #8892A0;
}
.empty-chat-icon {
  font-size: 64px;
  display: block;
  margin-bottom: 12px;
}
.empty-chat-content p {
  font-size: 14px;
  margin: 0;
}
.chat-header {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 16px 24px;
  border-bottom: 1px solid #F5F0EC;
  font-weight: 600;
  font-size: 15px;
  color: #2D3436;
}
.chat-header-avatar {
  width: 36px;
  height: 36px;
  border-radius: 50%;
  background: linear-gradient(135deg, #A29BFE, #6C5CE7);
  color: #fff;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 14px;
  font-weight: 700;
}
.chat-messages {
  flex: 1;
  overflow-y: auto;
  padding: 20px 24px;
  display: flex;
  flex-direction: column;
  gap: 14px;
  background: #FFFAF8;
}
.chat-bubble {
  max-width: 70%;
  animation: fadeInUp 0.3s ease;
}
.chat-bubble.mine { align-self: flex-end; }
.chat-bubble.theirs { align-self: flex-start; }
.bubble-content {
  padding: 12px 18px;
  border-radius: 16px;
  font-size: 14px;
  line-height: 1.6;
  word-break: break-word;
}
.mine .bubble-content {
  background: linear-gradient(135deg, #FF7E67, #FD79A8);
  color: #fff;
  border-bottom-right-radius: 4px;
  box-shadow: 0 2px 8px rgba(255, 126, 103, 0.15);
}
.theirs .bubble-content {
  background: #fff;
  color: #2D3436;
  border-bottom-left-radius: 4px;
  box-shadow: 0 2px 8px rgba(0,0,0,0.04);
}
.bubble-time {
  font-size: 11px;
  color: #B2BEC3;
  margin-top: 4px;
  padding: 0 4px;
}
.mine .bubble-time { text-align: right; }

/* ===== 输入区 ===== */
.chat-input {
  display: flex;
  gap: 10px;
  padding: 16px 24px;
  border-top: 1px solid #F5F0EC;
  background: #fff;
}
.chat-input-field {
  flex: 1;
  padding: 10px 18px;
  border: 1px solid rgba(240, 230, 224, 0.4);
  border-radius: 14px;
  font-size: 14px;
  outline: none;
  transition: all 0.3s ease;
  background: #FFF8F5;
}
.chat-input-field:focus {
  border-color: #FF7E67;
  box-shadow: 0 0 0 3px rgba(255, 126, 103, 0.1);
}
.chat-input-field::placeholder {
  color: #B2BEC3;
}
.send-btn {
  padding: 10px 28px;
  background: linear-gradient(135deg, #FF7E67, #FD79A8);
  color: #fff;
  border: none;
  border-radius: 14px;
  font-size: 14px;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.3s ease;
}
.send-btn:hover:not(:disabled) {
  transform: translateY(-1px);
  box-shadow: 0 4px 15px rgba(255, 126, 103, 0.3);
}
.send-btn:disabled {
  opacity: 0.4;
  cursor: not-allowed;
}

@keyframes fadeInUp {
  from { opacity: 0; transform: translateY(8px); }
  to { opacity: 1; transform: translateY(0); }
}
</style>
