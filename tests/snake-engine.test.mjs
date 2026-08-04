import assert from "node:assert/strict";
import test from "node:test";

import {
  advanceGame,
  createInitialGame,
  placeFood,
  queueDirection,
} from "../lib/snake-engine.ts";

test("creates a centered four-segment snake with food on an open cell", () => {
  const game = createInitialGame(() => 0, false, 10);

  assert.equal(game.status, "ready");
  assert.equal(game.snake.length, 4);
  assert.equal(game.score, 0);
  assert.ok(game.food);
  assert.equal(
    game.snake.some(
      (segment) => segment.x === game.food.x && segment.y === game.food.y,
    ),
    false,
  );
});

test("rejects reverse turns and only accepts one queued turn per tick", () => {
  const game = createInitialGame(() => 0, true, 12);
  const reversed = queueDirection(game, "left");
  const turned = queueDirection(game, "up");
  const doubleTurned = queueDirection(turned, "left");

  assert.equal(reversed.nextDirection, "right");
  assert.equal(turned.nextDirection, "up");
  assert.equal(doubleTurned.nextDirection, "up");
});

test("grows the snake, scores ten points, and accelerates after eating", () => {
  const game = createInitialGame(() => 0, true, 12);
  const head = game.snake[0];
  const eatingState = {
    ...game,
    score: 40,
    food: { x: head.x + 1, y: head.y },
  };
  const next = advanceGame(eatingState, () => 0.5);

  assert.equal(next.snake.length, game.snake.length + 1);
  assert.equal(next.score, 50);
  assert.equal(next.speedLevel, 2);
  assert.ok(next.tickMs < game.tickMs);
});

test("ends the run when the snake reaches a wall", () => {
  const game = {
    ...createInitialGame(() => 0, true, 5),
    snake: [
      { x: 4, y: 2 },
      { x: 3, y: 2 },
      { x: 2, y: 2 },
    ],
  };

  assert.equal(advanceGame(game).status, "gameover");
});

test("allows the head to enter the square vacated by the tail", () => {
  const game = {
    ...createInitialGame(() => 0, true, 5),
    snake: [
      { x: 2, y: 2 },
      { x: 2, y: 3 },
      { x: 1, y: 3 },
      { x: 1, y: 2 },
    ],
    direction: "left",
    nextDirection: "left",
    food: { x: 4, y: 4 },
  };

  const next = advanceGame(game);
  assert.equal(next.status, "running");
  assert.deepEqual(next.snake[0], { x: 1, y: 2 });
});

test("reports a full board by returning no food", () => {
  const snake = [
    { x: 0, y: 0 },
    { x: 1, y: 0 },
    { x: 0, y: 1 },
    { x: 1, y: 1 },
  ];

  assert.equal(placeFood(snake, 2), null);
});
