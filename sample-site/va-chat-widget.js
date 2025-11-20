/**
 * VA Chatbot Widget - JavaScript
 * Floating chat widget for available services
 */

class VAChatWidget {
    constructor(apiBaseUrl = 'http://localhost:8080') {
        this.version = '1.1.0-markdown'; // Version with markdown support
        console.log('[Widget] Version:', this.version);
        this.apiBaseUrl = apiBaseUrl;
        this.threadId = null;
        this.mode = 'chat'; // 'chat' or 'search'
        this.isOpen = false;
        
        this.init();
    }
    
    init() {
        // Create widget HTML
        this.createWidget();
        
        // Attach event listeners
        this.attachEventListeners();
        
        // Load thread from localStorage if exists
        this.loadThreadId();
    }
    
    createWidget() {
        // Create widget container
        const widgetHTML = `
            <div id="va-chat-widget">
                <!-- Chat Button (minimized) -->
                <button id="va-chat-button" aria-label="Open chat">
                    💬
                </button>
                
                <!-- Chat Container (expanded) -->
                <div id="va-chat-container">
                    <!-- Header -->
                    <div id="va-chat-header">
                        <h3>VA Assistant</h3>
                        <div class="va-header-controls">
                            <button id="va-clear-button" title="Clear conversation">🗑️</button>
                            <button id="va-minimize-button" title="Minimize">−</button>
                        </div>
                    </div>
                    
                    <!-- Mode Toggle -->
                    <div id="va-mode-toggle">
                        <button id="va-mode-chat" class="active">💬 Chat</button>
                        <button id="va-mode-search">🔍 Search</button>
                    </div>
                    
                    <!-- Messages Area -->
                    <div id="va-chat-messages">
                        <div class="va-message assistant">
                            <div class="va-message-content">
                                Hello! I'm the Virtual Assistant. How can I help you today?
                            </div>
                        </div>
                    </div>
                    
                    <!-- Input Area -->
                    <div id="va-chat-input-area">
                        <textarea 
                            id="va-chat-input" 
                            placeholder="Type your message..."
                            rows="1"
                            aria-label="Chat input"
                        ></textarea>
                        <button id="va-send-button" aria-label="Send message">
                            ➤
                        </button>
                    </div>
                </div>
            </div>
        `;
        
        // Inject into page
        document.body.insertAdjacentHTML('beforeend', widgetHTML);
    }
    
    attachEventListeners() {
        // Chat button (open)
        document.getElementById('va-chat-button').addEventListener('click', () => {
            this.openChat();
        });
        
        // Minimize button
        document.getElementById('va-minimize-button').addEventListener('click', () => {
            this.closeChat();
        });
        
        // Clear button
        document.getElementById('va-clear-button').addEventListener('click', () => {
            this.clearConversation();
        });
        
        // Mode toggle buttons
        document.getElementById('va-mode-chat').addEventListener('click', () => {
            this.setMode('chat');
        });
        
        document.getElementById('va-mode-search').addEventListener('click', () => {
            this.setMode('search');
        });
        
        // Send button
        document.getElementById('va-send-button').addEventListener('click', () => {
            this.sendMessage();
        });
        
        // Input field (Enter to send, Shift+Enter for new line)
        const input = document.getElementById('va-chat-input');
        input.addEventListener('keydown', (e) => {
            if (e.key === 'Enter' && !e.shiftKey) {
                e.preventDefault();
                this.sendMessage();
            }
        });
        
        // Auto-resize textarea
        input.addEventListener('input', () => {
            input.style.height = 'auto';
            input.style.height = Math.min(input.scrollHeight, 100) + 'px';
        });
        
        // Make widget draggable by header
        this.makeDraggable();
        
        // Make widget resizable from all corners
        this.makeResizable();
    }
    
    makeDraggable() {
        const header = document.getElementById('va-chat-header');
        const container = document.getElementById('va-chat-container');
        let isDragging = false;
        let currentX;
        let currentY;
        let initialX;
        let initialY;
        
        header.addEventListener('mousedown', (e) => {
            // Don't drag if clicking buttons
            if (e.target.tagName === 'BUTTON') return;
            
            isDragging = true;
            initialX = e.clientX - (container.offsetLeft || 0);
            initialY = e.clientY - (container.offsetTop || 0);
        });
        
        document.addEventListener('mousemove', (e) => {
            if (!isDragging) return;
            
            e.preventDefault();
            currentX = e.clientX - initialX;
            currentY = e.clientY - initialY;
            
            container.style.left = currentX + 'px';
            container.style.top = currentY + 'px';
            container.style.right = 'auto';
            container.style.bottom = 'auto';
            container.style.transform = 'none';
        });
        
        document.addEventListener('mouseup', () => {
            isDragging = false;
        });
    }
    
