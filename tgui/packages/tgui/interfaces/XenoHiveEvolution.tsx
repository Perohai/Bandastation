import '../styles/themes/xeno-hive.scss';
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

import { HiveTree, isComplete } from './XenoHiveEvolution/HiveTree';
import type {
  Upgrade,
  UpgradeDefinition,
  UpgradeState,
} from './XenoHiveEvolution/layoutTree';

type Data = {
  biomass: number;
  territoryTiles: number;
  territoryPending: number;
  territoryBatch: number;
  territoryEarned: number;
  crew: number;
  broodRate: number;
  canDebug: boolean;
  debugUsed: boolean;
  broodPoints: number;
  broodCost: number;
  broodPlaces: number;
  broodBlocked: boolean;
  core: boolean;
  packedCore: boolean;
  busy: boolean;
  canPlace: boolean;
  canPack: boolean;
  nodes: UpgradeDefinition[];
  nodeState: Record<string, UpgradeState>;
};

const emptyDefinitions: UpgradeDefinition[] = [];

const categories = [
  { name: 'Эволюция', icon: 'dna' },
  { name: 'Биоструктуры', icon: 'seedling' },
  { name: 'Популяция', icon: 'egg' },
  { name: 'Выводок', icon: 'bugs' },
];

export function XenoHiveEvolution() {
  const { act, data } = useBackend<Data>();
  const [category, setCategory] = useState(categories[0].name);
  const [selectedId, setSelectedId] = useState<string>();
  const [targetId, setTargetId] = useState<string | null>(null);
  const definitions = data.nodes ?? emptyDefinitions;
  const upgrades = definitions.map((node) => ({
    ...node,
    ...(data.nodeState?.[node.id] ?? { cost: 0, level: 0, available: false }),
  }));
  const byId = new Map(upgrades.map((node) => [node.id, node]));
  const current = selectedId ? byId.get(selectedId) : undefined;
  const selected =
    current?.category === category
      ? current
      : upgrades.find((node) => node.category === category);

  function selectNode(node: Upgrade) {
    setSelectedId(node.id);
    setCategory(node.category);
    setTargetId(node.category === category ? null : node.id);
  }

  return (
    <Window width={1220} height={800} title="Эволюция улья" theme="xeno-hive">
      <Window.Content fitted scrollable>
        <div className="Hive-layout">
          <Section className="Hive-vitals">
            <Stack align="center">
              <Stack.Item className="Hive-reserve">
                <Box className="Hive-biomass">
                  <Icon name="leaf" /> {data.biomass} биомассы
                </Box>
                {data.canDebug && (
                  <Button.Checkbox
                    checked={data.debugUsed}
                    disabled={data.debugUsed}
                    onClick={() => act('debug')}
                    mt={0.5}
                  >
                    Отладка: 99999 биомассы
                  </Button.Checkbox>
                )}
              </Stack.Item>
              <Stack.Item grow className="Hive-metrics">
                <Box color="label" mt={0.5}>
                  Выводок: {data.broodPoints} / {data.broodCost} · Мест в яйцах:{' '}
                  {data.broodPlaces}
                </Box>
                <Box color="label" mt={0.5}>
                  Рост: {data.broodRate} очков/мин · Живой экипаж: {data.crew}
                </Box>
                <Box color="label" mt={0.5}>
                  Территория: {data.territoryTiles} клеток · Заработано:{' '}
                  {data.territoryEarned} · Прогресс выплаты:{' '}
                  {data.territoryPending}/{data.territoryBatch}
                </Box>
              </Stack.Item>
              <Stack.Item>
                <Box className="Hive-coreStatus">
                  {data.core
                    ? 'Ядро улья установлено'
                    : data.packedCore
                      ? 'Ядро улья свёрнуто'
                      : 'Ядро улья отсутствует'}
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
                  tooltip="Свёрнутое ядро можно перенести и развернуть на траве. Свободные места в яйцах и накопленные очки выводка пропадут."
                >
                  Свернуть
                </Button>
              </Stack.Item>
            </Stack>
          </Section>
          {data.core && data.crew === 0 && (
            <NoticeBox>
              Доход выводка остановлен: среди живого экипажа нет существ,
              учитываемых экономикой улья. Призраки и ксеноморфы на рост не
              влияют.
            </NoticeBox>
          )}
          {data.broodBlocked && (
            <NoticeBox>
              Рядом с ядром не осталось места для яиц. Накопленные очки
              сохранятся.
            </NoticeBox>
          )}
          <Tabs fluid>
            {categories.map(({ name, icon }) => (
              <Tabs.Tab
                key={name}
                icon={icon}
                selected={name === category}
                onClick={() => {
                  setCategory(name);
                  setTargetId(null);
                }}
              >
                {name}
              </Tabs.Tab>
            ))}
          </Tabs>
          <div className="Hive-workspace">
            <HiveTree
              key={category}
              category={category}
              definitions={definitions}
              upgradesById={byId}
              selectedId={selected?.id}
              targetId={targetId}
              onSelect={selectNode}
            />
            {selected && (
              <aside className="Hive-detail" aria-label="Выбранная технология">
                <div className="Hive-detailBody">
                  <h2>
                    <Icon name={selected.icon} /> {selected.name}
                  </h2>
                  <p>{selected.description}</p>
                  {!!selected.requires.length && (
                    <div className="Hive-requirements">
                      <h3>Требования</h3>
                      {selected.requires.map((id) => {
                        const required = byId.get(id);
                        const icon = required?.level ? 'check' : 'lock';
                        return required && required.category !== category ? (
                          <Button
                            key={id}
                            fluid
                            icon={icon}
                            onClick={() => selectNode(required)}
                          >
                            {required.name} ↗{' '}
                            <span className="Hive-requirementCategory">
                              {required.category}
                            </span>
                          </Button>
                        ) : (
                          <Box
                            key={id}
                            mb={0.5}
                            color={required?.level ? 'good' : 'label'}
                          >
                            <Icon name={icon} /> {required?.name ?? id}
                          </Box>
                        );
                      })}
                    </div>
                  )}
                  {selected.id === 'larva' && !data.core && (
                    <NoticeBox>
                      Для создания яйца нужно установить ядро улья.
                    </NoticeBox>
                  )}
                </div>
                <div className="Hive-detailActions">
                  <Button
                    fluid
                    icon={isComplete(selected) ? 'check' : 'dna'}
                    disabled={!selected.available}
                    onClick={() => act('buy', { id: selected.id })}
                  >
                    {isComplete(selected)
                      ? 'Изучено'
                      : `Развить · ${selected.cost}`}
                  </Button>
                  <Box color="label" mt={0.5}>
                    Изученные адаптации сохраняются даже при смене королевы.
                  </Box>
                </div>
              </aside>
            )}
          </div>
          <NoticeBox className="Hive-footnote" mt={1}>
            {data.busy ? 'Королева уже развивает улей. ' : ''}
            Изучение адаптации занимает 5 секунд. Движение, получение урона или
            потеря сознания прервут процесс. Биомасса списывается только после
            завершения. Можно развивать несколько ветвей, но сбросить улучшения
            нельзя.
          </NoticeBox>
        </div>
      </Window.Content>
    </Window>
  );
}
