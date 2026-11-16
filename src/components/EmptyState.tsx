import React from 'react';
import {StyleSheet, Text, View} from 'react-native';

import {colors, radius, spacing} from '../theme';
import type {TaskFilter} from './FilterTabs';

type EmptyStateProps = {
  filter: TaskFilter;
};

const COPY: Record<
  TaskFilter,
  {icon: string; title: string; body: string}
> = {
  all: {
    icon: '+',
    title: 'Nenhuma tarefa ainda',
    body: 'Adicione a primeira tarefa abaixo e comece o dia.',
  },
  active: {
    icon: '✓',
    title: 'Tudo em dia',
    body: 'Você não tem tarefas pendentes. Aproveite a folga!',
  },
  done: {
    icon: '○',
    title: 'Nada concluído',
    body: 'Marque tarefas como concluídas para vê-las aqui.',
  },
};

export function EmptyState({filter}: EmptyStateProps) {
  const {icon, title, body} = COPY[filter];

  return (
    <View style={styles.container}>
      <View style={styles.iconCircle}>
        <Text style={styles.icon}>{icon}</Text>
      </View>
      <Text style={styles.title}>{title}</Text>
      <Text style={styles.body}>{body}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    alignItems: 'center',
    paddingVertical: spacing.xxl,
    paddingHorizontal: spacing.lg,
  },
  iconCircle: {
    width: 64,
    height: 64,
    borderRadius: radius.pill,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: colors.surface,
    borderWidth: 1,
    borderColor: colors.border,
    marginBottom: spacing.lg,
  },
  icon: {
    color: colors.accent,
    fontSize: 26,
    fontWeight: '700',
  },
  title: {
    color: colors.text,
    fontSize: 18,
    fontWeight: '700',
    textAlign: 'center',
  },
  body: {
    color: colors.textMuted,
    fontSize: 14,
    lineHeight: 20,
    textAlign: 'center',
    marginTop: spacing.sm,
    maxWidth: 280,
  },
});
