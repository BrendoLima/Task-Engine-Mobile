import React from 'react';
import {Pressable, StyleSheet, Text, View} from 'react-native';

import {colors, radius, spacing} from '../theme';

export type TaskFilter = 'all' | 'active' | 'done';

type FilterTabsProps = {
  value: TaskFilter;
  onChange: (filter: TaskFilter) => void;
  counts: Record<TaskFilter, number>;
};

const OPTIONS: Array<{key: TaskFilter; label: string}> = [
  {key: 'all', label: 'Todas'},
  {key: 'active', label: 'Ativas'},
  {key: 'done', label: 'Feitas'},
];

export function FilterTabs({value, onChange, counts}: FilterTabsProps) {
  return (
    <View style={styles.container} accessibilityRole="tablist">
      {OPTIONS.map(option => {
        const selected = option.key === value;

        return (
          <Pressable
            key={option.key}
            accessibilityRole="tab"
            accessibilityState={{selected}}
            onPress={() => onChange(option.key)}
            style={({pressed}) => [
              styles.tab,
              selected && styles.tabSelected,
              pressed && styles.pressed,
            ]}>
            <Text style={[styles.label, selected && styles.labelSelected]}>
              {option.label}
            </Text>
            <View style={[styles.badge, selected && styles.badgeSelected]}>
              <Text
                style={[
                  styles.badgeLabel,
                  selected && styles.badgeLabelSelected,
                ]}>
                {counts[option.key]}
              </Text>
            </View>
          </Pressable>
        );
      })}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    gap: spacing.xs,
    marginTop: spacing.xl,
    padding: spacing.xs,
    borderRadius: radius.pill,
    borderWidth: 1,
    borderColor: colors.border,
    backgroundColor: colors.surface,
  },
  tab: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 6,
    paddingVertical: spacing.sm,
    borderRadius: radius.pill,
  },
  tabSelected: {
    backgroundColor: colors.accentSoft,
  },
  label: {
    color: colors.textMuted,
    fontSize: 13,
    fontWeight: '600',
  },
  labelSelected: {
    color: colors.accent,
    fontWeight: '700',
  },
  badge: {
    minWidth: 20,
    height: 20,
    paddingHorizontal: 5,
    borderRadius: radius.pill,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: colors.surfaceMuted,
  },
  badgeSelected: {
    backgroundColor: 'rgba(91, 140, 255, 0.28)',
  },
  badgeLabel: {
    color: colors.textMuted,
    fontSize: 11,
    fontWeight: '700',
  },
  badgeLabelSelected: {
    color: colors.accent,
  },
  pressed: {
    opacity: 0.6,
  },
});
