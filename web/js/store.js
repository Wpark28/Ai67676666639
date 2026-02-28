// ===== IndexedDB Data Store =====
// Persistent storage for all app data

const DB_NAME = 'ergai';
const DB_VERSION = 1;

const Store = {
  db: null,

  async init() {
    return new Promise((resolve, reject) => {
      const req = indexedDB.open(DB_NAME, DB_VERSION);
      req.onupgradeneeded = (e) => {
        const db = e.target.result;
        if (!db.objectStoreNames.contains('profile')) db.createObjectStore('profile', { keyPath: 'id' });
        if (!db.objectStoreNames.contains('scores')) {
          const s = db.createObjectStore('scores', { keyPath: 'id', autoIncrement: true });
          s.createIndex('date', 'date');
        }
        if (!db.objectStoreNames.contains('dailyStatus')) {
          const d = db.createObjectStore('dailyStatus', { keyPath: 'id', autoIncrement: true });
          d.createIndex('date', 'date');
        }
        if (!db.objectStoreNames.contains('gymSessions')) {
          const g = db.createObjectStore('gymSessions', { keyPath: 'id', autoIncrement: true });
          g.createIndex('date', 'date');
        }
        if (!db.objectStoreNames.contains('calorieEntries')) {
          const c = db.createObjectStore('calorieEntries', { keyPath: 'id', autoIncrement: true });
          c.createIndex('date', 'date');
        }
        if (!db.objectStoreNames.contains('hrSessions')) {
          const h = db.createObjectStore('hrSessions', { keyPath: 'id', autoIncrement: true });
          h.createIndex('date', 'date');
        }
        if (!db.objectStoreNames.contains('baselines')) db.createObjectStore('baselines', { keyPath: 'id' });
      };
      req.onsuccess = (e) => { this.db = e.target.result; resolve(); };
      req.onerror = () => reject(req.error);
    });
  },

  // Generic CRUD
  async put(storeName, data) {
    return new Promise((resolve, reject) => {
      const tx = this.db.transaction(storeName, 'readwrite');
      tx.objectStore(storeName).put(data);
      tx.oncomplete = () => resolve();
      tx.onerror = () => reject(tx.error);
    });
  },

  async get(storeName, key) {
    return new Promise((resolve, reject) => {
      const tx = this.db.transaction(storeName, 'readonly');
      const req = tx.objectStore(storeName).get(key);
      req.onsuccess = () => resolve(req.result);
      req.onerror = () => reject(req.error);
    });
  },

  async getAll(storeName) {
    return new Promise((resolve, reject) => {
      const tx = this.db.transaction(storeName, 'readonly');
      const req = tx.objectStore(storeName).getAll();
      req.onsuccess = () => resolve(req.result || []);
      req.onerror = () => reject(req.error);
    });
  },

  async delete(storeName, key) {
    return new Promise((resolve, reject) => {
      const tx = this.db.transaction(storeName, 'readwrite');
      tx.objectStore(storeName).delete(key);
      tx.oncomplete = () => resolve();
      tx.onerror = () => reject(tx.error);
    });
  },

  async clear(storeName) {
    return new Promise((resolve, reject) => {
      const tx = this.db.transaction(storeName, 'readwrite');
      tx.objectStore(storeName).clear();
      tx.oncomplete = () => resolve();
      tx.onerror = () => reject(tx.error);
    });
  },

  // ===== Profile =====
  async getProfile() {
    const all = await this.getAll('profile');
    return all[0] || null;
  },

  async saveProfile(profile) {
    profile.id = 'main';
    return this.put('profile', profile);
  },

  // ===== Scores =====
  async getScores() {
    const all = await this.getAll('scores');
    return all.sort((a, b) => new Date(b.date) - new Date(a.date));
  },

  async addScore(score) {
    score.date = score.date || new Date().toISOString();
    return this.put('scores', score);
  },

  // ===== Daily Status =====
  async getDailyStatuses() {
    const all = await this.getAll('dailyStatus');
    return all.sort((a, b) => new Date(b.date) - new Date(a.date));
  },

  async saveDailyStatus(status) {
    status.date = status.date || new Date().toISOString();
    return this.put('dailyStatus', status);
  },

  async getTodayStatus() {
    const all = await this.getDailyStatuses();
    const today = new Date().toDateString();
    return all.find(s => new Date(s.date).toDateString() === today) || null;
  },

  // ===== Gym Sessions =====
  async getGymSessions() {
    const all = await this.getAll('gymSessions');
    return all.sort((a, b) => new Date(b.date) - new Date(a.date));
  },

  async saveGymSession(session) {
    session.date = session.date || new Date().toISOString();
    return this.put('gymSessions', session);
  },

  // ===== Calorie Entries =====
  async getCalorieEntries() {
    const all = await this.getAll('calorieEntries');
    return all.sort((a, b) => new Date(b.date) - new Date(a.date));
  },

  async addCalorieEntry(entry) {
    entry.date = entry.date || new Date().toISOString();
    return this.put('calorieEntries', entry);
  },

  async getTodayCalories() {
    const all = await this.getCalorieEntries();
    const today = new Date().toDateString();
    return all.filter(e => new Date(e.date).toDateString() === today);
  },

  // ===== Baselines =====
  async getBaselines() {
    return (await this.get('baselines', 'main')) || {
      id: 'main',
      hrvBaseline: 55,
      rhrBaseline: 60,
      respRateBaseline: 15,
      spo2Baseline: 97,
      sleepBaseline: 450,
      tempBaseline: 0,
      sampleCount: 0
    };
  },

  async saveBaselines(baselines) {
    baselines.id = 'main';
    return this.put('baselines', baselines);
  }
};

