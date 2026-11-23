import {expect, it} from 'vitest';

import {teamGraphLayout} from '../src/team-graph-layout.ts';

it('routes every connector to its own card in compact and scrollable team layouts', () => {
  for (const viewport of [
    {width: 660, height: 460},
    {width: 1200, height: 820},
  ]) {
    for (const count of [0, 1, 4, 7, 20, 100]) {
      const graph = teamGraphLayout(count, viewport);
      expect(graph.nodes).toHaveLength(count);
      if (count > 4) {
        expect(graph.width).toBeGreaterThanOrEqual(860);
        expect(graph.height).toBeGreaterThanOrEqual(
          Math.ceil(count / 2) * 220 + 60,
        );
      }
      for (const node of graph.nodes) {
        const [start, firstTurn, secondTurn, end] = node.connector;
        const halfWidth = graph.cardWidth / 2;
        expect(start.x).toBe(graph.reactor.x);
        expect(start.y).toBe(firstTurn.y);
        expect(firstTurn.x).toBe(secondTurn.x);
        expect(secondTurn.y).toBe(end.y);
        expect(end.y).toBe(node.center.y);
        expect(end.x).toBe(
          node.center.x +
            (node.center.x < graph.reactor.x ? halfWidth : -halfWidth),
        );
        for (const other of graph.nodes) {
          if (other === node) continue;
          const left = other.center.x - halfWidth;
          const right = other.center.x + halfWidth;
          const top = other.center.y - 90;
          const bottom = other.center.y + 90;
          for (const [a, b] of [
            [start, firstTurn],
            [firstTurn, secondTurn],
            [secondTurn, end],
          ]) {
            const overlapsX =
              Math.max(a.x, b.x) > left && Math.min(a.x, b.x) < right;
            const overlapsY =
              Math.max(a.y, b.y) > top && Math.min(a.y, b.y) < bottom;
            if (overlapsX && overlapsY)
              throw new Error('Connector crosses another card');
          }
        }
      }
    }
  }
});
