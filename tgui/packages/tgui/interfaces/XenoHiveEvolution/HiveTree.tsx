import { useLayoutEffect, useMemo, useRef, useState } from 'react';
import { Box, Button, Icon } from 'tgui-core/components';
import { addScrollableNode, removeScrollableNode } from 'tgui-core/events';
import {
  layoutTree,
  nodeHeight,
  nodeWidth,
  type Upgrade,
  type UpgradeDefinition,
} from './layoutTree';

export function isComplete(node: Upgrade) {
  return node.maxLevel !== null && node.level >= node.maxLevel;
}

type Props = {
  category: string;
  definitions: UpgradeDefinition[];
  upgradesById: Map<string, Upgrade>;
  selectedId?: string;
  targetId: string | null;
  onSelect: (upgrade: Upgrade) => void;
};

export function HiveTree({
  category,
  definitions,
  upgradesById,
  selectedId,
  targetId,
  onSelect,
}: Props) {
  const viewportRef = useRef<HTMLDivElement>(null);
  const [size, setSize] = useState({ width: 0, height: 0 });
  const [zoom, setZoom] = useState<number | 'fit' | null>(null);
  const zoomAnchor = useRef<{ x: number; y: number } | null>(null);
  const lastTarget = useRef<string | null>(null);
  const { nodes, links, width, height } = useMemo(
    () => layoutTree(definitions, category, size.width),
    [definitions, category, size.width],
  );
  const widthScale = Math.min(1, size.width / (width || 1)) || 1;
  const fit = Math.min(widthScale, size.height / height) || widthScale;
  const scale = zoom === 'fit' ? fit : (zoom ?? widthScale);
  const minZoom = Math.min(fit, 0.35);
  const maxZoom = 1.5;

  useLayoutEffect(() => {
    const viewport = viewportRef.current!;
    addScrollableNode(viewport);
    const measure = () => {
      const { clientWidth: width, clientHeight: height } = viewport;
      setSize((old) =>
        old.width === width && old.height === height ? old : { width, height },
      );
    };
    measure();
    const observer = new ResizeObserver(measure);
    observer.observe(viewport);
    return () => {
      observer.disconnect();
      removeScrollableNode(viewport);
    };
  }, []);

  useLayoutEffect(() => {
    const viewport = viewportRef.current!;
    const anchor = zoomAnchor.current;
    if (anchor) {
      viewport.scrollTo({
        left: anchor.x * viewport.scrollWidth - viewport.clientWidth / 2,
        top: anchor.y * viewport.scrollHeight - viewport.clientHeight / 2,
      });
      zoomAnchor.current = null;
    }

    if (targetId && width && size.width && lastTarget.current !== targetId) {
      const target = nodes.find(
        (node) => node.upgrade.id === targetId && !node.external,
      );
      if (target) {
        viewport.scrollTo({
          left: (target.x + nodeWidth / 2) * scale - viewport.clientWidth / 2,
          top: (target.y + nodeHeight / 2) * scale - viewport.clientHeight / 2,
        });
        lastTarget.current = targetId;
      }
    }
    if (!targetId) {
      lastTarget.current = null;
    }
  });

  function changeZoom(next: number) {
    const viewport = viewportRef.current!;
    const nextScale = Math.max(minZoom, Math.min(maxZoom, next));
    if (nextScale === scale) {
      return;
    }
    zoomAnchor.current = {
      x:
        (viewport.scrollLeft + viewport.clientWidth / 2) / viewport.scrollWidth,
      y:
        (viewport.scrollTop + viewport.clientHeight / 2) /
        viewport.scrollHeight,
    };
    setZoom(nextScale);
  }

  return (
    <div className="Hive-canvas">
      <div
        aria-label="Дерево улучшений"
        className="Hive-viewport"
        ref={viewportRef}
      >
        {!nodes.length && <Box m={2}>В этой категории пока нет улучшений.</Box>}
        <div
          className="Hive-graphBounds"
          style={{ width: width * scale, height: height * scale }}
        >
          <div
            className="Hive-graph"
            style={{ width, height, transform: `scale(${scale})` }}
          >
            <svg
              width={width}
              height={height}
              className="Hive-links"
              aria-hidden="true"
            >
              {links
                .map((link) => ({
                  ...link,
                  owned: (upgradesById.get(link.sourceId)?.level ?? 0) > 0,
                }))
                .sort((a, b) => Number(a.owned) - Number(b.owned))
                .map(({ path, key, owned }) => (
                  <path key={key} d={path} data-owned={owned} />
                ))}
            </svg>
            {nodes.map(({ upgrade: definition, external, terminal, x, y }) => {
              const upgrade = upgradesById.get(definition.id);
              if (!upgrade) {
                return null;
              }
              return (
                <button
                  type="button"
                  aria-pressed={
                    external ? undefined : selectedId === upgrade.id
                  }
                  className="Hive-node"
                  data-terminal={terminal}
                  data-external={external}
                  style={{
                    left: x - (terminal ? 4 : 0),
                    top: y,
                    width: nodeWidth + (terminal ? 8 : 0),
                    height: nodeHeight + (terminal ? 6 : 0),
                  }}
                  key={upgrade.id}
                  onClick={() => onSelect(upgrade)}
                >
                  <Icon
                    name={upgrade.icon}
                    className="Hive-nodeIcon"
                    aria-hidden="true"
                  />
                  <span className="Hive-nodeText">
                    <strong>
                      {upgrade.name}
                      {external && ' ↗'}
                    </strong>
                    {external ? (
                      <span>{upgrade.category}</span>
                    ) : isComplete(upgrade) ? (
                      <span className="Hive-owned">
                        <Icon name="check" /> Изучено
                      </span>
                    ) : (
                      <span
                        className={upgrade.available ? 'Hive-price' : undefined}
                      >
                        {!upgrade.available && (
                          <Icon name="lock" aria-label="Недоступно" />
                        )}{' '}
                        {upgrade.cost} биомассы
                      </span>
                    )}
                    {!external && upgrade.maxLevel !== 1 && (
                      <span>
                        Куплено: {upgrade.level}
                        {upgrade.maxLevel !== null && ` / ${upgrade.maxLevel}`}
                      </span>
                    )}
                  </span>
                </button>
              );
            })}
          </div>
        </div>
      </div>
      {!!nodes.length && (
        <div className="Hive-zoom">
          <Button
            icon="minus"
            aria-label="Уменьшить масштаб"
            tooltip="Уменьшить масштаб"
            disabled={scale <= minZoom}
            onClick={() => changeZoom(scale / 1.2)}
          />
          <span>{Math.round(scale * 100)}%</span>
          <Button
            icon="plus"
            aria-label="Увеличить масштаб"
            tooltip="Увеличить масштаб"
            disabled={scale >= maxZoom}
            onClick={() => changeZoom(scale * 1.2)}
          />
          <Button
            icon="expand"
            aria-label="Вместить дерево"
            tooltip="Вместить дерево"
            onClick={() => {
              setZoom('fit');
              viewportRef.current?.scrollTo(0, 0);
            }}
          />
        </div>
      )}
    </div>
  );
}
