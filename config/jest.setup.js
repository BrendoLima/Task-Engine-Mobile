import mockSafeAreaContext from 'react-native-safe-area-context/jest/mock';

jest.mock('@react-native-async-storage/async-storage', () => {
  const storage = new Map();
  const AsyncStorage = {
    getItem: jest.fn(async key => storage.get(key) ?? null),
    setItem: jest.fn(async (key, value) => {
      storage.set(key, value);
    }),
    removeItem: jest.fn(async key => {
      storage.delete(key);
    }),
    clear: jest.fn(async () => {
      storage.clear();
    }),
    getAllKeys: jest.fn(async () => Array.from(storage.keys())),
  };

  return {__esModule: true, default: AsyncStorage, ...AsyncStorage};
});

jest.mock('react-native-safe-area-context', () => mockSafeAreaContext);