// ===== Default Profile =====
function createDefaultProfile() {
  return {
    id: 'main',
    name: '',
    age: 20,
    weight: 80,
    height: 180,
    gender: 'male',
    experienceLevel: 'intermediate',
    maxHR: 195,
    restingHR: 60,
    pr2k: null,
    pr5k: null,
    pr6k: null,
    pr30min: null,
    totalWorkouts: 0,
    totalLifetimeMeters: 0,
    currentWeekSessions: 0,
    currentWeekMeters: 0,
    streakDays: 0,
    fitnessScore: 50,
    fatigueScore: 30,
    formScore: 20,
    weeklyGoalSessions: 5,
    weeklyGoalMeters: 50000,
    calorieTarget: 2500,
    proteinTarget: 150,
    carbTarget: 300,
    fatTarget: 80
  };
}

// ===== Food Library =====
const FoodLibrary = [
  { name: 'Chicken Breast (6oz)', cal: 280, protein: 53, carbs: 0, fat: 6 },
  { name: 'Brown Rice (1 cup)', cal: 215, protein: 5, carbs: 45, fat: 2 },
  { name: 'Salmon (6oz)', cal: 350, protein: 40, carbs: 0, fat: 20 },
  { name: 'Eggs (2 large)', cal: 140, protein: 12, carbs: 1, fat: 10 },
  { name: 'Greek Yogurt (1 cup)', cal: 130, protein: 22, carbs: 8, fat: 1 },
  { name: 'Banana', cal: 105, protein: 1, carbs: 27, fat: 0 },
  { name: 'Oatmeal (1 cup)', cal: 300, protein: 10, carbs: 54, fat: 5 },
  { name: 'Whey Protein Shake', cal: 150, protein: 30, carbs: 3, fat: 2 },
  { name: 'Pasta (2 cups cooked)', cal: 400, protein: 14, carbs: 78, fat: 2 },
  { name: 'Sweet Potato (medium)', cal: 103, protein: 2, carbs: 24, fat: 0 },
  { name: 'Steak (8oz)', cal: 450, protein: 50, carbs: 0, fat: 28 },
  { name: 'Avocado (whole)', cal: 322, protein: 4, carbs: 17, fat: 29 },
  { name: 'Broccoli (2 cups)', cal: 60, protein: 4, carbs: 12, fat: 0 },
  { name: 'Whole Milk (1 cup)', cal: 150, protein: 8, carbs: 12, fat: 8 },
  { name: 'Peanut Butter (2 tbsp)', cal: 190, protein: 8, carbs: 6, fat: 16 },
  { name: 'Turkey Sandwich', cal: 350, protein: 24, carbs: 35, fat: 12 },
  { name: 'Protein Bar', cal: 250, protein: 20, carbs: 30, fat: 8 },
  { name: 'Mixed Nuts (1/4 cup)', cal: 210, protein: 6, carbs: 8, fat: 18 },
  { name: 'Apple', cal: 95, protein: 0, carbs: 25, fat: 0 },
  { name: 'Tuna (1 can)', cal: 200, protein: 40, carbs: 0, fat: 2 }
];

