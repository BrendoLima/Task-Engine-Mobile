import React from 'react';
import {Pressable, StyleSheet, Text, TextInput, View} from 'react-native';

import {colors, radius, spacing} from '../theme';

type AddTaskBarProps = {
  value: string;
  onChangeText: (text: string) => void;
  onSubmit: () => void;
  bottomInset?: number;
};

export function AddTaskBar({
  value,
  onChangeText,
  onSubmit,
  bottomInset = 0,
}: AddTaskBarProps) {
  const disabled = value.trim().length === 0;

  return (
    <View
      style={[
        styles.container,
        {paddingBottom: Math.max(bottomInset, spacing.md)},
      ]}>
      <TextInput
        value={value}
        onChangeText={onChangeText}
        onSubmitEditing={onSubmit}
        placeholder="O que precisa ser feito?"
        placeholderTextColor={colors.textMuted}
        selectionColor={colors.accent}
        returnKeyType="done"
        maxLength={120}
        accessibilityLabel="Nova tarefa"
        style={styles.input}
      />
      <Pressable
        accessibilityRole="button"
        accessibilityLabel="Adicionar tarefa"
        accessibilityState={{disabled}}
        disabled={disabled}
        onPress={onSubmit}
        style={({pressed}) => [
          styles.button,
          disabled && styles.buttonDisabled,
          pressed && !disabled && styles.buttonPressed,
        ]}>
        <Text style={styles.buttonLabel}>+</Text>
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm + 2,
    paddingHorizontal: spacing.xl,
    paddingTop: spacing.md,
    borderTopWidth: 1,
    borderTopColor: colors.border,
    backgroundColor: colors.background,
  },
  input: {
    flex: 1,
    height: 50,
    paddingHorizontal: spacing.lg + 2,
    borderRadius: radius.pill,
    borderWidth: 1,
    borderColor: colors.border,
    backgroundColor: colors.surface,
    color: colors.text,
    fontSize: 15,
  },
  button: {
    width: 50,
    height: 50,
    borderRadius: 25,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: colors.accent,
  },
  buttonDisabled: {
    opacity: 0.35,
  },
  buttonPressed: {
    opacity: 0.8,
  },
  buttonLabel: {
    color: '#FFFFFF',
    fontSize: 26,
    fontWeight: '600',
    lineHeight: 30,
    marginTop: -2,
  },
});
