import React from 'react';
import {Pressable, StyleSheet, Text, View} from 'react-native';

import {colors, radius, spacing} from '../theme';
import type {Task} from '../types';

type TaskItemProps = {
  task: Task;
  onToggle: (id: string) => void;
  onRemove: (id: string) => void;
};

export function TaskItem({task, onToggle, onRemove}: TaskItemProps) {
  return (
    <View style={[styles.row, task.done && styles.rowDone]}>
      <Pressable
        accessibilityRole="checkbox"
        accessibilityState={{checked: task.done}}
        accessibilityLabel={`Marcar "${task.title}" como ${
          task.done ? 'não concluída' : 'concluída'
        }`}
        onPress={() => onToggle(task.id)}
        hitSlop={10}
        style={({pressed}) => [
          styles.checkbox,
          task.done && styles.checkboxDone,
          pressed && styles.pressed,
        ]}>
        {task.done ? <Text style={styles.check}>✓</Text> : null}
      </Pressable>

      <Pressable
        accessibilityRole="button"
        accessibilityLabel={`Alternar tarefa "${task.title}"`}
        onPress={() => onToggle(task.id)}
        style={styles.titleArea}>
        <Text
          style={[styles.title, task.done && styles.titleDone]}
          numberOfLines={2}>
          {task.title}
        </Text>
      </Pressable>

      <Pressable
        accessibilityRole="button"
        accessibilityLabel={`Excluir tarefa "${task.title}"`}
        onPress={() => onRemove(task.id)}
        hitSlop={10}
        style={({pressed}) => [styles.remove, pressed && styles.pressed]}>
        <Text style={styles.removeIcon}>×</Text>
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.md,
    backgroundColor: colors.surface,
    borderRadius: radius.lg,
    borderWidth: 1,
    borderColor: colors.border,
    paddingVertical: spacing.md,
    paddingHorizontal: spacing.md + 2,
  },
  rowDone: {
    opacity: 0.65,
  },
  checkbox: {
    width: 26,
    height: 26,
    borderRadius: 13,
    borderWidth: 2,
    borderColor: colors.textMuted,
    alignItems: 'center',
    justifyContent: 'center',
  },
  checkboxDone: {
    backgroundColor: colors.success,
    borderColor: colors.success,
  },
  check: {
    color: '#08130E',
    fontSize: 14,
    fontWeight: '900',
    marginTop: -1,
  },
  titleArea: {
    flex: 1,
    paddingVertical: 2,
  },
  title: {
    color: colors.text,
    fontSize: 15,
    fontWeight: '600',
    lineHeight: 20,
  },
  titleDone: {
    color: colors.textMuted,
    textDecorationLine: 'line-through',
  },
  remove: {
    width: 28,
    height: 28,
    borderRadius: 14,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: colors.surfaceMuted,
  },
  removeIcon: {
    color: colors.textMuted,
    fontSize: 18,
    lineHeight: 20,
    marginTop: -1,
  },
  pressed: {
    opacity: 0.6,
  },
});