    makeResizable() {
        const container = document.getElementById('va-chat-container');
        const minWidth = 320;
        const minHeight = 400;
        
        console.log('[Widget] makeResizable() called, container:', container);
        
        // Create resize handles for all four corners
        const corners = ['nw', 'ne', 'sw', 'se'];
        
        corners.forEach(corner => {
            const handle = document.createElement('div');
            handle.className = `va-resize-handle va-resize-${corner}`;
            
            // Add inline styles to ensure visibility
            handle.style.cssText = `
                position: absolute;
                width: 20px;
                height: 20px;
                z-index: 10;
                background: #001489;
                border: 2px solid white;
                border-radius: 50%;
                opacity: 0.7;
            `;
            
            // Set position based on corner
            if (corner === 'nw') {
                handle.style.top = '-10px';
                handle.style.left = '-10px';
                handle.style.cursor = 'nw-resize';
            } else if (corner === 'ne') {
                handle.style.top = '-10px';
                handle.style.right = '-10px';
                handle.style.cursor = 'ne-resize';
            } else if (corner === 'sw') {
                handle.style.bottom = '-10px';
                handle.style.left = '-10px';
                handle.style.cursor = 'sw-resize';
            } else if (corner === 'se') {
                handle.style.bottom = '-10px';
                handle.style.right = '-10px';
                handle.style.cursor = 'se-resize';
            }
            
            container.appendChild(handle);
            console.log(`[Widget] Created resize handle: ${corner}`);
            
            let isResizing = false;
            let startX, startY, startWidth, startHeight, startLeft, startTop;
            
            handle.addEventListener('mousedown', (e) => {
                e.preventDefault();
                e.stopPropagation();
                isResizing = true;
                
                startX = e.clientX;
                startY = e.clientY;
                startWidth = container.offsetWidth;
                startHeight = container.offsetHeight;
                startLeft = container.offsetLeft;
                startTop = container.offsetTop;
                
                document.body.style.cursor = getComputedStyle(handle).cursor;
            });
            
            document.addEventListener('mousemove', (e) => {
                if (!isResizing) return;
                
                const dx = e.clientX - startX;
                const dy = e.clientY - startY;
                
                let newWidth = startWidth;
                let newHeight = startHeight;
                let newLeft = startLeft;
                let newTop = startTop;
                
                // Calculate new dimensions based on corner
                if (corner.includes('e')) {
                    newWidth = Math.max(minWidth, startWidth + dx);
                } else if (corner.includes('w')) {
                    newWidth = Math.max(minWidth, startWidth - dx);
                    newLeft = startLeft + (startWidth - newWidth);
                }
                
                if (corner.includes('s')) {
                    newHeight = Math.max(minHeight, startHeight + dy);
                } else if (corner.includes('n')) {
                    newHeight = Math.max(minHeight, startHeight - dy);
                    newTop = startTop + (startHeight - newHeight);
                }
                
                container.style.width = newWidth + 'px';
                container.style.height = newHeight + 'px';
                container.style.left = newLeft + 'px';
                container.style.top = newTop + 'px';
                container.style.right = 'auto';
                container.style.bottom = 'auto';
            });
            
            document.addEventListener('mouseup', () => {
                if (isResizing) {
                    isResizing = false;
                    document.body.style.cursor = '';
                }
            });
        });
    }
    
    openChat() {
        this.isOpen = true;
        document.getElementById('va-chat-button').classList.add('hidden');
        document.getElementById('va-chat-container').classList.add('active');
        document.getElementById('va-chat-input').focus();
    }
    
    closeChat() {
        this.isOpen = false;
        document.getElementById('va-chat-button').classList.remove('hidden');
        document.getElementById('va-chat-container').classList.remove('active');
    }
    
