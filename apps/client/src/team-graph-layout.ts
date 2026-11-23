export interface Point {
  readonly x: number;
  readonly y: number;
}

export interface Viewport {
  readonly width: number;
  readonly height: number;
}

interface GraphNode {
  readonly center: Point;
  readonly connector: readonly [Point, Point, Point, Point];
}

/** Card positions and connector endpoints share the same scrollable canvas. */
export function teamGraphLayout(count: number, viewport: Viewport) {
  const rows = Math.ceil(count / 2);
  const compact = count <= 4;
  const width = Math.max(compact ? 1 : 860, viewport.width);
  const height = Math.max(compact ? 1 : rows * 220 + 60, viewport.height);
  const cardWidth = Math.min(
    275,
    compact ? width * 0.37 : (width - 320) / 2 - 24,
  );
  const reactor = {x: width / 2, y: height * (compact ? 0.48 : 0.5)};
  const nodes = Array.from({length: count}, (_, index): GraphNode => {
    const left = index % 2 === 0;
    const row = Math.floor(index / 2);
    const sideCount = left ? rows : Math.floor(count / 2);
    const inset = compact ? width * 0.23 : 24 + cardWidth / 2;
    const center = {
      x: left ? inset : width - inset,
      y: compact
        ? height * (row === 0 ? 0.19 : 0.81)
        : 30 + ((row + 0.5) * (height - 60)) / rows,
    };
    const edge = center.x + (left ? cardWidth / 2 : -cardWidth / 2);
    const lane =
      edge + (reactor.x - edge) * (0.14 + (0.72 * (row + 1)) / (sideCount + 1));
    const launch = reactor.y + (row - (sideCount - 1) / 2) * 12;
    return {
      center,
      connector: [
        {x: reactor.x, y: launch},
        {x: lane, y: launch},
        {x: lane, y: center.y},
        {x: edge, y: center.y},
      ],
    };
  });
  return {width, height, cardWidth, reactor, nodes};
}
