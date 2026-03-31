<template>
  <div class="messages-page">
    <div class="msg-container">
      <!-- 左侧会话列表 -->
      <div class="conv-list">
        <h3>消息</h3>
        <div
          v-for="conv in conversations"
          :key="conv.user_id"
          :class="['conv-item', { active: currentChat?.user_id === conv.user_id }]"
          @click="selectConversation(conv)"
        >
          <div class="conv-info">
            <span class="conv-name">{{ conv.username }}</span>
            <span class="conv-time">{{ formatTime(conv.last_time) }}</span>
          </div>
          <div class="conv-last">{{ conv.last_message }}</div>
          <el-badge v-if="conv.unread > 0" :value="conv.unread" class="conv-badge" />
        </div>
        <el-empty v-if="conversations.length === 0" description="暂无消息" :image-size="80" />
      </div>

      <!-- 右侧聊天窗口 -->
      <div class="chat-area" v-if="currentChat">
        <div class="chat-header">
          <span>与 {{ currentChat.username }} 的对话</span>
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
          <el-input
            v-model="newMessage"
            placeholder="输入消息..."
            @keyup.enter="sendMessage"
            :maxlength="500"
          />
          <el-button type="primary" @click="sendMessage" :disabled="!newMessage.trim()">发送</el-button>
        </div>
      </div>
      <div class="chat-area empty-chat" v-else>
        <el-empty description="选择一个会话开始聊天" :image-size="120" />
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, nextTick, onUnmounted } from 'vue'
import { useRoute } from 'vue-router'
import api from '../api'
import { ElMessage } from 'element-plus'

const route = useRoute()
const userId = JSON.parse(localStorage.getItem('client_user') || '{}').id
const conversations = ref([])
const currentChat = ref(null)
const chatMessages = ref([])
const newMessage = ref('')
const msgListRef = ref(null)
let pollTimer = null

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
  // 轮询新消息
  pollTimer = setInterval(async () => {
    await fetchConversations()
    if (currentChat.value) {
      await fetchMessages(currentChat.value.user_id)
    }
  }, 5000)
})

onUnmounted(() => {
  if (pollTimer) clearInterval(pollTimer)
})
</script>

<style scoped>
.messages-page { padding: 0; }
.msg-container {
  display: flex;
  height: calc(100vh - 80px);
  border: 1px solid #e4e7ed;
  border-radius: 8px;
  overflow: hidden;
  background: #fff;
}
.conv-list {
  width: 280px;
  border-right: 1px solid #e4e7ed;
  overflow-y: auto;
  flex-shrink: 0;
}
.conv-list h3 {
  padding: 16px;
  margin: 0;
  border-bottom: 1px solid #e4e7ed;
  font-size: 16px;
}
.conv-item {
  padding: 12px 16px;
  cursor: pointer;
  border-bottom: 1px solid #f0f0f0;
  position: relative;
  transition: background 0.2s;
}
.conv-item:hover { background: #f5f7fa; }
.conv-item.active { background: #ecf5ff; }
.conv-info {
  display: flex; justify-content: space-between; align-items: center;
}
.conv-name { font-weight: 600; font-size: 14px; }
.conv-time { font-size: 11px; color: #999; }
.conv-last {
  font-size: 12px; color: #999; margin-top: 4px;
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
}
.conv-badge { position: absolute; top: 12px; right: 16px; }

.chat-area {
  flex: 1; display: flex; flex-direction: column;
}
.empty-chat {
  justify-content: center; align-items: center;
}
.chat-header {
  padding: 14px 20px;
  border-bottom: 1px solid #e4e7ed;
  font-weight: 600;
  font-size: 15px;
}
.chat-messages {
  flex: 1; overflow-y: auto; padding: 16px 20px;
  display: flex; flex-direction: column; gap: 12px;
}
.chat-bubble { max-width: 70%; }
.chat-bubble.mine { align-self: flex-end; }
.chat-bubble.theirs { align-self: flex-start; }
.bubble-content {
  padding: 10px 14px;
  border-radius: 12px;
  font-size: 14px;
  line-height: 1.5;
  word-break: break-word;
}
.mine .bubble-content {
  background: #409eff; color: #fff;
  border-bottom-right-radius: 4px;
}
.theirs .bubble-content {
  background: #f0f0f0; color: #333;
  border-bottom-left-radius: 4px;
}
.bubble-time {
  font-size: 11px; color: #999; margin-top: 4px;
}
.mine .bubble-time { text-align: right; }

.chat-input {
  display: flex; gap: 8px;
  padding: 12px 20px;
  border-top: 1px solid #e4e7ed;
}
.chat-input .el-input { flex: 1; }
</style>
