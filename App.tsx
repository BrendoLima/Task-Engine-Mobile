import React, {useCallback, useEffect, useMemo, useState} from 'react';
import {
  ActivityIndicator,
  FlatList,
  KeyboardAvoidingView,
  Platform,
  Pressable,
  StatusBar,
  StyleSheet,
  Text,
  View,
  type DimensionValue,
} from 'react-native';
import {
  SafeAreaProvider,
  SafeAreaView,
  useSafeAreaInsets,
} from 'react-native-safe-area-context';

import {AddTaskBar} from './src/components/AddTaskBar';
import {EmptyState} from './src/components/EmptyState';
import {FilterTabs, type TaskFilter} from './src/components/FilterTabs';
import {TaskItem} from './src/components/TaskItem';
import {loadTasks, saveTasks} from './src/storage';
import {colors, radius, spacing} from './src/theme';
import type {Task} from './src/types';

const WEEKDAYS = [
  'domingo',
  'segunda-feira',
  'terça-feira',
  'quarta-feira',
  'quinta-feira',
  'sexta-feira',
  'sábado',
];

const MONTHS = [
  'janeiro',
  'fevereiro',
  'março',
  'abril',
  'maio',
  'junho',
  'julho',
  'agosto',
  'setembro',
  'outubro',
  'novembro',
  'dezembro',
];

function todayLabel(): string {
  const now = new Date();
  const weekday = WEEKDAYS[now.getDay()];
  const month = MONTHS[now.getMonth()];
  return `${weekday}, ${now.getDate()} de ${month}`;
}

function createId(): string {
  return `${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 8)}`;
}

export default function App() {
  return (
    <SafeAreaProvider>
      <StatusBar barStyle="light-content" />
      <TaskEngine />
    </SafeAreaProvider>
  );
}

