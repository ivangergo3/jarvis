import {useLayoutEffect, useMemo, useRef, useState} from 'react';
import type {CSSProperties} from 'react';

import {teamGraphLayout} from './team-graph-layout';
import './team-graph.css';

const reactorImage = new URL('../../../Resources/reactor.png', import.meta.url)
  .href;

export interface TeamCard {
  id: string;
  name: string;
  detail: string;
  status: 'In progress' | 'Standby' | 'Unknown';
}

interface TeamGraphProps {
  cards: readonly TeamCard[];
  selectedId?: string;
  onSelect: (id: string) => void;
}

function useViewport() {
  const ref = useRef<HTMLDivElement>(null);
  const [size, setSize] = useState({width: 660, height: 460});
  useLayoutEffect(() => {
    const element = ref.current;
    if (!element) return;
    const update = () => {
      const width = element.clientWidth;
      const height = element.clientHeight;
      if (width && height) {
        setSize((prev) =>
          prev.width === width && prev.height === height
            ? prev
            : {width, height},
        );
      }
    };
    update();
    const observer = new ResizeObserver(update);
    observer.observe(element);
    return () => observer.disconnect();
  }, []);
  return {ref, size};
}

export function TeamGraph({cards, selectedId, onSelect}: TeamGraphProps) {
  const [mode, setMode] = useState<'graph' | 'cards'>('graph');
  const {ref, size} = useViewport();
  const layout = useMemo(
    () => teamGraphLayout(cards.length, size),
    [cards.length, size],
  );
  const entries = layout.nodes.map((node, index) => {
    const card = cards[index];
    if (!card) throw new Error('Missing graph card');
    return {card, node};
  });
  const graph = mode === 'graph';
  return (
    <section aria-label="Team layout">
      <div className="team-modes" role="group" aria-label="View mode">
        <button aria-pressed={graph} onClick={() => setMode('graph')}>
          Graph
        </button>
        <button aria-pressed={!graph} onClick={() => setMode('cards')}>
          Cards
        </button>
      </div>
      <div className="team-viewport" ref={ref}>
        <div
          className={graph ? 'team-canvas' : 'team-grid'}
          style={
            graph ? {width: layout.width, height: layout.height} : undefined
          }
        >
          <img
            className="team-reactor"
            alt=""
            src={reactorImage}
            style={
              graph
                ? {left: layout.reactor.x, top: layout.reactor.y}
                : undefined
            }
          />
          {graph && (
            <svg
              className="team-wires"
              width={layout.width}
              height={layout.height}
              aria-hidden="true"
              focusable="false"
            >
              {entries.map(({card, node}) => (
                <polyline
                  key={card.id}
                  className={card.id === selectedId ? 'selected' : ''}
                  points={node.connector.map((p) => `${p.x},${p.y}`).join(' ')}
                />
              ))}
            </svg>
          )}
          {entries.map(({card, node}) => {
            const {center} = node;
            const position: CSSProperties | undefined = graph
              ? {
                  width: layout.cardWidth,
                  left: center.x,
                  top: center.y,
                }
              : undefined;
            return (
              <button
                key={card.id}
                className="team-card"
                style={position}
                title={card.name}
                aria-pressed={selectedId === card.id}
                onClick={() => onSelect(card.id)}
              >
                <small>{card.status}</small>
                <strong>{card.name}</strong>
                <span>{card.detail}</span>
              </button>
            );
          })}
        </div>
      </div>
    </section>
  );
}
