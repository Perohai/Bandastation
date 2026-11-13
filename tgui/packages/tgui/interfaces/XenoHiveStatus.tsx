import { Button, ProgressBar, Section, Table } from 'tgui-core/components';
import { useBackend } from '../backend';
import { Window } from '../layouts';

type HiveMember = {
  name: string;
  caste: string;
  status: string;
  health: number;
};

type HiveStatusData = {
  members: HiveMember[];
  count: number;
};

const CASTE_NAMES: Record<string, string> = {
  larva: 'Личинка',
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
  const { members = [], count = 0 } = data;

  return (
    <Window width={640} height={520} title="Состав улья">
      <Window.Content>
        <Section
          fill
          scrollable
          title={`Члены улья · ${count}`}
          buttons={
            <Button icon="sync" onClick={() => act('refresh')}>
              Обновить
            </Button>
          }
        >
          {members.length === 0 ? (
            <Section color="label">В улье пока никого нет.</Section>
          ) : (
            <Table>
              <Table.Row header>
                <Table.Cell>Ксеноморф</Table.Cell>
                <Table.Cell>Каста</Table.Cell>
                <Table.Cell>Состояние</Table.Cell>
                <Table.Cell>Здоровье</Table.Cell>
              </Table.Row>
              {members.map((member, index) => (
                <Table.Row key={`${member.name}-${index}`}>
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
                </Table.Row>
              ))}
            </Table>
          )}
        </Section>
      </Window.Content>
    </Window>
  );
}
