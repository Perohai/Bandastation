import { Button, ProgressBar, Section, Table } from 'tgui-core/components';
import { useBackend } from '../backend';
import { Window } from '../layouts';

type HiveMember = {
  id: string;
  name: string;
  canFollow: boolean;
  following: boolean;
  caste: string;
  status: string;
  health: number;
};

type HiveStatusData = {
  members: HiveMember[];
  count: number;
  canFollow: boolean;
  points: { id: string; name: string; location: string; following: boolean }[];
};

const CASTE_NAMES: Record<string, string> = {
  larva: 'Личинка',
  carrier: 'Носитель',
  drone: 'Дрон',
  defender: 'Защитник',
  runner: 'Бегун',
  sentinel: 'Страж',
  spitter: 'Плевун',
  warrior: 'Воин',
  ravager: 'Разоритель',
  praetorian: 'Преторианец',
  queen: 'Королева',
  crusher: 'Крушитель',
  boiler: 'Бойлер',
  hunter: 'Охотник',
};

export function XenoHiveStatus() {
  const { act, data } = useBackend<HiveStatusData>();
  const { members = [], count = 0, canFollow, points = [] } = data;

  return (
    <Window width={740} height={520} title="Состав улья">
      <Window.Content>
        <Section
          fill
          scrollable
          title={`Обитатели улья · ${count}`}
          buttons={
            <Button icon="sync" onClick={() => act('refresh')}>
              Обновить
            </Button>
          }
        >
          {members.length === 0 ? (
            <Section color="label">Улей пока пуст.</Section>
          ) : (
            <Table>
              <Table.Row header>
                <Table.Cell>Ксеноморф</Table.Cell>
                <Table.Cell>Каста</Table.Cell>
                <Table.Cell>Состояние</Table.Cell>
                <Table.Cell>Здоровье</Table.Cell>
                {canFollow && <Table.Cell>Указатель</Table.Cell>}
              </Table.Row>
              {members.map((member) => (
                <Table.Row key={member.id}>
                  <Table.Cell>{member.name}</Table.Cell>
                  <Table.Cell>
                    {CASTE_NAMES[member.caste] || member.caste}
                  </Table.Cell>
                  <Table.Cell
                    color={member.status === 'В строю' ? 'green' : 'label'}
                  >
                    {member.status}
                  </Table.Cell>
                  <Table.Cell>
                    <ProgressBar
                      value={member.health / 100}
                      ranges={{
                        good: [0.7, 1],
                        average: [0.4, 0.7],
                        bad: [0, 0.4],
                      }}
                    >
                      {member.health}%
                    </ProgressBar>
                  </Table.Cell>
                  {canFollow && (
                    <Table.Cell>
                      {member.canFollow && (
                        <Button.Checkbox
                          checked={member.following}
                          onClick={() => act('follow', { id: member.id })}
                        >
                          Следовать
                        </Button.Checkbox>
                      )}
                    </Table.Cell>
                  )}
                </Table.Row>
              ))}
            </Table>
          )}
          {!!points.length && (
            <Section title="Точки сбора" mt={1}>
              <Table>
                {points.map((point) => (
                  <Table.Row key={point.id}>
                    <Table.Cell>{point.name}</Table.Cell>
                    <Table.Cell>{point.location}</Table.Cell>
                    <Table.Cell>
                      <Button.Checkbox
                        checked={point.following}
                        onClick={() => act('follow', { id: point.id })}
                      >
                        Следовать
                      </Button.Checkbox>
                    </Table.Cell>
                  </Table.Row>
                ))}
              </Table>
            </Section>
          )}
        </Section>
      </Window.Content>
    </Window>
  );
}
