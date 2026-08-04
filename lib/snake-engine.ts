export type Direction = "up" | "down" | "left" | "right";

export type GameStatus = "ready" | "running" | "paused" | "gameover" | "won";

export type Point = Readonly<{
  x: number;
  y: number;
}>;

export type GameState = Readonly<{
  gridSize: number;
  snake: readonly Point[];
  food: Point | null;
  direction: Direction;
  nextDirection: Direction;
  status: GameStatus;
  score: number;
  speedLevel: number;
  tickMs: number;
}>;

export const DEFAULT_GRID_SIZE = 22;

const DIRECTION_VECTOR: Record<Direction, Point> = {
  up: { x: 0, y: -1 },
  down: { x: 0, y: 1 },
  left: { x: -1, y: 0 },
  right: { x: 1, y: 0 },
};

const OPPOSITE_DIRECTION: Record<Direction, Direction> = {
  up: "down",
  down: "up",
  left: "right",
  right: "left",
};

function samePoint(a: Point, b: Point) {
  return a.x === b.x && a.y === b.y;
}

function speedForScore(score: number) {
  const speedLevel = Math.min(6, Math.floor(score / 50) + 1);

  return {
    speedLevel,
    tickMs: Math.max(64, 148 - (speedLevel - 1) * 15),
  };
}

export function placeFood(
  snake: readonly Point[],
  gridSize: number,
  random: () => number = Math.random,
): Point | null {
  const occupied = new Set(snake.map((segment) => `${segment.x}:${segment.y}`));
  const openCells: Point[] = [];

  for (let y = 0; y < gridSize; y += 1) {
    for (let x = 0; x < gridSize; x += 1) {
      if (!occupied.has(`${x}:${y}`)) {
        openCells.push({ x, y });
      }
    }
  }

  if (openCells.length === 0) {
    return null;
  }

  const safeRandom = Math.min(Math.max(random(), 0), 0.999999999);
  return openCells[Math.floor(safeRandom * openCells.length)];
}

export function createInitialGame(
  random: () => number = Math.random,
  startRunning = false,
  gridSize = DEFAULT_GRID_SIZE,
): GameState {
  const center = Math.floor(gridSize / 2);
  const snake: readonly Point[] = [
    { x: center, y: center },
    { x: center - 1, y: center },
    { x: center - 2, y: center },
    { x: center - 3, y: center },
  ];
  const speed = speedForScore(0);

  return {
    gridSize,
    snake,
    food: placeFood(snake, gridSize, random),
    direction: "right",
    nextDirection: "right",
    status: startRunning ? "running" : "ready",
    score: 0,
    ...speed,
  };
}

export function queueDirection(
  state: GameState,
  nextDirection: Direction,
): GameState {
  const alreadyQueued = state.nextDirection !== state.direction;
  const reversing = OPPOSITE_DIRECTION[state.direction] === nextDirection;

  if (alreadyQueued || reversing || state.nextDirection === nextDirection) {
    return state;
  }

  return { ...state, nextDirection };
}

export function advanceGame(
  state: GameState,
  random: () => number = Math.random,
): GameState {
  if (state.status !== "running") {
    return state;
  }

  const movement = DIRECTION_VECTOR[state.nextDirection];
  const head = state.snake[0];
  const nextHead = {
    x: head.x + movement.x,
    y: head.y + movement.y,
  };
  const hitWall =
    nextHead.x < 0 ||
    nextHead.x >= state.gridSize ||
    nextHead.y < 0 ||
    nextHead.y >= state.gridSize;
  const ateFood = state.food !== null && samePoint(nextHead, state.food);
  const bodyToCheck = ateFood ? state.snake : state.snake.slice(0, -1);
  const hitSelf = bodyToCheck.some((segment) => samePoint(segment, nextHead));

  if (hitWall || hitSelf) {
    return {
      ...state,
      direction: state.nextDirection,
      status: "gameover",
    };
  }

  const snake = ateFood
    ? [nextHead, ...state.snake]
    : [nextHead, ...state.snake.slice(0, -1)];
  const score = state.score + (ateFood ? 10 : 0);
  const food = ateFood ? placeFood(snake, state.gridSize, random) : state.food;
  const speed = speedForScore(score);

  return {
    ...state,
    snake,
    food,
    score,
    direction: state.nextDirection,
    nextDirection: state.nextDirection,
    status: ateFood && food === null ? "won" : "running",
    ...speed,
  };
}
