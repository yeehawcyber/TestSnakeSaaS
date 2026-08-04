export const MAX_CHAT_MESSAGE_LENGTH = 600;
export const MAX_CHAT_HISTORY_LENGTH = 8;
export const MAX_CHAT_HISTORY_MESSAGE_LENGTH = 1_200;

export type ChatRole = "user" | "assistant";

export type ChatTurn = Readonly<{
  role: ChatRole;
  content: string;
}>;

export type ChatContext = Readonly<{
  score: number;
  speedLevel: number;
  status: "ready" | "running" | "paused" | "gameover" | "won";
}>;

export type ChatRequest = Readonly<{
  message: string;
  history: readonly ChatTurn[];
  context: ChatContext | null;
}>;

const GAME_STATUSES = new Set<ChatContext["status"]>([
  "ready",
  "running",
  "paused",
  "gameover",
  "won",
]);

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function parseContext(value: unknown): ChatContext | null {
  if (!isRecord(value)) {
    return null;
  }

  const score = Number(value.score);
  const speedLevel = Number(value.speedLevel);
  const status = value.status;

  if (
    !Number.isInteger(score) ||
    score < 0 ||
    score > 10_000_000 ||
    !Number.isInteger(speedLevel) ||
    speedLevel < 1 ||
    speedLevel > 6 ||
    typeof status !== "string" ||
    !GAME_STATUSES.has(status as ChatContext["status"])
  ) {
    return null;
  }

  return { score, speedLevel, status: status as ChatContext["status"] };
}

function parseCompletedHistory(value: unknown): readonly ChatTurn[] {
  if (!Array.isArray(value)) {
    return [];
  }

  const validTurns = value
    .slice(-MAX_CHAT_HISTORY_LENGTH)
    .filter(isRecord)
    .map((turn) => ({
      role: turn.role,
      content: typeof turn.content === "string" ? turn.content.trim() : "",
    }))
    .filter(
      (turn): turn is ChatTurn =>
        (turn.role === "user" || turn.role === "assistant") &&
        turn.content.length > 0 &&
        turn.content.length <= MAX_CHAT_HISTORY_MESSAGE_LENGTH,
    );

  const completedHistory: ChatTurn[] = [];
  for (let index = 0; index + 1 < validTurns.length; index += 2) {
    const userTurn = validTurns[index];
    const assistantTurn = validTurns[index + 1];
    if (userTurn.role !== "user" || assistantTurn.role !== "assistant") {
      break;
    }
    completedHistory.push(userTurn, assistantTurn);
  }

  return completedHistory;
}

export function parseChatRequest(value: unknown): ChatRequest | null {
  if (!isRecord(value) || typeof value.message !== "string") {
    return null;
  }

  const message = value.message.trim();
  if (message.length === 0 || message.length > MAX_CHAT_MESSAGE_LENGTH) {
    return null;
  }

  return {
    message,
    history: parseCompletedHistory(value.history),
    context: parseContext(value.context),
  };
}
