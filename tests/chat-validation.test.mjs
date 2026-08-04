import assert from "node:assert/strict";
import test from "node:test";

import {
  MAX_CHAT_MESSAGE_LENGTH,
  parseChatRequest,
} from "../lib/chat-validation.ts";

test("accepts a bounded chat request with a completed conversation", () => {
  const request = parseChatRequest({
    message: "How should I handle corners?",
    history: [
      { role: "user", content: "Give me one tip." },
      { role: "assistant", content: "Leave yourself an exit lane." },
    ],
    context: { score: 80, speedLevel: 2, status: "running" },
  });

  assert.ok(request);
  assert.equal(request.history.length, 2);
  assert.equal(request.context?.score, 80);
});

test("drops incomplete or malformed history instead of sending it to Bedrock", () => {
  const request = parseChatRequest({
    message: "Help",
    history: [
      { role: "assistant", content: "This cannot start a Converse history." },
      { role: "user", content: "Unpaired turn" },
    ],
    context: null,
  });

  assert.ok(request);
  assert.deepEqual(request.history, []);
});

test("rejects empty and oversized player messages", () => {
  assert.equal(parseChatRequest({ message: "   " }), null);
  assert.equal(
    parseChatRequest({ message: "x".repeat(MAX_CHAT_MESSAGE_LENGTH + 1) }),
    null,
  );
});

test("ignores an invalid game summary without rejecting the message", () => {
  const request = parseChatRequest({
    message: "Hello",
    context: { score: -1, speedLevel: 50, status: "unknown" },
  });

  assert.ok(request);
  assert.equal(request.context, null);
});
