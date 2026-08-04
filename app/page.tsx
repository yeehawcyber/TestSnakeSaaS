"use client";

import { useCallback, useEffect, useRef, useState } from "react";

import { GameChat } from "@/app/components/game-chat";
import { LoginScreen } from "@/app/components/login-screen";
import { useCognitoAuth } from "@/app/use-cognito-auth";
import type { CognitoSession } from "@/lib/cognito-auth";
import {
  advanceGame,
  createInitialGame,
  queueDirection,
  type Direction,
  type GameState,
} from "@/lib/snake-engine";

const CANVAS_SIZE = 660;
const BEST_SCORE_KEY = "snake-shift-best-score";

function formatScore(score: number) {
  return score.toString().padStart(4, "0");
}

function gameStatusLabel(status: GameState["status"]) {
  const labels: Record<GameState["status"], string> = {
    ready: "Ready",
    running: "Live",
    paused: "Paused",
    gameover: "Run over",
    won: "Grid cleared",
  };

  return labels[status];
}

function drawRoundedSquare(
  context: CanvasRenderingContext2D,
  x: number,
  y: number,
  size: number,
  radius: number,
) {
  context.beginPath();
  context.roundRect(x, y, size, size, radius);
  context.fill();
}

function drawGame(canvas: HTMLCanvasElement, game: GameState) {
  const pixelRatio = Math.min(window.devicePixelRatio || 1, 2);
  canvas.width = CANVAS_SIZE * pixelRatio;
  canvas.height = CANVAS_SIZE * pixelRatio;

  const context = canvas.getContext("2d");
  if (!context) {
    return;
  }

  context.setTransform(pixelRatio, 0, 0, pixelRatio, 0, 0);
  context.imageSmoothingEnabled = true;
  context.fillStyle = "#141512";
  context.fillRect(0, 0, CANVAS_SIZE, CANVAS_SIZE);

  const cellSize = CANVAS_SIZE / game.gridSize;

  context.strokeStyle = "#252820";
  context.lineWidth = 1;
  for (let index = 1; index < game.gridSize; index += 1) {
    const position = index * cellSize + 0.5;
    context.beginPath();
    context.moveTo(position, 0);
    context.lineTo(position, CANVAS_SIZE);
    context.stroke();
    context.beginPath();
    context.moveTo(0, position);
    context.lineTo(CANVAS_SIZE, position);
    context.stroke();
  }

  if (game.food) {
    const centerX = (game.food.x + 0.5) * cellSize;
    const centerY = (game.food.y + 0.5) * cellSize;
    const foodSize = cellSize * 0.48;

    context.save();
    context.translate(centerX, centerY);
    context.rotate(Math.PI / 4);
    context.fillStyle = "#ff6542";
    context.fillRect(-foodSize / 2, -foodSize / 2, foodSize, foodSize);
    context.restore();

    context.fillStyle = "#fff5d6";
    context.fillRect(
      centerX - cellSize * 0.07,
      centerY - cellSize * 0.07,
      cellSize * 0.14,
      cellSize * 0.14,
    );
  }

  game.snake
    .slice()
    .reverse()
    .forEach((segment, reverseIndex) => {
      const originalIndex = game.snake.length - reverseIndex - 1;
      const inset = originalIndex === 0 ? cellSize * 0.09 : cellSize * 0.13;
      const segmentSize = cellSize - inset * 2;
      const x = segment.x * cellSize + inset;
      const y = segment.y * cellSize + inset;

      context.fillStyle = originalIndex === 0 ? "#d5ff68" : "#aeea42";
      drawRoundedSquare(context, x, y, segmentSize, cellSize * 0.2);

      if (originalIndex > 0 && originalIndex % 3 === 0) {
        context.fillStyle = "#8bc42a";
        context.fillRect(
          x + segmentSize * 0.3,
          y + segmentSize * 0.3,
          segmentSize * 0.4,
          segmentSize * 0.4,
        );
      }
    });

  const head = game.snake[0];
  const eyeOffsets: Record<Direction, readonly [readonly number[], readonly number[]]> = {
    up: [
      [0.32, 0.25],
      [0.68, 0.25],
    ],
    down: [
      [0.32, 0.75],
      [0.68, 0.75],
    ],
    left: [
      [0.25, 0.32],
      [0.25, 0.68],
    ],
    right: [
      [0.75, 0.32],
      [0.75, 0.68],
    ],
  };

  context.fillStyle = "#141512";
  eyeOffsets[game.direction].forEach(([offsetX, offsetY]) => {
    const eyeSize = cellSize * 0.11;
    context.fillRect(
      (head.x + offsetX) * cellSize - eyeSize / 2,
      (head.y + offsetY) * cellSize - eyeSize / 2,
      eyeSize,
      eyeSize,
    );
  });
}

