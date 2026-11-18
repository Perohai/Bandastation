import { expect, test } from 'bun:test';
import { layoutTree, type Upgrade } from './layoutTree';

const node = (
  id: string,
  requires: string[] = [],
  category = 'Выводок',
): Upgrade => ({
  id,
  name: id,
  description: '',
  category,
  icon: 'dna',
  cost: 100,
  level: 0,
  maxLevel: 1,
  requires,
  available: false,
});

test('shows only real links across a fork, a join and a category boundary', () => {
  const upgrades = [
    node('root', ['external']),
    node('left', ['root']),
    node('right', ['root']),
    node('join', ['left', 'right']),
    node('tile'),
    node('external', ['private'], 'Биоструктуры'),
    node('private', [], 'Биоструктуры'),
  ];
  const { nodes, links } = layoutTree(upgrades, 'Выводок', 900);
  expect(
    nodes.filter((entry) => entry.external).map((entry) => entry.upgrade.id),
  ).toEqual(['external']);
  expect(links.map((link) => link.key).sort()).toEqual([
    'external:root',
    'left:join',
    'right:join',
    'root:left',
    'root:right',
  ]);

  const position = new Map(nodes.map((entry) => [entry.upgrade.id, entry]));
  expect(position.get('left')!.x).not.toBe(position.get('right')!.x);
  expect(position.get('join')!.y).toBeGreaterThan(position.get('left')!.y);
});

test('wraps independent tiles on narrow canvases without adding links', () => {
  const upgrades = [node('first'), node('second'), node('third')];
  const wide = layoutTree(upgrades, 'Выводок', 900);
  expect(wide.links).toEqual([]);
  expect(wide.nodes[0].y).toBe(wide.nodes[1].y);
  expect(wide.nodes[2].y).toBeGreaterThan(wide.nodes[1].y);

  const narrow = layoutTree(upgrades, 'Выводок', 350);
  expect(narrow.width).toBeLessThan(350);
  expect(narrow.nodes[1].y).toBeGreaterThan(narrow.nodes[0].y);
});
