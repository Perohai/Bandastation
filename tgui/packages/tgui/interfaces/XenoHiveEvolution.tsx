import { useState } from 'react';
import {
  Box,
  Button,
  Icon,
  NoticeBox,
  Section,
  Stack,
  Tabs,
} from 'tgui-core/components';
import { useBackend } from '../backend';
import { Window } from '../layouts';

type Upgrade = {
  id: string;
  name: string;
  description: string;
  branch: string;
  icon: string;
  x: number;
  y: number;
  cost: number;
  level: number;
  maxLevel: number | null;
  requires: string[];
  available: boolean;
};

type Data = {
  biomass: number;
  broodPoints: number;
  broodCost: number;
  broodPlaces: number;
  core: boolean;
  busy: boolean;
  canPlace: boolean;
  canPack: boolean;
  nodes: Upgrade[];
};

const branches = [
  { name: 'Качество', icon: 'dna', color: '#b99bea' },
  { name: 'Количество', icon: 'egg', color: '#e7b674' },
  { name: 'Функциональность', icon: 'sitemap', color: '#79c9bb' },
];
const cardWidth = 168;
const cardHeight = 132;
const nodeX = (node: Upgrade) => 120 + node.x * 195;
const nodeY = (node: Upgrade) => 24 + node.y * 164;
const complete = (node: Upgrade) =>
  node.maxLevel !== null && node.level >= node.maxLevel;