type SnakeGameProps = Readonly<{
  session: CognitoSession;
  onSignOut: () => void;
}>;

function SnakeGame({ session, onSignOut }: SnakeGameProps) {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const [game, setGame] = useState(() => createInitialGame(() => 0.37));
  const [bestScore, setBestScore] = useState(0);

  const restart = useCallback((startRunning = true) => {
    setGame(createInitialGame(Math.random, startRunning));
  }, []);

  const startOrResume = useCallback(() => {
    setGame((current) => {
      if (current.status === "gameover" || current.status === "won") {
        return createInitialGame(Math.random, true);
      }

      if (current.status === "ready" || current.status === "paused") {
        return { ...current, status: "running" };
      }

      return current;
    });
  }, []);

  const togglePause = useCallback(() => {
    setGame((current) => {
      if (current.status === "running") {
        return { ...current, status: "paused" };
      }

      if (current.status === "paused" || current.status === "ready") {
        return { ...current, status: "running" };
      }

      return current;
    });
  }, []);

  const move = useCallback((direction: Direction) => {
    setGame((current) => {
      if (current.status === "gameover" || current.status === "won") {
        return current;
      }

      const activeGame =
        current.status === "ready" ? { ...current, status: "running" as const } : current;
      return queueDirection(activeGame, direction);
    });
  }, []);

  useEffect(() => {
    const frame = window.requestAnimationFrame(() => {
      const savedBestScore = Number(window.localStorage.getItem(BEST_SCORE_KEY));
      if (Number.isFinite(savedBestScore) && savedBestScore > 0) {
        setBestScore(savedBestScore);
      }
    });

    return () => window.cancelAnimationFrame(frame);
  }, []);

  useEffect(() => {
    if (game.score <= bestScore) {
      return undefined;
    }

    const frame = window.requestAnimationFrame(() => {
      setBestScore(game.score);
      window.localStorage.setItem(BEST_SCORE_KEY, String(game.score));
    });

    return () => window.cancelAnimationFrame(frame);
  }, [bestScore, game.score]);

  useEffect(() => {
    if (canvasRef.current) {
      drawGame(canvasRef.current, game);
    }
  }, [game]);

  useEffect(() => {
    if (game.status !== "running") {
      return undefined;
    }

    const timer = window.setInterval(() => {
      setGame((current) => advanceGame(current));
    }, game.tickMs);

    return () => window.clearInterval(timer);
  }, [game.status, game.tickMs]);

  useEffect(() => {
    const handleKeyDown = (event: KeyboardEvent) => {
      if (
        event.target instanceof HTMLInputElement ||
        event.target instanceof HTMLTextAreaElement ||
        event.target instanceof HTMLSelectElement
      ) {
        return;
      }

      const directionKeys: Record<string, Direction> = {
        ArrowUp: "up",
        w: "up",
        W: "up",
        ArrowDown: "down",
        s: "down",
        S: "down",
        ArrowLeft: "left",
        a: "left",
        A: "left",
        ArrowRight: "right",
        d: "right",
        D: "right",
      };
      const direction = directionKeys[event.key];

      if (direction) {
        event.preventDefault();
        move(direction);
        return;
      }

      if (event.code === "Space") {
        event.preventDefault();
        togglePause();
      }

      if (event.key === "r" || event.key === "R") {
        event.preventDefault();
        restart(true);
      }
    };

    window.addEventListener("keydown", handleKeyDown, { passive: false });
    return () => window.removeEventListener("keydown", handleKeyDown);
  }, [move, restart, togglePause]);

  const overlayVisible = game.status !== "running";
  const runComplete = game.status === "gameover" || game.status === "won";

  return (
    <main className="game-shell">
      <header className="masthead">
        <a className="brand-lockup" href="#game-board" aria-label="Snake Shift home">
          <span className="brand-mark" aria-hidden="true">
            S/S
          </span>
          <span>
            <strong>SNAKE/SHIFT</strong>
            <small>Web arcade // build 01</small>
          </span>
        </a>

        <div className="player-session">
          <span className="player-name" title={session.user.email}>
            {session.user.displayName}
          </span>
          <button type="button" onClick={onSignOut}>
            Sign out
          </button>
          <div className="masthead-status" aria-label={`Game status: ${gameStatusLabel(game.status)}`}>
            <span className={`status-light status-${game.status}`} aria-hidden="true" />
            {gameStatusLabel(game.status)}
          </div>
        </div>
      </header>

      <section className="game-intro" aria-labelledby="game-title">
        <p className="eyebrow">Classic mode / 22 × 22</p>
        <h1 id="game-title">
          EAT THE SIGNAL.
          <span>MISS THE STATIC.</span>
        </h1>
        <p className="intro-copy">
          One bright signal. One growing problem. Keep moving and own the grid.
        </p>
      </section>

      <section className="game-layout" aria-label="Snake game and controls">
        <aside className="score-rail" aria-label="Run statistics">
          <div className="metric metric-primary">
            <span>Current score</span>
            <strong data-testid="current-score">{formatScore(game.score)}</strong>
          </div>
          <div className="metric-row">
            <div className="metric">
              <span>Best run</span>
              <strong>{formatScore(bestScore)}</strong>
            </div>
            <div className="metric">
              <span>Speed</span>
              <strong>{game.speedLevel.toString().padStart(2, "0")}/06</strong>
            </div>
          </div>

          <div className="run-actions">
            <button
              className="button button-primary"
              type="button"
              onClick={game.status === "running" ? togglePause : startOrResume}
            >
              {game.status === "running" ? "Pause run" : runComplete ? "Try again" : "Start run"}
              <span aria-hidden="true">↗</span>
            </button>
            <button className="button button-secondary" type="button" onClick={() => restart(false)}>
              New grid <span aria-hidden="true">R</span>
            </button>
          </div>
        </aside>

        <div className="board-column" id="game-board">
          <div className="board-frame">
            <div className="board-index board-index-top" aria-hidden="true">
              <span>00</span>
              <span>11</span>
              <span>21</span>
            </div>
            <div className="canvas-wrap">
              <canvas
                ref={canvasRef}
                className={runComplete ? "game-canvas canvas-muted" : "game-canvas"}
                aria-label={`Snake board. Score ${game.score}. Status ${gameStatusLabel(game.status)}.`}
                role="img"
              />

              {overlayVisible && (
                <div className="game-overlay" data-testid="game-overlay">
                  <p>{game.status === "paused" ? "Hold position" : runComplete ? "Run complete" : "System ready"}</p>
                  <h2>
                    {game.status === "paused"
                      ? "PAUSED"
                      : game.status === "won"
                        ? "GRID CLEARED"
                        : game.status === "gameover"
                          ? "SIGNAL LOST"
                          : "READY?"}
                  </h2>
                  <span>
                    {runComplete
                      ? `${formatScore(game.score)} points logged.`
                      : game.status === "paused"
                        ? "Your run is waiting."
                        : "Use arrows, WASD, or the touch pad."}
                  </span>
                  <button className="overlay-button" type="button" onClick={startOrResume}>
                    {runComplete ? "Run it back" : game.status === "paused" ? "Resume" : "Launch game"}
                  </button>
                </div>
              )}
            </div>
            <div className="board-index board-index-bottom" aria-hidden="true">
              <span>X:00</span>
              <span>GRID:484</span>
              <span>Y:21</span>
            </div>
          </div>
        </div>

        <aside className="control-rail" aria-label="Game controls">
          <div className="control-copy">
            <span className="section-number">01</span>
            <div>
              <h2>Steer clean.</h2>
              <p>Use arrow keys or WASD. Hit space to pause and R to reset.</p>
            </div>
          </div>

          <div className="d-pad" aria-label="Touch direction controls">
            <button type="button" className="d-up" aria-label="Move up" onPointerDown={() => move("up")}>
              ↑
            </button>
            <button type="button" className="d-left" aria-label="Move left" onPointerDown={() => move("left")}>
              ←
            </button>
            <span className="d-center" aria-hidden="true">
              S/S
            </span>
            <button type="button" className="d-right" aria-label="Move right" onPointerDown={() => move("right")}>
              →
            </button>
            <button type="button" className="d-down" aria-label="Move down" onPointerDown={() => move("down")}>
              ↓
            </button>
          </div>

          <div className="rules-card">
            <span className="section-number">02</span>
            <p>
              <strong>Orange = +10.</strong> The pace rises every 50 points. Walls and your own trail end the run.
            </p>
          </div>
        </aside>
      </section>

      <footer className="game-footer">
        <span>Private session. No tracking.</span>
        <span>Keyboard + touch ready</span>
      </footer>

      <GameChat
        accessToken={session.accessToken}
        context={{
          score: game.score,
          speedLevel: game.speedLevel,
          status: game.status,
        }}
      />

      <p className="sr-only" aria-live="polite">
        {gameStatusLabel(game.status)}. Score {game.score}.
      </p>
    </main>
  );
}

export default function Home() {
  const auth = useCognitoAuth();

  if (auth.status === "authenticated" && auth.session) {
    return <SnakeGame session={auth.session} onSignOut={auth.signOut} />;
  }

  return (
    <LoginScreen
      status={auth.status === "authenticated" ? "loading" : auth.status}
      error={auth.error}
      missing={auth.missing}
      onSignIn={auth.signIn}
      onRetry={auth.retry}
    />
  );
}
