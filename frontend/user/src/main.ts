import { config, configManager, Config } from './config.js';
import { WebSocketAdapter } from '../shared/config/websocket-adapter.js';

// WebSocket client for user interface
class UserWebSocketClient {
    private ws: WebSocket | null = null;
    private wsUrl: string;
    private reconnectAttempts = 0;
    private maxReconnectAttempts: number;
    private reconnectDelay = 1000; // Start with 1 second
    private isConnecting = false;
    private isIntentionalDisconnect = false;

    // DOM elements
    private sendButton: HTMLButtonElement;
    private buttonText: HTMLSpanElement;
    private buttonLoader: HTMLSpanElement;
    private statusIndicator: HTMLElement;
    private statusDot: HTMLElement;
    private statusText: HTMLElement;
    private feedbackElement: HTMLElement;

    constructor() {
        // Use configuration from config file with dynamic refresh capability
        this.wsUrl = config.webSocketUrl;
        this.maxReconnectAttempts = config.maxReconnectAttempts;
        
        // Initialize DOM elements
        this.sendButton = document.getElementById('sendMessageBtn') as HTMLButtonElement;
        this.buttonText = this.sendButton.querySelector('.button-text') as HTMLSpanElement;
        this.buttonLoader = this.sendButton.querySelector('.button-loader') as HTMLSpanElement;
        this.statusIndicator = document.getElementById('connectionStatus') as HTMLElement;
        this.statusDot = this.statusIndicator.querySelector('.status-dot') as HTMLElement;
        this.statusText = this.statusIndicator.querySelector('.status-text') as HTMLElement;
        this.feedbackElement = document.getElementById('feedback') as HTMLElement;

        this.init();
        this.setupNetworkMonitoring();
    }

    private init(): void {
        // Add button click event listener
        this.sendButton.addEventListener('click', () => this.sendMessage());
        
        // Connect to WebSocket
        this.connect();
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
            console.log('WebSocket connected');
            this.isConnecting = false;
            this.reconnectAttempts = 0;
            this.reconnectDelay = 1000;
            this.updateConnectionStatus('connected', 'Connected');
            this.sendButton.disabled = false;
            this.showFeedback('Connected to messaging system', 'success');
        };

        this.ws.onclose = (event) => {
            console.log('WebSocket disconnected:', event.code, event.reason);
            this.isConnecting = false;
            this.updateConnectionStatus('disconnected', 'Disconnected');
            this.sendButton.disabled = true;

            if (!this.isIntentionalDisconnect) {
                this.showFeedback('Connection lost. Attempting to reconnect...', 'error');
                this.scheduleReconnect();
            }
        };

        this.ws.onerror = (error) => {
            console.error('WebSocket error:', error);
            this.handleConnectionError();
        };

