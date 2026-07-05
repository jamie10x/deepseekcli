"""Pydantic models for Anthropic-compatible requests."""

from enum import StrEnum
from typing import Any, Literal

from pydantic import BaseModel, ConfigDict, Field, model_validator


# =============================================================================
# Content Block Types
# =============================================================================
class Role(StrEnum):
    user = "user"
    assistant = "assistant"
    system = "system"


class _AnthropicBlockBase(BaseModel):
    """Pass through provider fields (e.g. ``cache_control``) for native transports."""

    model_config = ConfigDict(extra="allow")


class ContentBlockText(_AnthropicBlockBase):
    type: Literal["text"]
    text: str


class ContentBlockImage(_AnthropicBlockBase):
    type: Literal["image"]
    source: dict[str, Any]


class ContentBlockDocument(_AnthropicBlockBase):
    """Anthropic document block (e.g. PDF files via the Files API)."""

    type: Literal["document"]
    source: dict[str, Any]


class ContentBlockToolUse(_AnthropicBlockBase):
    type: Literal["tool_use"]
    id: str
    name: str
    input: dict[str, Any]


class ContentBlockToolResult(_AnthropicBlockBase):
    type: Literal["tool_result"]
    tool_use_id: str
    content: str | list[Any] | dict[str, Any]


class ContentBlockThinking(_AnthropicBlockBase):
    type: Literal["thinking"]
    thinking: str
    signature: str | None = None


class ContentBlockRedactedThinking(_AnthropicBlockBase):
    type: Literal["redacted_thinking"]
    data: str


class ContentBlockServerToolUse(_AnthropicBlockBase):
    """Anthropic server-side tool invocation (e.g. ``web_search``, ``web_fetch``)."""

    type: Literal["server_tool_use"]
    id: str
    name: str
    input: dict[str, Any]


class ContentBlockWebSearchToolResult(_AnthropicBlockBase):
    type: Literal["web_search_tool_result"]
    tool_use_id: str
    content: Any


class ContentBlockWebFetchToolResult(_AnthropicBlockBase):
    type: Literal["web_fetch_tool_result"]
    tool_use_id: str
    content: Any


class SystemContent(_AnthropicBlockBase):
    type: Literal["text"]
    text: str


# =============================================================================
# Message Types
# =============================================================================
class Message(BaseModel):
    # Accept "system" so Claude Code messages that embed a system turn
    # inside the messages array pass Pydantic validation. The service layer
    # hoists these into the top-level ``system`` field before forwarding.
    role: Literal["user", "assistant", "system"]
    content: (
        str
        | list[
            ContentBlockText
            | ContentBlockImage
            | ContentBlockDocument
            | ContentBlockToolUse
            | ContentBlockToolResult
            | ContentBlockThinking
            | ContentBlockRedactedThinking
            | ContentBlockServerToolUse
            | ContentBlockWebSearchToolResult
            | ContentBlockWebFetchToolResult
        ]
    )
    reasoning_content: str | None = None


class Tool(_AnthropicBlockBase):
    name: str
    # Anthropic server tools (e.g. web_search beta tools) include a ``type`` and
    # may omit ``input_schema`` because the provider owns the schema.
    type: str | None = None
    description: str | None = None
    input_schema: dict[str, Any] | None = None


class ThinkingConfig(BaseModel):
    enabled: bool | None = True
    type: str | None = None
    budget_tokens: int | None = None


# =============================================================================
# Request Models
# =============================================================================
class MessagesRequest(BaseModel):
    model_config = ConfigDict(extra="allow")

    model: str
    # Internal routing / debug: accepted on parse but not serialized to providers.
    original_model: str | None = Field(default=None, exclude=True)
    resolved_provider_model: str | None = Field(default=None, exclude=True)
    max_tokens: int | None = None
    messages: list[Message]
    system: str | list[SystemContent] | None = None

    @model_validator(mode="after")
    def _hoist_system_messages(self) -> MessagesRequest:
        """Move system-role messages from the messages list into the system field.

        Some Claude Code versions embed system turns inside the messages array
        instead of the top-level system parameter. The Anthropic spec (and all
        provider transports) expect system content at the top level only.
        """
        system_msgs = [m for m in self.messages if m.role == "system"]
        if not system_msgs:
            return self

        # Collect text from all system-role messages.
        extra_system_texts: list[str] = []
        for msg in system_msgs:
            if isinstance(msg.content, str):
                extra_system_texts.append(msg.content)
            else:
                extra_system_texts.extend(
                    block.text
                    for block in msg.content
                    if isinstance(block, ContentBlockText)
                )

        if extra_system_texts:
            extra_text = "\n".join(extra_system_texts)
            if self.system is None:
                self.system = extra_text
            elif isinstance(self.system, str):
                self.system = self.system + "\n" + extra_text
            else:
                # list[SystemContent] — append a new block
                self.system = [
                    *self.system,
                    SystemContent(type="text", text=extra_text),
                ]

        # Drop system-role messages from the list.
        self.messages = [m for m in self.messages if m.role != "system"]
        return self

    stop_sequences: list[str] | None = None
    stream: bool | None = True
    temperature: float | None = None
    top_p: float | None = None
    top_k: int | None = None
    metadata: dict[str, Any] | None = None
    tools: list[Tool] | None = None
    tool_choice: dict[str, Any] | None = None
    thinking: ThinkingConfig | None = None
    # Native Anthropic / SDK client hints: ignored (not forwarded) for OpenAI Chat conversion.
    context_management: dict[str, Any] | None = None
    output_config: dict[str, Any] | None = None
    mcp_servers: list[dict[str, Any]] | None = None
    extra_body: dict[str, Any] | None = None
    # Beta feature flags sent by Claude Code as a body field; accepted but never forwarded.
    betas: list[str] | None = Field(default=None, exclude=True)


class TokenCountRequest(BaseModel):
    model_config = ConfigDict(extra="allow")

    model: str
    original_model: str | None = Field(default=None, exclude=True)
    resolved_provider_model: str | None = Field(default=None, exclude=True)
    messages: list[Message]
    system: str | list[SystemContent] | None = None
    tools: list[Tool] | None = None
    thinking: ThinkingConfig | None = None
    tool_choice: dict[str, Any] | None = None
    context_management: dict[str, Any] | None = None
    output_config: dict[str, Any] | None = None
    mcp_servers: list[dict[str, Any]] | None = None
    betas: list[str] | None = Field(default=None, exclude=True)