    setMode(mode) {
        this.mode = mode;
        
        // Update button states
        document.getElementById('va-mode-chat').classList.toggle('active', mode === 'chat');
        document.getElementById('va-mode-search').classList.toggle('active', mode === 'search');
        
        // Toggle search-mode class on container for full-width display
        const container = document.getElementById('va-chat-container');
        if (container) {
            if (mode === 'search') {
                container.classList.add('search-mode');
            } else {
                container.classList.remove('search-mode');
            }
        }
    }
    
    async sendMessage() {
        console.log('[Widget] sendMessage() called');
        const input = document.getElementById('va-chat-input');
        const message = input.value.trim();
        console.log('[Widget] Message from input:', message);
        
        if (!message) {
            console.warn('[Widget] Empty message, returning');
            return;
        }
        
        // Clear input and reset height
        input.value = '';
        input.style.height = 'auto';
        
        // Disable send button
        const sendButton = document.getElementById('va-send-button');
        sendButton.disabled = true;
        
        // Add user message to chat
        this.addMessage('user', message);
        
        // Show loading indicator
        this.showLoading();
        console.log('[Widget] Loading indicator shown');
        
        try {
            // Call API
            console.log('[Widget] Calling API with message:', message, 'mode:', this.mode);
            const response = await this.callChatAPI(message);
            console.log('[Widget] API response received:', response);
            
            // Remove loading indicator
            this.removeLoading();
            console.log('[Widget] Loading indicator removed');
            
            // Add assistant response
            if (this.mode === 'search' && response.search_results) {
                // Check if we have proper search results (not just fallback)
                const hasProperResults = response.search_results.length > 0 && 
                                        response.search_results.some(r => r.url && r.url !== '#');
                
                if (hasProperResults) {
                    console.log('[Widget] Adding search results:', response.search_results);
                    this.addSearchResults(response.search_results);
                } else {
                    // Display as message with linkified URLs
                    console.log('[Widget] No proper search results, displaying as message');
                    this.addMessage('assistant', response.message, response.citations);
                }
            } else {
                console.log('[Widget] Adding message response');
                this.addMessage('assistant', response.message, response.citations);
            }
            
            // Save thread ID
            if (response.thread_id) {
                this.threadId = response.thread_id;
                this.saveThreadId();
                console.log('[Widget] Thread ID saved:', this.threadId);
            }
            
        } catch (error) {
            console.error('[Widget] Error sending message:', error);
            console.error('[Widget] Error details:', error.message, error.stack);
            this.removeLoading();
            this.addError('Sorry, I encountered an error. Please try again.');
        } finally {
            sendButton.disabled = false;
            console.log('[Widget] Send button re-enabled');
        }
    }
    
