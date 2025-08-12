---@class AiChat
---@field options AiChatOptions
---@field setup fun(opts: AiChatOptions)

---@class AiChatOptions
---@field state StateOptions

---@class StateOptions
---@field llm_provider 'openai' | 'anthropic'
