// Copyright (c) 2025 WSO2 LLC (http://www.wso2.com).
//
// WSO2 LLC. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

# Represents a short-term memory store that retains a fixed number of recent messages by a key.
public type ShortTermMemoryStore isolated object {

    # Retrieves all stored interactive chat messages (i.e., all chat messages except the system
    # message) for a given key.
    # 
    # + key - The key associated with the memory
    # + return - A copy of the messages, or an `ai:MemoryError` error if the operation fails
    public isolated function get(string key) returns ChatInteractiveMessage[]|MemoryError;

    # Retrieves the system message, if it was provided, for a given key.
    # 
    # + key - The key associated with the memory
    # + return - A copy of the message if it was specified, nil if it was not, or an 
    # `ai:MemoryError` error if the operation fails
    public isolated function getChatSystemMessage(string key) returns ChatSystemMessage|MemoryError?;

    # Adds a chat message to the memory store for a given key.
    # 
    # + key - The key associated with the memory
    # + message - The `ChatMessage` message to store
    # + return - nil on success, or an `ai:Error` if the operation fails
    public isolated function put(string key, ChatMessage message) returns MemoryError?;

    # Removes all stored interactive chat messages (i.e., all chat messages except the system
    # message) for a given key.
    # 
    # + key - The key associated with the memory
    # + count - Optional number of messages to remove, starting from the first interactive message in; 
    #               if not provided, removes all messages
    # + return - nil on success, or an `ai:Error` if the operation fails
    public isolated function remove(string key, int? count = ()) returns MemoryError?;

    # Removes the system chat message, if specified, for a given key.
    # 
    # + key - The key associated with the memory
    # + return - nil on success or if there is no system chat message against the key, 
    #       or an `ai:Error` if the operation fails
    public isolated function removeChatSystemMessage(string key) returns MemoryError?;

    # Checks if the memory store is full for a given key.
    # 
    # + key - The key associated with the memory
    # + return - true if the memory store is full, false otherwise
    public isolated function isFull(string key) returns boolean;
};

# Provides an in-memory chat message store.
public isolated class InMemoryShortTermMemoryStore {
    *ShortTermMemoryStore;

    private final int size;
    private final map<MemoryChatSystemMessage> systemMessages = {};
    private final map<MemoryChatInteractiveMessage[]> messages = {};

    # Initializes a new in-memory store.
    # 
    # + size - The maximum capacity for stored messages
    public isolated function init(int size = 10) returns MemoryError? {
        if size < 3 {
            return error("Size must be at least 3");
        }

        self.size = size;
    }

    # Retrieves a copy of all stored messages, with an optional system prompt.
    #
    # + key - The key associated with the memory
    # + return - A copy of the messages or an empty array if there are no messages yet
    public isolated function get(string key) returns ChatInteractiveMessage[] {
        lock {
            if self.messages.hasKey(key) {
                return self.messages.get(key).clone();
            }
            return [];
        }
    }

    # Retrieves the system message, if it was provided, for a given key.
    # 
    # + key - The key associated with the memory
    # + return - A copy of the message if it was specified, nil if it was not
    public isolated function getChatSystemMessage(string key) returns ChatSystemMessage? {
        lock {
            if self.systemMessages.hasKey(key) {
                return self.systemMessages.get(key);
            }
            return;
        }
    }

    # Adds a message to the window.
    #
    # + key - The key associated with the memory
    # + message - The `ChatMessage` message to store
    # + return - nil on success, or `ai:MemoryError` error if the operation fails 
    public isolated function put(string key, ChatMessage message) returns MemoryError? {
        final readonly & MemoryChatMessage newMessage = check mapToMemoryChatMessage(message);
        lock {
            if newMessage is MemoryChatSystemMessage {
                self.systemMessages[key] = newMessage;
                return;
            }

            if !self.messages.hasKey(key) {
                self.messages[key] = [newMessage];
                return;
            }
            
            MemoryChatInteractiveMessage[] messages = self.messages.get(key);
            messages.push(newMessage);
        }
    }

    # Removes stored messages for a given key.
    # 
    # + key - The key associated with the memory
    # + count - Optional number of messages to remove, starting from the first non-system message in; 
    #               if not provided, removes all messages including the system message
    # + return - nil on success, or an `ai:MemoryError` error if the operation fails 
    public isolated function remove(string key, int? count = ()) returns MemoryError? {
        lock {
            if !self.messages.hasKey(key) {
                return;
            }

            if count is () {
                self.messages.get(key).removeAll();
                return;
            }

            // If a count is provided, remove that many user messages from the start.
            if count <= 0 {
                return error("Count must be a positive integer.");
            }
            
            MemoryChatMessage[] messages = self.messages.get(key);
            int countToRemove = count < messages.length() ? count : messages.length();

            foreach int index in 0 ..< countToRemove {
                _ = messages.shift();
            }
        }
    }

    # Removes the system chat message, if specified, for a given key.
    # 
    # + key - The key associated with the memory
    public isolated function removeChatSystemMessage(string key) {
        lock {
            if self.systemMessages.hasKey(key) {
                _ = self.systemMessages.remove(key);
            }
        }
    }

    # Checks if the memory store is full for a given key.
    # 
    # + key - The key associated with the memory
    # + return - true if the memory store is full, false otherwise
    public isolated function isFull(string key) returns boolean {
        lock {
            if !self.messages.hasKey(key) {
                return false;
            }

            return self.messages.get(key).length() == self.size;
        }
    }
}