    async callChatAPI(message) {
        console.log('[Widget] callChatAPI - URL:', `${this.apiBaseUrl}/api/chat`);
        console.log('[Widget] callChatAPI - Payload:', {message, thread_id: this.threadId, mode: this.mode});
        
        const response = await fetch(`${this.apiBaseUrl}/api/chat`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                message: message,
                thread_id: this.threadId,
                mode: this.mode
            })
        });
        
        console.log('[Widget] callChatAPI - Response status:', response.status);
        
        if (!response.ok) {
            throw new Error(`API error: ${response.status}`);
        }
        
        return await response.json();
    }
    
    addMessage(role, content, citations = null) {
        console.log('[Widget] addMessage called with content:', content);
        console.log('[Widget] Content length:', content.length);
        
        const messagesContainer = document.getElementById('va-chat-messages');
        
        const messageDiv = document.createElement('div');
        messageDiv.className = `va-message ${role}`;
        
        // Convert markdown to HTML and linkify URLs
        let processedContent = this.renderMarkdown(content);
        console.log('[Widget] Processed content:', processedContent.substring(0, 500));
        
        let html = `<div class="va-message-content">${processedContent}</div>`;
        
        // Add citations if available
        if (citations && citations.length > 0) {
            html += '<div class="va-citations">';
            html += '<div class="va-citations-title">Sources:</div>';
            citations.forEach((citation, index) => {
                if (citation.url && citation.url !== '#') {
                    html += `<a href="${citation.url}" class="va-citation" target="_blank">${index + 1}. ${this.escapeHtml(citation.title || 'Source')}</a>`;
                }
            });
            html += '</div>';
        }
        
        messageDiv.innerHTML = html;
        messagesContainer.appendChild(messageDiv);
        
        // Scroll to bottom
        this.scrollToBottom();
    }
    
    addSearchResults(results) {
        console.log('[Widget] addSearchResults called with:', results);
        console.log('[Widget] results type:', typeof results);
        console.log('[Widget] results is array:', Array.isArray(results));
        
        const messagesContainer = document.getElementById('va-chat-messages');
        
        const resultsDiv = document.createElement('div');
        resultsDiv.className = 'va-message assistant';
        
        let html = '<div class="va-search-results">';
        
        // Handle both array and object formats
        const resultsArray = Array.isArray(results) ? results : (results.results || []);
        console.log('[Widget] resultsArray:', resultsArray, 'length:', resultsArray.length);
        
        if (resultsArray.length === 0) {
            console.warn('[Widget] No search results to display');
            html += '<div class="va-search-result"><p>No search results found.</p></div>';
        } else {
            resultsArray.forEach((result, index) => {
                console.log(`[Widget] Processing result ${index}:`, result);
                html += '<div class="va-search-result">';
                // Don't escape URLs in href attributes to preserve functionality
                html += `<h4><a href="${result.url}" target="_blank" rel="noopener noreferrer">${this.escapeHtml(result.title)}</a></h4>`;
                if (result.url && result.url !== '#') {
                    html += `<div class="va-result-url"><a href="${result.url}" target="_blank" rel="noopener noreferrer">${this.escapeHtml(result.url)}</a></div>`;
                }
                // Convert newlines to br tags in snippet
                const snippetWithBreaks = this.escapeHtml(result.snippet).replace(/\n/g, '<br>');
                html += `<p>${snippetWithBreaks}</p>`;
                html += '</div>';
            });
        }
        
        html += '</div>';
        console.log('[Widget] Final HTML:', html);
        resultsDiv.innerHTML = html;
        console.log('[Widget] Appending to messages container');
        messagesContainer.appendChild(resultsDiv);
        
        this.scrollToBottom();
        console.log('[Widget] addSearchResults completed');
    }
    
    addError(message) {
        const messagesContainer = document.getElementById('va-chat-messages');
        
        const errorDiv = document.createElement('div');
        errorDiv.className = 'va-message assistant';
        errorDiv.innerHTML = `<div class="va-error">${this.escapeHtml(message)}</div>`;
        
        messagesContainer.appendChild(errorDiv);
        this.scrollToBottom();
    }
    
    showLoading() {
        const messagesContainer = document.getElementById('va-chat-messages');
        
        const loadingDiv = document.createElement('div');
        loadingDiv.className = 'va-message assistant';
        loadingDiv.id = 'va-loading-indicator';
        loadingDiv.innerHTML = `
            <div class="va-loading">
                <span></span>
                <span></span>
                <span></span>
            </div>
        `;
        
        messagesContainer.appendChild(loadingDiv);
        this.scrollToBottom();
    }
    
    removeLoading() {
        const loadingIndicator = document.getElementById('va-loading-indicator');
        if (loadingIndicator) {
            loadingIndicator.remove();
        }
    }
    
    clearConversation() {
        const messagesContainer = document.getElementById('va-chat-messages');
        messagesContainer.innerHTML = `
            <div class="va-message assistant">
                <div class="va-message-content">
                    Hello! I'm the Virtual Assistant. How can I help you today?
                </div>
            </div>
        `;
        
        // Clear thread
        this.threadId = null;
        localStorage.removeItem('va_thread_id');
    }
    
    scrollToBottom() {
        const messagesContainer = document.getElementById('va-chat-messages');
        messagesContainer.scrollTop = messagesContainer.scrollHeight;
    }
    
    saveThreadId() {
        if (this.threadId) {
            localStorage.setItem('va_thread_id', this.threadId);
        }
    }
    
    loadThreadId() {
        this.threadId = localStorage.getItem('va_thread_id');
    }
    
    escapeHtml(text) {
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }
    
    renderMarkdown(text) {
        // First escape HTML to prevent XSS
        let escaped = this.escapeHtml(text);
        
        // Convert markdown syntax to HTML
        // Bold: **text** or __text__
        escaped = escaped.replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>');
        escaped = escaped.replace(/__(.+?)__/g, '<strong>$1</strong>');
        
        // Italic: *text* or _text_
        escaped = escaped.replace(/\*(.+?)\*/g, '<em>$1</em>');
        escaped = escaped.replace(/_(.+?)_/g, '<em>$1</em>');
        
        // Code: `text`
        escaped = escaped.replace(/`(.+?)`/g, '<code>$1</code>');
        
        // Headers: ## Header
        escaped = escaped.replace(/^### (.+)$/gm, '<h4>$1</h4>');
        escaped = escaped.replace(/^## (.+)$/gm, '<h3>$1</h3>');
        escaped = escaped.replace(/^# (.+)$/gm, '<h2>$1</h2>');
        
        // Unordered lists: - item or * item
        escaped = escaped.replace(/^[\-\*] (.+)$/gm, '<li>$1</li>');
        escaped = escaped.replace(/(<li>.*<\/li>\n?)+/g, '<ul>$&</ul>');
        
        // Ordered lists: 1. item
        escaped = escaped.replace(/^\d+\. (.+)$/gm, '<li>$1</li>');
        
        // Convert newlines to <br> tags, but not inside lists
        escaped = escaped.replace(/\n(?!<\/?(ul|li))/g, '<br>');
        
        // Convert URLs to clickable links
        const urlRegex = /(https?:\/\/[^\s<]+)/g;
        escaped = escaped.replace(urlRegex, (url) => {
            let cleanUrl = url.replace(/[.,;:!?)\]]+$/, '');
            return `<a href="${cleanUrl}" target="_blank" rel="noopener noreferrer" style="color: #1a0dab; text-decoration: underline;">${cleanUrl}</a>`;
        });
        
        return escaped;
    }
    
    linkifyUrls(text) {
        // First escape the HTML
        const escaped = this.escapeHtml(text);
        
        // Convert newlines to <br> tags to preserve formatting
        const withBreaks = escaped.replace(/\n/g, '<br>');
        
        // Then convert URLs to clickable links
        // Match http://, https://, and www. URLs
        const urlRegex = /(https?:\/\/[^\s<]+)/g;
        
        return withBreaks.replace(urlRegex, (url) => {
            // Remove trailing punctuation that's not part of the URL
            let cleanUrl = url.replace(/[.,;:!?)\]]+$/, '');
            return `<a href="${cleanUrl}" target="_blank" rel="noopener noreferrer" style="color: #1a0dab; text-decoration: underline;">${cleanUrl}</a>`;
        });
    }
    
    // Public API methods for external integration
    open() {
        console.log('[Widget] open() called');
        this.isOpen = true;
        const container = document.getElementById('va-chat-container');
        const button = document.getElementById('va-chat-button');
        if (container && button) {
            container.classList.add('active');
            button.classList.add('hidden');
            console.log('[Widget] Widget opened - container active, button hidden');
        } else {
            console.error('[Widget] Could not find container or button elements');
        }
    }
    
    close() {
        console.log('[Widget] close() called');
        this.isOpen = false;
        const container = document.getElementById('va-chat-container');
        const button = document.getElementById('va-chat-button');
        if (container && button) {
            container.classList.remove('active');
            button.classList.remove('hidden');
            console.log('[Widget] Widget closed - container inactive, button visible');
        }
    }
    
    search(query) {
        console.log('[Widget] search() called with:', query);
        
        // Switch to search mode
        this.mode = 'search';
        console.log('[Widget] Mode set to:', this.mode);
        
        // Add search-mode class to container for full-width display
        const container = document.getElementById('va-chat-container');
        if (container) {
            container.classList.add('search-mode');
            console.log('[Widget] Added search-mode class to container');
        }
        
        const searchButton = document.getElementById('va-mode-search');
        const chatButton = document.getElementById('va-mode-chat');
        if (searchButton && chatButton) {
            searchButton.classList.add('active');
            chatButton.classList.remove('active');
            console.log('[Widget] Mode buttons updated');
        }
        
        // Set the query in the input
        const input = document.getElementById('va-chat-input');
        if (input) {
            input.value = query;
            console.log('[Widget] Input value set to:', input.value);
        } else {
            console.error('[Widget] Input element not found!');
        }
        
        // Trigger send
        console.log('[Widget] Calling sendMessage()...');
        this.sendMessage();
    }
}

// Initialize widget when DOM is ready
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => {
        window.VAChatWidget = new VAChatWidget();
        // Expose as VAChat for external integration
        window.VAChat = window.VAChatWidget;
    });
} else {
    window.VAChatWidget = new VAChatWidget();
    // Expose as VAChat for external integration
    window.VAChat = window.VAChatWidget;
}