function TaskEngine() {
  const insets = useSafeAreaInsets();
  const [tasks, setTasks] = useState<Task[]>([]);
  const [filter, setFilter] = useState<TaskFilter>('all');
  const [draft, setDraft] = useState('');
  const [hydrated, setHydrated] = useState(false);

  useEffect(() => {
    let active = true;

    loadTasks().then(stored => {
      if (!active) {
        return;
      }
      setTasks(stored);
      setHydrated(true);
    });

    return () => {
      active = false;
    };
  }, []);

  useEffect(() => {
    if (hydrated) {
      saveTasks(tasks);
    }
  }, [tasks, hydrated]);

  const addTask = useCallback(() => {
    const title = draft.trim();
    if (!title) {
      return;
    }

    setTasks(current => [
      {id: createId(), title, done: false, createdAt: Date.now()},
      ...current,
    ]);
    setDraft('');
  }, [draft]);

  const toggleTask = useCallback((id: string) => {
    setTasks(current =>
      current.map(task =>
        task.id === id ? {...task, done: !task.done} : task,
      ),
    );
  }, []);

  const removeTask = useCallback((id: string) => {
    setTasks(current => current.filter(task => task.id !== id));
  }, []);

  const clearCompleted = useCallback(() => {
    setTasks(current => current.filter(task => !task.done));
  }, []);

  const remaining = useMemo(() => tasks.filter(t => !t.done).length, [tasks]);
  const completed = tasks.length - remaining;
  const progress = tasks.length === 0 ? 0 : completed / tasks.length;
  const progressPercent = Math.round(progress * 100);

  const visibleTasks = useMemo(() => {
    if (filter === 'active') {
      return tasks.filter(task => !task.done);
    }
    if (filter === 'done') {
      return tasks.filter(task => task.done);
    }
    return tasks;
  }, [filter, tasks]);

  return (
    <SafeAreaView style={styles.safeArea} edges={['top', 'left', 'right']}>
      <KeyboardAvoidingView
        style={styles.flex}
        behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
        <FlatList
          data={visibleTasks}
          keyExtractor={task => task.id}
          renderItem={({item}) => (
            <TaskItem task={item} onToggle={toggleTask} onRemove={removeTask} />
          )}
          contentContainerStyle={styles.listContent}
          ItemSeparatorComponent={Separator}
          keyboardShouldPersistTaps="handled"
          showsVerticalScrollIndicator={false}
          ListHeaderComponent={
            <View style={styles.header}>
              <Text style={styles.eyebrow}>TASK ENGINE</Text>
              <Text style={styles.title}>Hoje</Text>
              <Text style={styles.date}>{todayLabel()}</Text>

              <View style={styles.statsRow}>
                <StatCard value={remaining} label="a fazer" />
                <StatCard value={completed} label="concluídas" tone="success" />
                <View style={styles.progressCard}>
                  <Text style={styles.progressLabel}>{progressPercent}%</Text>
                  <View style={styles.progressTrack}>
                    <View
                      style={[
                        styles.progressFill,
                        {
                          width: `${progressPercent}%` as DimensionValue,
                        },
                      ]}
                    />
                  </View>
                  <Text style={styles.progressCaption}>do dia concluído</Text>
                </View>
              </View>

              <FilterTabs
                value={filter}
                onChange={setFilter}
                counts={{all: tasks.length, active: remaining, done: completed}}
              />
            </View>
          }
          ListEmptyComponent={
            hydrated ? <EmptyState filter={filter} /> : <LoadingState />
          }
          ListFooterComponent={
            completed > 0 ? (
              <Pressable
                accessibilityRole="button"
                accessibilityLabel="Limpar tarefas concluídas"
                onPress={clearCompleted}
                style={({pressed}) => [
                  styles.clearButton,
                  pressed && styles.pressed,
                ]}>
                <Text style={styles.clearLabel}>Limpar concluídas</Text>
              </Pressable>
            ) : undefined
          }
        />

        <AddTaskBar
          value={draft}
          onChangeText={setDraft}
          onSubmit={addTask}
          bottomInset={insets.bottom}
        />
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
}

type StatCardProps = {
  value: number;
  label: string;
  tone?: 'default' | 'success';
};

function StatCard({value, label, tone = 'default'}: StatCardProps) {
  return (
    <View style={styles.statCard}>
      <Text
        style={[
          styles.statValue,
          tone === 'success' && styles.statValueSuccess,
        ]}>
        {value}
      </Text>
      <Text style={styles.statLabel}>{label}</Text>
    </View>
  );
}

function Separator() {
  return <View style={styles.separator} />;
}

function LoadingState() {
  return (
    <View style={styles.loading}>
      <ActivityIndicator color={colors.accent} />
      <Text style={styles.loadingLabel}>Carregando suas tarefas…</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  flex: {
    flex: 1,
  },
  safeArea: {
    flex: 1,
    backgroundColor: colors.background,
  },
  listContent: {
    paddingHorizontal: spacing.xl,
    paddingBottom: spacing.lg,
  },
  header: {
    paddingTop: spacing.md,
    paddingBottom: spacing.lg,
  },
  eyebrow: {
    color: colors.accent,
    fontSize: 11,
    fontWeight: '700',
    letterSpacing: 2.5,
  },
  title: {
    color: colors.text,
    fontSize: 42,
    fontWeight: '800',
    letterSpacing: -1,
    marginTop: spacing.xs,
  },
  date: {
    color: colors.textMuted,
    fontSize: 14,
    marginTop: 2,
  },
  statsRow: {
    flexDirection: 'row',
    gap: spacing.sm,
    marginTop: spacing.xl,
  },
  statCard: {
    flex: 1,
    backgroundColor: colors.surface,
    borderRadius: radius.lg,
    borderWidth: 1,
    borderColor: colors.border,
    padding: spacing.md,
    justifyContent: 'center',
  },
  statValue: {
    color: colors.text,
    fontSize: 22,
    fontWeight: '800',
  },
  statValueSuccess: {
    color: colors.success,
  },
  statLabel: {
    color: colors.textMuted,
    fontSize: 11,
    fontWeight: '600',
    letterSpacing: 0.4,
    marginTop: 2,
    textTransform: 'uppercase',
  },
  progressCard: {
    flex: 1.5,
    backgroundColor: colors.surface,
    borderRadius: radius.lg,
    borderWidth: 1,
    borderColor: colors.border,
    padding: spacing.md,
    justifyContent: 'center',
  },
  progressLabel: {
    color: colors.accent,
    fontSize: 18,
    fontWeight: '800',
  },
  progressTrack: {
    height: 6,
    borderRadius: radius.pill,
    backgroundColor: colors.surfaceMuted,
    marginTop: spacing.sm,
    overflow: 'hidden',
  },
  progressFill: {
    height: '100%',
    borderRadius: radius.pill,
    backgroundColor: colors.success,
  },
  progressCaption: {
    color: colors.textMuted,
    fontSize: 10,
    marginTop: spacing.xs + 2,
  },
  separator: {
    height: spacing.sm + 2,
  },
  clearButton: {
    alignSelf: 'center',
    marginTop: spacing.lg,
    paddingHorizontal: spacing.lg,
    paddingVertical: spacing.sm,
    borderRadius: radius.pill,
    borderWidth: 1,
    borderColor: colors.border,
  },
  clearLabel: {
    color: colors.textMuted,
    fontSize: 12,
    fontWeight: '600',
  },
  loading: {
    alignItems: 'center',
    gap: spacing.md,
    paddingVertical: spacing.xxl,
  },
  loadingLabel: {
    color: colors.textMuted,
    fontSize: 13,
  },
  pressed: {
    opacity: 0.6,
  },
});
