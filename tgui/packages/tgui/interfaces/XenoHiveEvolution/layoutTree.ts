export type UpgradeDefinition = {
  id: string;
  name: string;
  description: string;
  category: string;
  icon: string;
  maxLevel: number | null;
  requires: string[];
};

export type UpgradeState = {
  cost: number;
  level: number;
  available: boolean;
};

export type Upgrade = UpgradeDefinition & UpgradeState;

export const nodeWidth = 192;
export const nodeHeight = 68;
const columnGap = 24;
const rowGap = 58;
const padding = 20;

type TreeNode = {
  upgrade: UpgradeDefinition;
  external: boolean;
  x: number;
  y: number;
  terminal: boolean;
};

export function layoutTree(
  upgrades: UpgradeDefinition[],
  category: string,
  viewportWidth: number,
) {
  const byId = new Map(upgrades.map((upgrade) => [upgrade.id, upgrade]));
  const visible = upgrades.filter((upgrade) => upgrade.category === category);
  const parents = new Map<string, string[]>();
  const children = new Map<string, string[]>();
  for (const upgrade of visible) {
    parents.set(
      upgrade.id,
      upgrade.requires.filter((id) => byId.has(id)),
    );
    for (const id of parents.get(upgrade.id) ?? []) {
      const dependents = children.get(id) ?? [];
      dependents.push(upgrade.id);
      children.set(id, dependents);
    }
  }

  const branching = [...parents.values(), ...children.values()].some(
    (links) => links.length > 1,
  );
  const layoutWidth =
    branching && viewportWidth >= 760
      ? Math.max(viewportWidth, 1120)
      : viewportWidth;
  const tileWidth = branching
    ? nodeWidth
    : Math.max(
        nodeWidth,
        Math.floor((layoutWidth - 2 * padding - 2 * columnGap) / 2),
      );
  if (!branching) {
    const connected = (id: string) =>
      Number(!!parents.get(id)?.length || children.has(id));
    visible.sort((a, b) => connected(a.id) - connected(b.id));
  }

  const nodes: TreeNode[] = [];
  const links: { path: string; sourceId: string; key: string }[] = [];
  const remaining = new Set(visible.map(({ id }) => id));
  let width = 0;
  let x = padding;
  let y = padding;
  let rowHeight = 0;

  for (const upgrade of visible) {
    if (!remaining.has(upgrade.id)) {
      continue;
    }

    const group = new Set([upgrade.id]);
    for (const id of group) {
      remaining.delete(id);
      for (const neighbor of [
        ...(parents.get(id) ?? []),
        ...(children.get(id) ?? []),
      ]) {
        group.add(neighbor);
      }
    }

    // Rank by prerequisites, then align shorter paths before their shared unlock.
    const ranks = new Map<string, number>();
    const pending = new Set(group);
    while (pending.size) {
      const size = pending.size;
      for (const id of pending) {
        const required = parents.get(id) ?? [];
        if (required.every((parent) => ranks.has(parent))) {
          ranks.set(
            id,
            Math.max(0, ...required.map((parent) => ranks.get(parent)! + 1)),
          );
          pending.delete(id);
        }
      }
      if (pending.size === size) {
        break;
      }
    }
    for (const id of [...ranks.keys()].reverse()) {
      const dependents = children.get(id) ?? [];
      if (
        parents.get(id)?.length &&
        dependents.length &&
        dependents.every((child) => ranks.has(child))
      ) {
        ranks.set(
          id,
          Math.min(...dependents.map((child) => ranks.get(child)! - 1)),
        );
      }
    }

    const rows: string[][] = [];
    for (const id of group) {
      const rank = ranks.get(id) ?? 0;
      rows[rank] ??= [];
      rows[rank].push(id);
    }
    const columns = Math.max(...rows.map((row) => row.length));
    const groupWidth = columns * (nodeWidth + columnGap) - columnGap;
    let longLinks = 0;
    for (const id of group) {
      longLinks += (parents.get(id) ?? []).filter(
        (parent) => (ranks.get(id) ?? 0) - (ranks.get(parent) ?? 0) > 1,
      ).length;
    }
    const routeWidth = longLinks ? 14 + longLinks * 8 : 0;
    const fullWidth = groupWidth + routeWidth;
    const slotWidth = Math.max(fullWidth, tileWidth);
    if (x > padding && x + slotWidth + padding > layoutWidth) {
      y += rowHeight + rowGap;
      x = padding;
      rowHeight = 0;
    }

    const left = x + (slotWidth - fullWidth) / 2;
    const placed = new Map<string, TreeNode>();
    rows.forEach((row, rank) => {
      const center = (id: string) => {
        const sources = (parents.get(id) ?? [])
          .map((parent) => placed.get(parent))
          .filter((node) => node !== undefined);
        return sources.length
          ? sources.reduce((sum, node) => sum + node.x, 0) / sources.length
          : left + (groupWidth - nodeWidth) / 2;
      };
      row.sort((a, b) => center(a) - center(b));
      row.forEach((id, index) => {
        const item = byId.get(id)!;
        const node = {
          upgrade: item,
          external: item.category !== category,
          terminal: !!parents.get(id)?.length && !children.has(id),
          x:
            left +
            (groupWidth - nodeWidth) *
              (row.length > 1 ? index / (row.length - 1) : 0.5),
          y: y + rank * (nodeHeight + rowGap),
        };
        placed.set(id, node);
        nodes.push(node);
      });
    });

    let longLinkIndex = 0;
    for (const [id, target] of placed) {
      for (const parent of parents.get(id) ?? []) {
        const source = placed.get(parent)!;
        const startX = source.x + nodeWidth / 2;
        const endX = target.x + nodeWidth / 2;
        const startY = source.y + nodeHeight;
        const endY = target.y;
        if (startY >= endY) {
          continue;
        }
        let path = `M ${startX} ${startY}`;
        const clearVerticalPath =
          startX === endX &&
          ![...placed.values()].some(
            (node) =>
              node.y > source.y &&
              node.y < target.y &&
              node.x - 4 < startX &&
              startX < node.x + nodeWidth + 4,
          );
        if (endY - startY > rowGap && !clearVerticalPath) {
          const lane = left + groupWidth + 14 + longLinkIndex++ * 8;
          path += ` V ${startY + rowGap / 3} H ${lane} V ${endY - rowGap / 3} H ${endX}`;
        } else {
          path += ` V ${(startY + endY) / 2} H ${endX}`;
        }
        path += ` V ${endY - 3} m -4 -5 l 4 5 l 4 -5`;
        links.push({
          path,
          sourceId: parent,
          key: `${parent}:${id}`,
        });
      }
    }

    width = Math.max(width, x + slotWidth + padding);
    rowHeight = Math.max(
      rowHeight,
      rows.length * (nodeHeight + rowGap) - rowGap,
    );
    x += slotWidth + columnGap * 2;
  }

  return { nodes, links, width, height: y + rowHeight + padding };
}
