"use client";

import { useEffect, useRef, useState, type FormEvent, type KeyboardEvent } from "react";

import { MAX_CHAT_MESSAGE_LENGTH, type ChatContext, type ChatRole } from "@/lib/chat-validation";

type DisplayMessage = Readonly<{
  id: string;
  role: ChatRole;
  content: string;
  local?: boolean;
}>;

type GameChatProps = Readonly<{
  accessToken: string;
  context: ChatContext;
}>;

const WELCOME_MESSAGE: DisplayMessage = {
  id: "welcome",
  role: "assistant",
  content: "I am Shift, your Bedrock-powered game assistant. Ask for a Snake tactic or anything else on your mind.",
  local: true,
};

function messageId() {
  return window.crypto.randomUUID();
}

function parseEventBlock(block: string) {
  const event = block
    .split("\n")
    .find((line) => line.startsWith("event:"))
    ?.slice(6)
    .trim();
  const data = block
    .split("\n")
    .find((line) => line.startsWith("data:"))
    ?.slice(5)
    .trim();

  if (!event || !data) {
    return null;
  }

  try {
    return { event, payload: JSON.parse(data) as Record<string, unknown> };
  } catch {
    return null;
  }
}

export function GameChat({ accessToken, context }: GameChatProps) {
  const [open, setOpen] = useState(false);
  const [messages, setMessages] = useState<DisplayMessage[]>([WELCOME_MESSAGE]);
  const [draft, setDraft] = useState("");
  const [sending, setSending] = useState(false);
  const transcriptEndRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    transcriptEndRef.current?.scrollIntoView({ block: "nearest" });
  }, [messages]);

  const sendMessage = async (event?: FormEvent) => {
    event?.preventDefault();
    const message = draft.trim();
    if (!message || sending) {
      return;
    }

    const userMessage: DisplayMessage = {
      id: messageId(),
      role: "user",
      content: message,
    };
    const assistantId = messageId();
    const priorHistory = messages
      .filter((item) => !item.local && item.content)
      .slice(-8)
      .map(({ role, content }) => ({ role, content }));

    setDraft("");
    setSending(true);
    setMessages((current) => [
      ...current,
      userMessage,
      { id: assistantId, role: "assistant", content: "" },
    ]);

    try {
      const response = await fetch("/api/chat", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ message, history: priorHistory, context }),
      });

      if (!response.ok || !response.body) {
        const payload = (await response.json().catch(() => null)) as { error?: string } | null;
        throw new Error(payload?.error ?? "The assistant could not answer right now.");
      }

      const reader = response.body.getReader();
      const decoder = new TextDecoder();
      let buffer = "";
      let receivedText = false;

      while (true) {
        const { done, value } = await reader.read();
        buffer += decoder.decode(value, { stream: !done });

        let boundary = buffer.indexOf("\n\n");
        while (boundary >= 0) {
          const block = buffer.slice(0, boundary);
          buffer = buffer.slice(boundary + 2);
          const parsed = parseEventBlock(block);

          if (parsed?.event === "delta" && typeof parsed.payload.text === "string") {
            receivedText = true;
            const text = parsed.payload.text;
            setMessages((current) =>
              current.map((item) =>
                item.id === assistantId ? { ...item, content: item.content + text } : item,
              ),
            );
          }

          if (parsed?.event === "error") {
            throw new Error(
              typeof parsed.payload.error === "string"
                ? parsed.payload.error
                : "The assistant response was interrupted.",
            );
          }

          boundary = buffer.indexOf("\n\n");
        }

        if (done) {
          if (!receivedText) {
            throw new Error("The assistant returned an empty response.");
          }
          break;
        }
      }
    } catch (error) {
      const fallback = error instanceof Error ? error.message : "The assistant could not answer right now.";
      setMessages((current) =>
        current.map((item) =>
          item.id === assistantId ? { ...item, content: fallback } : item,
        ),
      );
    } finally {
      setSending(false);
    }
  };

  const handleComposerKeyDown = (event: KeyboardEvent<HTMLTextAreaElement>) => {
    if (event.key === "Enter" && !event.shiftKey) {
      event.preventDefault();
      void sendMessage();
    }
  };

  return (
    <div className={open ? "chat-dock chat-open" : "chat-dock"}>
      {open && (
        <section className="chat-panel" aria-label="Shift AI assistant">
          <header className="chat-header">
            <div>
              <span>Bedrock live</span>
              <h2>Ask Shift</h2>
            </div>
            <button type="button" aria-label="Close assistant" onClick={() => setOpen(false)}>
              ×
            </button>
          </header>

          <div className="chat-transcript" aria-live="polite">
            {messages.map((message) => (
              <article className={`chat-message chat-${message.role}`} key={message.id}>
                <span>{message.role === "assistant" ? "SHIFT" : "YOU"}</span>
                <p>{message.content || "Thinking…"}</p>
              </article>
            ))}
            <div ref={transcriptEndRef} />
          </div>

          <form className="chat-composer" onSubmit={(event) => void sendMessage(event)}>
            <label htmlFor="shift-message">Message Shift</label>
            <div>
              <textarea
                id="shift-message"
                maxLength={MAX_CHAT_MESSAGE_LENGTH}
                onChange={(event) => setDraft(event.target.value)}
                onKeyDown={handleComposerKeyDown}
                placeholder="Ask for a tactic..."
                rows={2}
                value={draft}
              />
              <button type="submit" disabled={!draft.trim() || sending} aria-label="Send message">
                {sending ? "···" : "↗"}
              </button>
            </div>
            <small>Enter to send · Shift + Enter for a new line</small>
          </form>
        </section>
      )}

      <button
        className="chat-launcher"
        type="button"
        aria-expanded={open}
        onClick={() => setOpen((current) => !current)}
      >
        <span className="chat-signal" aria-hidden="true" />
        {open ? "Close Shift" : "Ask Shift"}
        <small>AI</small>
      </button>
    </div>
  );
}
