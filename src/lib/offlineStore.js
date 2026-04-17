const key = 'careflow.offline.v1';

export function loadOfflineState(seedFactory) {
  const saved = localStorage.getItem(key);

  if (saved) {
    return JSON.parse(saved);
  }

  const seeded = seedFactory();
  saveOfflineState(seeded);
  return seeded;
}

export function saveOfflineState(state) {
  localStorage.setItem(key, JSON.stringify(state));
}

export function clearOfflineState() {
  localStorage.removeItem(key);
}
