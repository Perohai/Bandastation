import { afterEach, expect, it, spyOn } from 'bun:test';
import { fireEvent, render, screen } from '@testing-library/react';
import fixture from 'tgui-dev-server/preview/fixtures/space-navigation.json';

import * as actions from '../../events/act';
import { gameDataAtom, resetStore, store } from '../../events/store';
import { descentPlot } from './Descent';
import { SpaceNavigation } from './index';
import type { NavigationData } from './types';

afterEach(resetStore);

it('distinguishes throttle buttons from the lever and sounds local tabs', () => {
  const sendAct = spyOn(actions, 'sendAct').mockImplementation(() => {});
  try {
    store.set(gameDataAtom, { ...fixture.data, throttle: 0 });
    render(<SpaceNavigation />);

    fireEvent.click(screen.getByLabelText('Увеличить тягу'));
    expect(sendAct).toHaveBeenLastCalledWith('throttle', {
      value: 5,
      button: true,
    });

    fireEvent.keyDown(screen.getByRole('slider', { name: 'Тяга, проценты' }), {
      key: 'Home',
    });
    expect(sendAct).toHaveBeenLastCalledWith('throttle', {
      value: 0,
      button: false,
    });

    fireEvent.click(screen.getByLabelText('Уменьшить тягу'));
    expect(sendAct).toHaveBeenLastCalledWith('throttle', {
      value: -5,
      button: true,
    });

    fireEvent.click(screen.getByRole('tab', { name: 'КОНТАКТЫ' }));
    expect(sendAct).toHaveBeenLastCalledWith('interface_click');
  } finally {
    sendAct.mockRestore();
  }
});

it('approaches the inspected person and docks only to their own rescue site', () => {
  const sendAct = spyOn(actions, 'sendAct').mockImplementation(() => {});
  try {
    const human = { kind: 'human', name: 'Человек', dead: 0 };
    store.set(gameDataAtom, {
      ...fixture.data,
      control_revision: 17,
      can_approach_biosignature: 1,
      can_dock: 1,
      selected: 'rescue-site',
      selected_biosignature: 8,
      ship_contacts: [
        { id: 7, x: 805, y: 420, age: 1, mode: 'active', fauna: human },
        {
          id: 8,
          x: 820,
          y: 400,
          age: 2,
          mode: 'active',
          fauna: { ...human, dead: 1 },
        },
      ],
    });
    render(<SpaceNavigation />);

    fireEvent.click(screen.getByLabelText('Биосигнатура 7 · Человек · жив'));
    fireEvent.click(screen.getByText('Подлететь'));
    expect(sendAct).toHaveBeenLastCalledWith('approach_biosignature', {
      value: 7,
      revision: 17,
    });
    expect(
      screen
        .getByLabelText('Стыковка недоступна')
        .classList.contains('Button--disabled'),
    ).toBe(true);

    fireEvent.click(screen.getByLabelText('Биосигнатура 8 · Человек · мёртв'));
    fireEvent.click(screen.getByLabelText('Стыковка с зоной спасения'));
    expect(sendAct).toHaveBeenLastCalledWith('dock', { value: 'rescue-site' });
  } finally {
    sendAct.mockRestore();
  }
});

it('starts the plotted entry only at the announced atmospheric cue', () => {
  const approach: NonNullable<NavigationData['approach']> = {
    elapsed: 0,
    duration: 170,
    departing: false,
    site: 'Test planet',
    scene: 'planet',
    biome: null,
    loading: true,
    planet_timing: {
      orbit_duration: 120,
      descent_start: null,
      entry_start: null,
      entry_end: null,
      liftoff: null,
      ascent_cloud: null,
      ascent_orbit: null,
    },
  };

  const loading = descentPlot(approach, 145);
  expect(loading.heat).toBe(0);
  expect(loading.countdown).toBe(false);
  expect(loading.flown).toBeGreaterThan(descentPlot(approach, 120).flown);

  approach.planet_timing!.descent_start = 145;
  approach.planet_timing!.entry_start = 148;
  approach.planet_timing!.entry_end = 154;
  expect(descentPlot(approach, 145).flown).toBe(loading.flown);
  expect(descentPlot(approach, 147).heat).toBe(0);
  expect(descentPlot(approach, 151).heat).toBe(1);
  expect(descentPlot(approach, 154).heat).toBe(0);
});