// ===== Exercise Library =====
const ExerciseLibrary = [
  { name: 'Bench Press', muscle: 'chest', category: 'barbell' },
  { name: 'Incline Bench Press', muscle: 'chest', category: 'barbell' },
  { name: 'Dumbbell Bench Press', muscle: 'chest', category: 'dumbbell' },
  { name: 'Cable Fly', muscle: 'chest', category: 'cable' },
  { name: 'Push Ups', muscle: 'chest', category: 'bodyweight' },
  { name: 'Barbell Row', muscle: 'back', category: 'barbell' },
  { name: 'Deadlift', muscle: 'back', category: 'barbell' },
  { name: 'Pull Ups', muscle: 'back', category: 'bodyweight' },
  { name: 'Lat Pulldown', muscle: 'back', category: 'cable' },
  { name: 'Seated Cable Row', muscle: 'back', category: 'cable' },
  { name: 'Dumbbell Row', muscle: 'back', category: 'dumbbell' },
  { name: 'Face Pulls', muscle: 'back', category: 'cable' },
  { name: 'Squat', muscle: 'legs', category: 'barbell' },
  { name: 'Front Squat', muscle: 'legs', category: 'barbell' },
  { name: 'Leg Press', muscle: 'legs', category: 'machine' },
  { name: 'Romanian Deadlift', muscle: 'legs', category: 'barbell' },
  { name: 'Leg Extension', muscle: 'legs', category: 'machine' },
  { name: 'Leg Curl', muscle: 'legs', category: 'machine' },
  { name: 'Bulgarian Split Squat', muscle: 'legs', category: 'dumbbell' },
  { name: 'Hip Thrust', muscle: 'legs', category: 'barbell' },
  { name: 'Calf Raises', muscle: 'legs', category: 'machine' },
  { name: 'Overhead Press', muscle: 'shoulders', category: 'barbell' },
  { name: 'Lateral Raise', muscle: 'shoulders', category: 'dumbbell' },
  { name: 'Rear Delt Fly', muscle: 'shoulders', category: 'dumbbell' },
  { name: 'Barbell Curl', muscle: 'arms', category: 'barbell' },
  { name: 'Dumbbell Curl', muscle: 'arms', category: 'dumbbell' },
  { name: 'Hammer Curl', muscle: 'arms', category: 'dumbbell' },
  { name: 'Tricep Pushdown', muscle: 'arms', category: 'cable' },
  { name: 'Skull Crushers', muscle: 'arms', category: 'barbell' },
  { name: 'Plank', muscle: 'core', category: 'bodyweight' },
  { name: 'Hanging Leg Raise', muscle: 'core', category: 'bodyweight' },
  { name: 'Cable Crunch', muscle: 'core', category: 'cable' },
  { name: 'Ab Wheel Rollout', muscle: 'core', category: 'bodyweight' }
];
