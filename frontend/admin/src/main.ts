import { config, configManager, Config } from './config.js';
import { WebSocketAdapter } from '../shared/config/websocket-adapter.js';

// WebSocket client for admin interface
interface Message {
    content: string;
    timestamp: number;
    connectionId: string;
}

class AdminWebSocketClient {
    private ws: WebSocket | null = null;
    private wsUrl: string;
    private reconnectAttempts = 0;
    private maxReconnectAttempts: number;
    private reconnectDelay = 1000; // Start with 1 second
    private isConnecting = false;
    private isIntentionalDisconnect = false;
    private messageCount = 0;

    // DOM elements
    private statusIndicator: HTMLElement;
    private statusDot: HTMLElement;
    private statusText: HTMLElement;
    private messageList: HTMLElement;
    private messageCountElement: HTMLElement;
    private noMessagesElement: HTMLElement;

    constructor() {
        // Use configuration from config file with dynamic refresh capability
        this.wsUrl = config.webSocketUrl;
        this.maxReconnectAttempts = config.maxReconnectAttempts;
        
        // Initialize DOM elements
        this.statusIndicator = document.getElementById('connectionStatus') as HTMLElement;
        this.statusDot = this.statusIndicator.querySelector('.status-dot') as HTMLElement;
        this.statusText = this.statusIndicator.querySelector('.status-text') as HTMLElement;
        this.messageList = document.getElementById('messageList') as HTMLElement;
        this.messageCountElement = document.getElementById('messageCount') as HTMLElement;
        this.noMessagesElement = this.messageList.querySelector('.no-messages') as HTMLElement;

        this.init();
        this.setupNetworkMonitoring();
    }

    private init(): void {
        // Connect to WebSocket
        this.connect();
        
        // Set up periodic connection health check
        setInterval(() => this.checkConnectionHealth(), 30000); // Check every 30 seconds
    }

    private connect(): void {
        if (this.isConnecting || (this.ws && this.ws.readyState === WebSocket.CONNECTING)) {
            return;
        }

        this.isConnecting = true;
        this.isIntentionalDisconnect = false;
        this.updateConnectionStatus('connecting', 'Connecting...');

        try {
            // Refresh configuration to get latest WebSocket URL
            const currentConfig = configManager.refreshConfig();
            this.wsUrl = currentConfig.webSocketUrl;
            this.maxReconnectAttempts = currentConfig.maxReconnectAttempts;

            // Create WebSocket connection with environment-specific parameters
            this.ws = this.createWebSocketConnection(this.wsUrl, currentConfig);
            this.setupWebSocketEventHandlers();
        } catch (error) {
            console.error('Failed to create WebSocket connection:', error);
            this.handleConnectionError();
        }
    }

    private createWebSocketConnection(url: string, config: Config): WebSocket {
        // Use WebSocket adapter for environment-specific connection
        return WebSocketAdapter.createConnection(url, {
            connectionType: config.connectionType,
            deploymentMode: config.deploymentMode,
            enableLogging: config.enableLogging,
            connectionTimeout: config.connectionTimeout
        });
    }

    private setupWebSocketEventHandlers(): void {
        if (!this.ws) return;

        this.ws.onopen = () => {
            console.log('Admin WebSocket connected');
            this.isConnecting = false;
            this.reconnectAttempts = 0;
            this.reconnectDelay = 1000;
            this.updateConnectionStatus('connected', 'Connected - Monitoring messages');
            
            // Send identification message to mark this as an admin connection
            this.identifyAsAdmin();
        };

        this.ws.onclose = (event) => {
            console.log('Admin WebSocket disconnected:', event.code, event.reason);
            this.isConnecting = false;
            this.updateConnectionStatus('disconnected', 'Disconnected');

            if (!this.isIntentionalDisconnect) {
                this.scheduleReconnect();
            }
        };

        this.ws.onerror = (error) => {
            console.error('Admin WebSocket error:', error);
            this.handleConnectionError();
        };

        this.ws.onmessage = (event) => {
            console.log('Admin received message:', event.data);
            try {
                const data = JSON.parse(event.data);
                this.handleIncomingMessage(data);
            } catch (error) {
                console.error('Failed to parse incoming message:', error);
            }
        };
    }