        this.ws.onmessage = (event) => {
            console.log('Received message:', event.data);
            try {
                const message = JSON.parse(event.data);
                this.handleServerMessage(message);
            } catch (error) {
                console.error('Failed to parse server message:', error);
            }
        };
    }

    private handleConnectionError(): void {
        this.isConnecting = false;
        this.updateConnectionStatus('disconnected', 'Connection failed');
        this.sendButton.disabled = true;
        
        // Provide environment-specific error messages
        const currentConfig = configManager.getConfig();
        const errorMessage = this.getEnvironmentSpecificErrorMessage(currentConfig);
        this.showFeedback(errorMessage, 'error');
        
        this.scheduleReconnect();
    }

    private getEnvironmentSpecificErrorMessage(config: Config): string {
        return WebSocketAdapter.getErrorMessage(config.deploymentMode, 'connection');
    }

    private scheduleReconnect(): void {
        if (this.reconnectAttempts >= this.maxReconnectAttempts) {
            this.showFeedback('Unable to connect. Please refresh the page to try again.', 'error');
            return;
        }

        this.reconnectAttempts++;
        const currentConfig = configManager.getConfig();
        const delay = WebSocketAdapter.getReconnectInterval(currentConfig.deploymentMode, this.reconnectAttempts);
        
        this.updateConnectionStatus('connecting', `Reconnecting in ${Math.ceil(delay / 1000)}s...`);
        
        setTimeout(() => {
            if (!this.isIntentionalDisconnect) {
                this.connect();
            }
        }, delay);
    }

    private sendMessage(): void {
        if (!this.ws || this.ws.readyState !== WebSocket.OPEN) {
            this.showFeedback('Not connected. Please wait for connection to be established.', 'error');
            return;
        }

        // Disable button and show loading state
        this.sendButton.disabled = true;
        this.buttonText.style.display = 'none';
        this.buttonLoader.style.display = 'inline-block';

        const currentConfig = configManager.getConfig();
        const message = this.buildMessage(currentConfig);

        try {
            this.ws.send(JSON.stringify(message));
            console.log('Message sent:', message);
            
            // Set a timeout to handle cases where server doesn't respond
            const responseTimeout = setTimeout(() => {
                this.showFeedback('Message sent (no server response received)', 'info');
                this.resetButtonState();
            }, currentConfig.connectionTimeout || 3000);

            // Store timeout ID to clear it if we get a response
            (this.ws as any).responseTimeout = responseTimeout;
            
        } catch (error) {
            console.error('Failed to send message:', error);
            this.showFeedback('Failed to send message. Please try again.', 'error');
            this.resetButtonState();
        }
    }

    private buildMessage(config: Config): any {
        return WebSocketAdapter.buildMessage('sendMessage', {
            content: 'speak german'
        }, config);
    }

    private resetButtonState(): void {
        this.sendButton.disabled = false;
        this.buttonText.style.display = 'inline-block';
        this.buttonLoader.style.display = 'none';
    }

    private handleServerMessage(message: any): void {
        // Clear any pending response timeout
        if (this.ws && (this.ws as any).responseTimeout) {
            clearTimeout((this.ws as any).responseTimeout);
            (this.ws as any).responseTimeout = null;
        }

        // Handle server responses
        if (message.type === 'confirmation') {
            this.showFeedback('Message delivered to administrators', 'success');
            this.resetButtonState();
        } else if (message.type === 'error') {
            this.showFeedback(`Error: ${message.message}`, 'error');
            this.resetButtonState();
        } else if (message.statusCode === 200) {
            // Handle successful API Gateway response
            this.showFeedback('Message sent successfully!', 'success');
            this.resetButtonState();
        } else if (message.statusCode && message.statusCode !== 200) {
            // Handle API Gateway error responses
            this.showFeedback(`Server error (${message.statusCode}). Please try again.`, 'error');
            this.resetButtonState();
        } else {
            // Default success case for any other server response
            this.showFeedback('Message sent successfully!', 'success');
            this.resetButtonState();
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

    private showFeedback(message: string, type: 'success' | 'error' | 'info'): void {
        // Remove existing type classes
        this.feedbackElement.classList.remove('success', 'error', 'info');
        
        // Add new type class
        this.feedbackElement.classList.add(type);
        
        // Set message and show
        this.feedbackElement.textContent = message;
        this.feedbackElement.style.display = 'block';
        
        // Auto-hide success and info messages after 5 seconds
        if (type === 'success' || type === 'info') {
            setTimeout(() => {
                if (this.feedbackElement.classList.contains(type)) {
                    this.feedbackElement.style.display = 'none';
                }
            }, 5000);
        }
        
        // Auto-hide error messages after 10 seconds (longer for errors)
        if (type === 'error') {
            setTimeout(() => {
                if (this.feedbackElement.classList.contains('error')) {
                    this.feedbackElement.style.display = 'none';
                }
            }, 10000);
        }
    }

    private setupNetworkMonitoring(): void {
        // Monitor online/offline status
        window.addEventListener('online', () => {
            console.log('Network connection restored');
            this.showFeedback('Network connection restored. Reconnecting...', 'info');
            if (!this.ws || this.ws.readyState !== WebSocket.OPEN) {
                this.connect();
            }
        });

        window.addEventListener('offline', () => {
            console.log('Network connection lost');
            this.showFeedback('Network connection lost. Will reconnect when available.', 'error');
            this.updateConnectionStatus('disconnected', 'No network connection');
        });

        // Check if we're currently offline
        if (!navigator.onLine) {
            this.updateConnectionStatus('disconnected', 'No network connection');
            this.showFeedback('No network connection available', 'error');
        }
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
}

// Initialize the WebSocket client when the DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    const client = new UserWebSocketClient();
    
    // Handle page unload
    window.addEventListener('beforeunload', () => {
        client.disconnect();
    });
});