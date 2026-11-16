import AsyncStorage from '@react-native-async-storage/async-storage';

import type {Task} from './types';

const STORAGE_KEY = '@task-engine/tasks/v1';

/**
 * Lê as tarefas salvas no dispositivo. Qualquer dado inválido é descartado
 * para que o app nunca quebre por causa de um estado antigo ou corrompido.
 */
export async function loadTasks(): Promise<Task[]> {
  try {
    const raw = await AsyncStorage.getItem(STORAGE_KEY);
    if (!raw) {
      return [];
    }

    const parsed: unknown = JSON.parse(raw);
    if (!Array.isArray(parsed)) {
      return [];
    }

    return parsed.filter(isTask);
  } catch {
    return [];
  }
}

export async function saveTasks(tasks: Task[]): Promise<void> {
  try {
    await AsyncStorage.setItem(STORAGE_KEY, JSON.stringify(tasks));
  } catch {
    // Sem persistência o app continua funcionando em memória.
  }
}

function isTask(value: unknown): value is Task {
  if (typeof value !== 'object' || value === null) {
    return false;
  }

  const task = value as Record<string, unknown>;
  return (
    typeof task.id === 'string' &&
    typeof task.title === 'string' &&
    typeof task.done === 'boolean' &&
    typeof task.createdAt === 'number'
  );
}