    private identifyAsAdmin(): void {
        if (!this.ws || this.ws.readyState !== WebSocket.OPEN) return;

        const currentConfig = configManager.getConfig();
        const identificationMessage = this.buildIdentificationMessage(currentConfig);

        try {
            this.ws.send(JSON.stringify(identificationMessage));
            console.log('Admin identification sent:', identificationMessage);
        } catch (error) {
            console.error('Failed to send admin identification:', error);
        }
    }

    private buildIdentificationMessage(config: Config): any {
        return WebSocketAdapter.buildMessage('identify', {
            type: 'admin',
            deploymentMode: config.deploymentMode
        }, config);
    }

    private handleConnectionError(): void {
        this.isConnecting = false;
        this.updateConnectionStatus('disconnected', 'Connection failed');
        
        // Log environment-specific error information
        const currentConfig = configManager.getConfig();
        console.error(`Admin WebSocket connection failed in ${currentConfig.deploymentMode} mode`);
        
        this.scheduleReconnect();
    }

    private scheduleReconnect(): void {
        if (this.reconnectAttempts >= this.maxReconnectAttempts) {
            this.updateConnectionStatus('disconnected', 'Connection failed - Refresh to retry');
            return;
        }

        this.reconnectAttempts++;
        const currentConfig = configManager.getConfig();
        const delay = WebSocketAdapter.getReconnectInterval(currentConfig.deploymentMode, this.reconnectAttempts);
        
        this.updateConnectionStatus('connecting', `Reconnecting in ${Math.ceil(delay / 1000)}s... (${this.reconnectAttempts}/${this.maxReconnectAttempts})`);
        
        setTimeout(() => {
            if (!this.isIntentionalDisconnect) {
                this.connect();
            }
        }, delay);
    }

    private handleIncomingMessage(data: any): void {
        // Handle different types of messages
        if (data.type === 'message' || data.content) {
            // This is a user message that should be displayed
            const message: Message = {
                content: data.content || data.data?.content || 'speak german',
                timestamp: data.timestamp || Date.now(),
                connectionId: data.connectionId || data.sourceConnectionId || 'unknown'
            };
            
            this.displayMessage(message);
        } else if (data.type === 'confirmation') {
            // Connection confirmation or other system messages
            console.log('System confirmation:', data);
        } else if (data.statusCode === 200) {
            // API Gateway success response
            console.log('API Gateway response:', data);
        } else {
            // Log any other message types for debugging
            console.log('Unknown message type:', data);
        }
    }

    private displayMessage(message: Message): void {
        // Hide "no messages" placeholder if it's visible
        if (this.noMessagesElement && this.noMessagesElement.style.display !== 'none') {
            this.noMessagesElement.style.display = 'none';
        }

        // Create message element
        const messageElement = this.createMessageElement(message);
        
        // Add to the top of the message list (most recent first)
        this.messageList.insertBefore(messageElement, this.messageList.firstChild);
        
        // Update message count
        this.messageCount++;
        this.updateMessageCount();
        
        // Add highlight animation for new messages
        messageElement.classList.add('new');
        setTimeout(() => {
            messageElement.classList.remove('new');
        }, 2000);
        
        // Scroll to top to show the new message
        this.messageList.scrollTop = 0;
        
        // Limit the number of displayed messages to prevent memory issues
        this.limitDisplayedMessages();
    }

    private createMessageElement(message: Message): HTMLElement {
        const messageDiv = document.createElement('div');
        messageDiv.className = 'message-item';
        
        const timestamp = new Date(message.timestamp);
        const timeString = timestamp.toLocaleTimeString();
        const dateString = timestamp.toLocaleDateString();
        
        messageDiv.innerHTML = `
            <div class="message-header-info">
                <span class="message-timestamp">${dateString} ${timeString}</span>
                <span class="message-id">ID: ${message.connectionId.substring(0, 8)}...</span>
            </div>
            <div class="message-content">${this.escapeHtml(message.content)}</div>
        `;
        
        return messageDiv;
    }

