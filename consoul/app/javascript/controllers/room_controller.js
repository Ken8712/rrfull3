import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["timer", "heartCount", "lastActivity", "status", "currentUserEmotion", "partnerEmotion"]
  static values = { 
    roomId: Number,
    pollingInterval: { type: Number, default: 500 }
  }

  completedHandled = false

  connect() {
    console.log("Room controller connected for room:", this.roomIdValue)
    this.startPolling()
    
    // ページ可視性の変化を監視（バックグラウンド対策）
    document.addEventListener('visibilitychange', this.handleVisibilityChange.bind(this))
  }

  disconnect() {
    this.stopPolling()
    this.stopClientTimer()
    document.removeEventListener('visibilitychange', this.handleVisibilityChange.bind(this))
  }

  // ポーリング開始
  startPolling() {
    this.pollingTimer = setInterval(() => {
      this.fetchRoomStatus()
    }, this.pollingIntervalValue)
  }

  // ポーリング停止
  stopPolling() {
    if (this.pollingTimer) {
      clearInterval(this.pollingTimer)
      this.pollingTimer = null
    }
  }

  // ルームステータスを取得
  async fetchRoomStatus() {
    try {
      const response = await fetch(`/rooms/${this.roomIdValue}/status`, {
        headers: {
          "Accept": "application/json",
          "X-Requested-With": "XMLHttpRequest"
        }
      })

      if (response.ok) {
        const data = await response.json()
        this.updateUI(data.room)
      }
    } catch (error) {
      console.error("Failed to fetch room status:", error)
    }
  }

  // UI更新
  updateUI(roomData) {
    // リアルタイムタイマー更新
    if (this.hasTimerTarget) {
      if (roomData.timer_running) {
        // タイマーが動いている場合、クライアント側で計算
        this.startClientTimer(roomData.elapsed_seconds)
      } else {
        // タイマーが停止している場合、サーバーの値を使用
        this.stopClientTimer()
        this.timerTarget.textContent = roomData.elapsed_time
      }
    }

    // ハートカウント更新（アニメーション付き）
    if (this.hasHeartCountTarget) {
      const currentCount = parseInt(this.heartCountTarget.textContent) || 0
      const newCount = roomData.heart_count
      
      if (newCount > currentCount) {
        this.animateHeartCount(currentCount, newCount)
      } else {
        this.heartCountTarget.textContent = newCount
      }
    }

    // 最終アクティビティ更新
    if (this.hasLastActivityTarget && roomData.last_activity_at) {
      this.lastActivityTarget.textContent = roomData.last_activity_at
    }

    // 感情更新
    if (this.hasCurrentUserEmotionTarget && roomData.current_user_emotion) {
      this.currentUserEmotionTarget.textContent = roomData.current_user_emotion
    }
    
    if (this.hasPartnerEmotionTarget && roomData.partner_emotion) {
      this.partnerEmotionTarget.textContent = roomData.partner_emotion
    }

    // ステータス更新（ページリロードを避ける）
    if (this.hasStatusTarget) {
      const currentStatus = this.statusTarget.textContent.trim()
      if (currentStatus !== roomData.status) {
        this.statusTarget.textContent = roomData.status
        this.updateStatusBadge(roomData.status)
      }
    }
    
    // コントロールボタンは常に更新（タイマー状態が変わるため）
    this.updateControlButtons(roomData)
    
    // ルーム完了を検知
    if (roomData.status === 'completed' && !this.completedHandled) {
      this.handleRoomCompleted(roomData)
    }
  }

  // クライアント側タイマー開始
  startClientTimer(initialSeconds) {
    this.stopClientTimer() // 既存のタイマーを停止
    
    this.clientStartTime = Date.now()
    this.serverElapsedSeconds = initialSeconds
    
    this.clientTimer = setInterval(() => {
      const clientElapsed = Math.floor((Date.now() - this.clientStartTime) / 1000)
      const totalSeconds = this.serverElapsedSeconds + clientElapsed
      const formatted = this.formatTime(totalSeconds)
      
      if (this.hasTimerTarget) {
        this.timerTarget.textContent = formatted
      }
    }, 100) // 100ms間隔で更新（滑らかな表示）
  }

  // クライアント側タイマー停止
  stopClientTimer() {
    if (this.clientTimer) {
      clearInterval(this.clientTimer)
      this.clientTimer = null
    }
  }

  // 時間フォーマット
  formatTime(totalSeconds) {
    const minutes = Math.floor(totalSeconds / 60)
    const seconds = totalSeconds % 60
    return `${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`
  }

  // ハートカウントアニメーション
  animateHeartCount(from, to) {
    const duration = 500 // 0.5秒
    const startTime = Date.now()
    
    const animate = () => {
      const elapsed = Date.now() - startTime
      const progress = Math.min(elapsed / duration, 1)
      
      // イージング関数（ease-out）
      const easeOut = 1 - Math.pow(1 - progress, 3)
      const currentValue = Math.round(from + (to - from) * easeOut)
      
      this.heartCountTarget.textContent = currentValue
      
      if (progress < 1) {
        requestAnimationFrame(animate)
      }
    }
    
    requestAnimationFrame(animate)
  }

  // ステータスバッジ更新
  updateStatusBadge(status) {
    const badgeClasses = {
      'waiting': 'bg-yellow-100 text-yellow-800',
      'active': 'bg-green-100 text-green-800', 
      'completed': 'bg-gray-100 text-gray-800'
    }
    
    this.statusTarget.className = `inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${badgeClasses[status] || 'bg-gray-100 text-gray-800'}`
  }

  // コントロールボタン更新
  updateControlButtons(roomData) {
    const timerControls = this.element.querySelector('.timer-controls')
    if (!timerControls) return

    // 新しいボタンのHTML生成
    let buttonsHTML = ''
    
    if (roomData.status === 'active') {
      if (roomData.timer_running) {
        buttonsHTML = `<button class="px-6 py-3 bg-yellow-500 text-white rounded-lg hover:bg-yellow-600 active:bg-yellow-700 transition-colors touch-manipulation" data-action="click->room#pauseTimer">一時停止</button>`
      } else {
        buttonsHTML = `<button class="px-6 py-3 bg-green-500 text-white rounded-lg hover:bg-green-600 active:bg-green-700 transition-colors touch-manipulation" data-action="click->room#resumeTimer">再開</button>`
      }
      buttonsHTML += ` <button class="px-6 py-3 bg-red-500 text-white rounded-lg hover:bg-red-600 active:bg-red-700 transition-colors touch-manipulation" data-action="click->room#completeRoom">ルーム終了</button>`
    }

    // タイマーボタンのみを更新（ルーム終了ボタンは維持）
    const existingTimerButton = timerControls.querySelector('[data-action*="pauseTimer"], [data-action*="resumeTimer"]')
    const existingCompleteButton = timerControls.querySelector('[data-action*="completeRoom"]')
    
    if (roomData.status === 'active') {
      // 既存のボタンがない、または異なる場合のみ更新
      const needsUpdate = !existingTimerButton || 
        (roomData.timer_running && !existingTimerButton.matches('[data-action*="pauseTimer"]')) ||
        (!roomData.timer_running && !existingTimerButton.matches('[data-action*="resumeTimer"]'))
      
      if (needsUpdate) {
        timerControls.innerHTML = buttonsHTML
      }
    }
  }

  // ルーム開始
  async startRoom() {
    if (!confirm("ルームを開始しますか？")) return

    try {
      const response = await this.sendRoomAction("start")
      if (response.success) {
        this.updateUI(response.room)
        this.showNotification("ルームが開始されました")
        
        // ステータス表示を強制的に更新
        if (this.hasStatusTarget) {
          this.statusTarget.textContent = 'active'
          this.updateStatusBadge('active')
        }
        
        // waiting-sectionを非表示にし、active-sectionを表示
        const waitingSection = this.element.querySelector('.waiting-section')
        const activeSection = this.element.querySelector('.active-section')
        
        if (waitingSection) waitingSection.style.display = 'none'
        if (activeSection) activeSection.style.display = 'block'
      } else {
        this.showError(response.error)
      }
    } catch (error) {
      this.showError("ルームの開始に失敗しました")
    }
  }

  // タイマー一時停止
  async pauseTimer() {
    try {
      const response = await this.sendRoomAction("pause_timer")
      if (response.success) {
        this.updateUI(response.room)
        this.showNotification("タイマーを一時停止しました")
      } else {
        this.showError(response.error)
      }
    } catch (error) {
      this.showError("タイマー一時停止に失敗しました")
    }
  }

  // タイマー再開
  async resumeTimer() {
    try {
      const response = await this.sendRoomAction("resume_timer")
      if (response.success) {
        this.updateUI(response.room)
        this.showNotification("タイマーを再開しました")
      } else {
        this.showError(response.error)
      }
    } catch (error) {
      this.showError("タイマー再開に失敗しました")
    }
  }

  // ルーム終了
  async completeRoom() {
    if (!confirm("ルームを終了しますか？")) return

    try {
      const response = await this.sendRoomAction("complete")
      if (response.success) {
        this.updateUI(response.room)
        this.showNotification("ルームが終了されました")
        // handleRoomCompletedで処理されるため、ここでは何もしない
      } else {
        this.showError(response.error)
      }
    } catch (error) {
      this.showError("ルーム終了に失敗しました")
    }
  }

  // ルーム完了時の処理
  handleRoomCompleted(roomData) {
    this.completedHandled = true
    this.stopPolling()
    this.stopClientTimer()
    
    // セクションの切り替え
    const waitingSection = this.element.querySelector('.waiting-section')
    const activeSection = this.element.querySelector('.active-section')
    const completedSection = this.element.querySelector('.completed-section')
    
    if (waitingSection) waitingSection.style.display = 'none'
    if (activeSection) activeSection.style.display = 'none'
    if (completedSection) {
      completedSection.style.display = 'block'
      
      // 完了データを更新
      this.updateCompletedSection(roomData)
    }
    
    this.showNotification('ルームが終了しました')
  }

  // 完了セクションの内容更新
  updateCompletedSection(roomData) {
    const completedSection = this.element.querySelector('.completed-section')
    if (!completedSection) return

    // 総経過時間
    const elapsedTimeEl = completedSection.querySelector('[data-completed="elapsed-time"]')
    if (elapsedTimeEl) {
      elapsedTimeEl.textContent = roomData.elapsed_time
    }

    // 総ハート数
    const heartCountEl = completedSection.querySelector('[data-completed="heart-count"]')
    if (heartCountEl) {
      heartCountEl.textContent = roomData.heart_count
    }

    // 終了時刻
    const endedAtEl = completedSection.querySelector('[data-completed="ended-at"]')
    if (endedAtEl && roomData.ended_at) {
      endedAtEl.textContent = roomData.ended_at
    }
  }

  // ハート追加
  async addHeart() {
    try {
      const response = await this.sendRoomAction("add_heart")
      if (response.success) {
        this.updateUI(response.room)
        // ハートアニメーション効果
        this.animateHeartButton()
      } else {
        this.showError(response.error)
      }
    } catch (error) {
      this.showError("ハート送信に失敗しました")
    }
  }

  // アクティビティ更新
  async updateActivity() {
    try {
      const response = await this.sendRoomAction("update_activity")
      if (response.success) {
        this.updateUI(response.room)
        this.showNotification("アクティビティを更新しました")
      } else {
        this.showError(response.error)
      }
    } catch (error) {
      this.showError("アクティビティ更新に失敗しました")
    }
  }

  // 感情設定
  async setEmotion(event) {
    const emotion = event.target.dataset.emotion
    
    try {
      const response = await fetch(`/rooms/${this.roomIdValue}/set_emotion`, {
        method: "PATCH",
        headers: {
          "Accept": "application/json",
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content,
          "X-Requested-With": "XMLHttpRequest"
        },
        body: JSON.stringify({ emotion: emotion })
      })

      const data = await response.json()
      
      if (data.success) {
        this.updateUI(data.room)
        this.showNotification(`感情を ${emotion} に設定しました`)
        this.animateEmotionButton(event.target)
      } else {
        this.showError(data.error)
      }
    } catch (error) {
      this.showError("感情の設定に失敗しました")
    }
  }

  // 感情ボタンアニメーション
  animateEmotionButton(button) {
    button.classList.add('animate-bounce')
    setTimeout(() => {
      button.classList.remove('animate-bounce')
    }, 600)
  }

  // バックグラウンド/フォアグラウンド切り替え処理
  handleVisibilityChange() {
    if (document.hidden) {
      // バックグラウンドになった
      console.log('App went to background')
      // ポーリング間隔を長くする（バッテリー節約）
      this.stopPolling()
      this.pollingTimer = setInterval(() => {
        this.fetchRoomStatus()
      }, 5000) // 5秒間隔に
    } else {
      // フォアグラウンドに戻った
      console.log('App came to foreground')
      // 即座に最新状態を取得
      this.fetchRoomStatus()
      // 通常のポーリング間隔に戻す
      this.stopPolling()
      this.startPolling()
    }
  }

  // Room APIアクション送信
  async sendRoomAction(action) {
    try {
      const response = await fetch(`/rooms/${this.roomIdValue}/${action}`, {
        method: "PATCH",
        headers: {
          "Accept": "application/json",
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content,
          "X-Requested-With": "XMLHttpRequest"
        }
      })

      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`)
      }

      return await response.json()
    } catch (error) {
      console.error('Network error:', error)
      // ネットワークエラーの場合、リトライを示唆
      if (error.message.includes('Failed to fetch')) {
        this.showError("ネットワークエラー。接続を確認してください。")
      }
      throw error
    }
  }

  // ハートボタンアニメーション
  animateHeartButton() {
    const heartButton = this.element.querySelector('[data-action*="addHeart"]')
    if (heartButton) {
      heartButton.classList.add('animate-pulse')
      setTimeout(() => {
        heartButton.classList.remove('animate-pulse')
      }, 300)
    }
  }

  // 通知表示
  showNotification(message) {
    // 簡単なトースト通知（今後改善予定）
    const toast = document.createElement('div')
    toast.className = 'toast-notification'
    toast.textContent = message
    toast.style.cssText = `
      position: fixed;
      top: 20px;
      right: 20px;
      background: #28a745;
      color: white;
      padding: 10px 20px;
      border-radius: 5px;
      z-index: 1000;
    `
    document.body.appendChild(toast)

    setTimeout(() => {
      toast.remove()
    }, 3000)
  }

  // エラー表示
  showError(message) {
    const toast = document.createElement('div')
    toast.className = 'error-notification'
    toast.textContent = message
    toast.style.cssText = `
      position: fixed;
      top: 20px;
      right: 20px;
      background: #dc3545;
      color: white;
      padding: 10px 20px;
      border-radius: 5px;
      z-index: 1000;
    `
    document.body.appendChild(toast)

    setTimeout(() => {
      toast.remove()
    }, 3000)
  }
}