export function XenoHiveEvolution() {
  const { act, data } = useBackend<Data>();
  const [branchIndex, setBranchIndex] = useState(0);
  const [selectedId, setSelectedId] = useState('carapace');
  const branch = branches[branchIndex];
  const nodes = data.nodes.filter((node) => node.branch === branch.name);
  const selected = nodes.find((node) => node.id === selectedId) || nodes[0];
  const byId = Object.fromEntries(data.nodes.map((node) => [node.id, node]));
  const width = 315 + Math.max(0, ...nodes.map((node) => node.x)) * 195;
  const height = 170 + Math.max(0, ...nodes.map((node) => node.y)) * 164;
  const rootY = height / 2;

  return (
    <Window width={1220} height={800} title="Эволюция улья" theme="abductor">
      <Window.Content scrollable>
        <Section>
          <Stack align="center" justify="space-between">
            <Stack.Item>
              <Box fontSize={2} bold color="good">
                <Icon name="leaf" /> {data.biomass} биомассы
              </Box>
              <Box color="label" mt={0.5}>
                Выводок: {data.broodPoints} / {data.broodCost} · Мест в кладке:{' '}
                {data.broodPlaces}
              </Box>
            </Stack.Item>
            <Stack.Item>
              <Box mb={0.5}>
                {data.core ? 'Ядро улья установлено' : 'Ядро улья отсутствует'}
              </Box>
              <Button
                icon="seedling"
                disabled={!data.canPlace}
                onClick={() => act('place_core')}
              >
                Установить ядро
              </Button>
              <Button
                icon="arrows-up-down-left-right"
                disabled={!data.canPack}
                onClick={() => act('pack_core')}
                tooltip="Свободные места и дробные очки выводка будут потеряны. Новое ядро устанавливается на траве."
              >
                Свернуть
              </Button>
            </Stack.Item>
          </Stack>
        </Section>
        <Tabs fluid>
          {branches.map((entry, index) => (
            <Tabs.Tab
              key={entry.name}
              icon={entry.icon}
              selected={index === branchIndex}
              onClick={() => setBranchIndex(index)}
            >
              {entry.name}
            </Tabs.Tab>
          ))}
        </Tabs>
        <Stack align="stretch" mt={1}>
          <Stack.Item grow basis={0} style={{ minWidth: 0 }}>
            <Section title={`Дерево: ${branch.name}`}>
              <Box color="label" mb={1}>
                Выберите узел. Линии показывают обязательные предшествующие
                улучшения.
              </Box>
              <div
                style={{
                  overflow: 'auto',
                  height: 530,
                  background: '#10171c',
                  borderRadius: 4,
                }}
              >
                <div
                  style={{
                    position: 'relative',
                    width,
                    height: Math.max(height, 510),
                  }}
                >
                  <svg
                    width={width}
                    height={Math.max(height, 510)}
                    style={{ position: 'absolute', inset: 0 }}
                    aria-hidden="true"
                  >
                    {nodes.flatMap((node) => {
                      const parents = node.requires
                        .map((id) => byId[id])
                        .filter(Boolean);
                      const sources = parents.length
                        ? parents.map((parent) => ({
                            x: nodeX(parent) + cardWidth,
                            y: nodeY(parent) + cardHeight / 2,
                            owned: parent.level > 0,
                          }))
                        : [{ x: 72, y: rootY, owned: true }];
                      return sources.map((source, index) => (
                        <path
                          key={`${node.id}-${index}`}
                          d={
                            !parents.length && node.x > 0
                              ? `M ${source.x} ${source.y} L 92 ${source.y} L 92 ${height - 8} L ${nodeX(node) - 16} ${height - 8} L ${nodeX(node) - 16} ${nodeY(node) + cardHeight / 2} L ${nodeX(node)} ${nodeY(node) + cardHeight / 2}`
                              : `M ${source.x} ${source.y} C ${source.x + 24} ${source.y}, ${nodeX(node) - 24} ${nodeY(node) + cardHeight / 2}, ${nodeX(node)} ${nodeY(node) + cardHeight / 2}`
                          }
                          stroke={source.owned ? branch.color : '#68768b'}
                          strokeWidth={3}
                          strokeDasharray={parents.length ? undefined : '4 4'}
                          fill="none"
                        />
                      ));
                    })}
                  </svg>
                  <Box
                    style={{
                      position: 'absolute',
                      left: 14,
                      top: rootY - 28,
                      width: 58,
                      textAlign: 'center',
                    }}
                  >
                    <Icon name="sitemap" size={2} color={branch.color} />
                    <Box mt={0.5} fontSize={0.85}>
                      Улей
                    </Box>
                  </Box>
                  {nodes.map((node) => (
                    <Box
                      key={node.id}
                      style={{
                        position: 'absolute',
                        left: nodeX(node),
                        top: nodeY(node),
                        width: cardWidth,
                      }}
                    >
                      <Button
                        fluid
                        onClick={() => setSelectedId(node.id)}
                        tooltip={node.description}
                        style={{
                          height: cardHeight,
                          whiteSpace: 'normal',
                          textAlign: 'center',
                          background:
                            selected?.id === node.id ? '#384154' : '#202a34',
                          border: `2px solid ${complete(node) ? '#79bc8e' : selected?.id === node.id ? branch.color : '#46505e'}`,
                        }}
                      >
                        <Box mb={0.7}>
                          <Icon
                            name={node.icon}
                            size={2.5}
                            color={complete(node) ? '#79bc8e' : branch.color}
                          />
                        </Box>
                        <Box bold lineHeight={1.2}>
                          {node.name}
                        </Box>
                        <Box
                          mt={0.7}
                          color={
                            complete(node)
                              ? 'good'
                              : node.available
                                ? 'white'
                                : 'label'
                          }
                        >
                          {complete(node) ? (
                            <>
                              <Icon name="check" /> Изучено
                            </>
                          ) : (
                            <>
                              {!node.available && <Icon name="lock" />}{' '}
                              {node.cost} биомассы
                            </>
                          )}
                        </Box>
                        {node.maxLevel !== 1 && (
                          <Box mt={0.2} fontSize={0.8}>
                            Куплено: {node.level}
                            {node.maxLevel !== null && ` / ${node.maxLevel}`}
                          </Box>
                        )}
                      </Button>
                    </Box>
                  ))}
                </div>
              </div>
            </Section>
          </Stack.Item>
          <Stack.Item basis="270px" shrink={0}>
            {selected && (
              <Section title="Выбранная адаптация" fill>
                <Box textAlign="center" my={2}>
                  <Icon name={selected.icon} size={4} color={branch.color} />
                </Box>
                <Box bold fontSize={1.4} mb={1}>
                  {selected.name}
                </Box>
                <Box mb={2} lineHeight={1.5}>
                  {selected.description}
                </Box>
                {!!selected.requires.length && (
                  <Box mb={2}>
                    <Box color="label" mb={0.5}>
                      Предшествующие узлы
                    </Box>
                    {selected.requires.map((id) => (
                      <Box
                        key={id}
                        mb={0.5}
                        color={byId[id]?.level ? 'good' : 'label'}
                      >
                        <Icon name={byId[id]?.level ? 'check' : 'lock'} />{' '}
                        {byId[id]?.name || id}
                      </Box>
                    ))}
                  </Box>
                )}
                <Button
                  fluid
                  icon={complete(selected) ? 'check' : 'dna'}
                  disabled={!selected.available}
                  onClick={() => act('buy', { id: selected.id })}
                >
                  {complete(selected)
                    ? 'Изучено'
                    : `Развить · ${selected.cost}`}
                </Button>
                <Box mt={1} color="label">
                  Покупки сохраняются при смене королевы.
                </Box>
                {selected.id === 'larva' && !data.core && (
                  <NoticeBox mt={1}>Для яйца установите ядро.</NoticeBox>
                )}
              </Section>
            )}
          </Stack.Item>
        </Stack>
        <NoticeBox mt={1}>
          {data.busy ? 'Королева занята развитием улья. ' : ''}
          Покупка занимает 5 секунд. Движение, урон и потеря сознания прерывают
          её. Биомасса списывается после завершения. Ветки можно смешивать;
          сброса нет.
        </NoticeBox>
      </Window.Content>
    </Window>
  );
}