    private escapeHtml(text: string): string {
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }

    private updateMessageCount(): void {
        this.messageCountElement.textContent = this.messageCount.toString();
    }

    private limitDisplayedMessages(): void {
        const maxMessages = 100; // Keep only the last 100 messages
        const messages = this.messageList.querySelectorAll('.message-item');
        
        if (messages.length > maxMessages) {
            for (let i = maxMessages; i < messages.length; i++) {
                messages[i].remove();
            }
        }
    }

    private updateConnectionStatus(status: 'connecting' | 'connected' | 'disconnected', text: string): void {
        // Remove all status classes
        this.statusDot.classList.remove('connecting', 'connected', 'disconnected');
        
        // Add current status class
        this.statusDot.classList.add(status);
        
        // Update status text
        this.statusText.textContent = text;
    }

    private checkConnectionHealth(): void {
        if (!this.ws || this.ws.readyState !== WebSocket.OPEN) {
            console.log('Connection health check: Not connected, attempting reconnect');
            if (!this.isConnecting && !this.isIntentionalDisconnect) {
                this.connect();
            }
            return;
        }

        // Send a ping to check if connection is still alive
        try {
            this.ws.send(JSON.stringify({ action: 'ping' }));
        } catch (error) {
            console.error('Health check ping failed:', error);
            this.handleConnectionError();
        }
    }

    private setupNetworkMonitoring(): void {
        // Monitor online/offline status
        window.addEventListener('online', () => {
            console.log('Network connection restored');
            this.updateConnectionStatus('connecting', 'Network restored - Reconnecting...');
            if (!this.ws || this.ws.readyState !== WebSocket.OPEN) {
                this.connect();
            }
        });

        window.addEventListener('offline', () => {
            console.log('Network connection lost');
            this.updateConnectionStatus('disconnected', 'No network connection');
        });

        // Check if we're currently offline
        if (!navigator.onLine) {
            this.updateConnectionStatus('disconnected', 'No network connection');
        }

        // Handle page visibility changes (reconnect when page becomes visible)
        document.addEventListener('visibilitychange', () => {
            if (!document.hidden && (!this.ws || this.ws.readyState !== WebSocket.OPEN)) {
                console.log('Page became visible, checking connection');
                if (!this.isConnecting && !this.isIntentionalDisconnect) {
                    this.connect();
                }
            }
        });
    }

    public disconnect(): void {
        this.isIntentionalDisconnect = true;
        if (this.ws) {
            this.ws.close();
        }
    }

    public reconnectWithNewConfig(): void {
        // Force configuration refresh and reconnect
        this.isIntentionalDisconnect = false;
        if (this.ws) {
            this.ws.close();
        }
        // Connection will be re-established in onclose handler
    }

    public getCurrentConfig(): Config {
        return configManager.getConfig();
    }

    public validateCurrentConnection(): boolean {
        return configManager.isConfigurationValid() && 
               this.ws !== null && 
               this.ws.readyState === WebSocket.OPEN;
    }

    public getConnectionStatus(): string {
        if (!this.ws) return 'disconnected';
        
        switch (this.ws.readyState) {
            case WebSocket.CONNECTING:
                return 'connecting';
            case WebSocket.OPEN:
                return 'connected';
            case WebSocket.CLOSING:
            case WebSocket.CLOSED:
            default:
                return 'disconnected';
        }
    }

    public getMessageCount(): number {
        return this.messageCount;
    }
}

// Initialize the admin WebSocket client when the DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    const adminClient = new AdminWebSocketClient();
    
    // Handle page unload
    window.addEventListener('beforeunload', () => {
        adminClient.disconnect();
    });
    
    // Make client available globally for debugging
    (window as any).adminClient = adminClient;
});