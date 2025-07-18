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

import ballerina/http;
import ballerina/ai;
import ballerina/jballerina.java;

isolated client class ProviderImpl {
    *ai:ModelProvider;

    isolated remote function chat(ai:ChatMessage[]|ai:ChatUserMessage messages, ai:ChatCompletionFunctions[] tools, string? stop)
        returns ai:ChatAssistantMessage|ai:LlmError {
        return {role: ai:ASSISTANT};
    }

    isolated remote function generate(ai:Prompt prompt, typedesc<anydata> td = <>) returns td|ai:Error = @java:Method {
        'class: "io.ballerina.lib.ai.MockGenerator"
    } external;
}

final ai:ModelProvider model = new ProviderImpl();
final ai:Agent agent = check new (
    systemPrompt = {
        role: "Math Tutor",
        instructions: "You are a school tutor assistant. " +
        "Provide answers to students' questions so they can compare their answers. " +
        "Use the tools when there is query related to math"
    },
    model = model,
    tools = [sum, mult, sqrt],
    verbose = true
);

@ai:AgentTool
isolated function sum(decimal a, decimal b) returns decimal => a + b;

@ai:AgentTool
isolated function mult(decimal a, decimal b) returns decimal => a * b;

@ai:AgentTool
isolated function sqrt(float a) returns float => a.sqrt();

service /api/v1 on new ai:Listener(9090) {
    resource function post chat(@http:Payload ai:ChatReqMessage request) returns ai:ChatRespMessage|error {
        string response = check agent.run(request.message, sessionId = request.sessionId);
        return {message: response};
    }
}
