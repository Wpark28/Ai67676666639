// ===== Main Application Controller =====

const App = {
  currentTab: 'dashboard',
  currentSubView: null,
  viewStack: [],
  activeGymSession: null,
  waterCount: 0,
  cameraStream: null,

  async init() {
    await Store.init();

    // Register Service Worker
    if ('serviceWorker' in navigator) {
      navigator.serviceWorker.register('/sw.js').catch(() => {});
    }

    // Tab bar events
    document.querySelectorAll('#tab-bar .tab').forEach(btn => {
      btn.addEventListener('click', () => {
        const tab = btn.dataset.tab;
        if (tab === 'capture') {
          this.navigate('capture');
        } else {
          this.switchTab(tab);
        }
      });
    });

    // Check if profile exists
    const profile = await Store.getProfile();
    if (!profile) {
      this.navigate('profile');
    } else {
      this.switchTab('dashboard');
    }

    // Bluetooth HR live update
    BluetoothHR.onUpdate = (hr) => {
      if (this.currentTab === 'hr' || this.currentSubView === 'hr') {
        this.render();
      }
    };

    BluetoothHR.onDisconnect = () => {
      if (this.currentTab === 'hr' || this.currentSubView === 'hr') {
        this.render();
      }
    };
  },

  switchTab(tab) {
    this.currentTab = tab;
    this.currentSubView = null;
    this.viewStack = [];

    // Update tab bar
    document.querySelectorAll('#tab-bar .tab').forEach(btn => {
      btn.classList.toggle('active', btn.dataset.tab === tab);
    });

    // Update nav
    const titles = { dashboard: 'ErgAI', body: 'Body Status', capture: 'Capture', coach: 'AI Coach', more: 'More' };
    document.getElementById('nav-title').textContent = titles[tab] || 'ErgAI';
    this.hideBackButton();

    this.render();
  },

  navigate(view) {
    this.currentSubView = view;
    this.viewStack.push(view);

    const titles = {
      hr: 'Heart Rate', gym: 'Gym Tracker', history: 'Erg History',
      calories: 'Nutrition', profile: 'Profile', simulate: 'Simulate Data',
      capture: 'Capture'
    };

    document.getElementById('nav-title').textContent = titles[view] || 'ErgAI';
    this.showBackButton();
    this.render();
  },

  goBack() {
    this.viewStack.pop();
    if (this.viewStack.length > 0) {
      this.currentSubView = this.viewStack[this.viewStack.length - 1];
      this.render();
    } else {
      this.currentSubView = null;
      this.switchTab(this.currentTab);
    }
  },

  showBackButton() {
    const nav = document.getElementById('nav-bar');
    let backBtn = nav.querySelector('.nav-back');
    if (!backBtn) {
      backBtn = document.createElement('button');
      backBtn.className = 'nav-back';
      backBtn.innerHTML = '&#8249; Back';
      backBtn.onclick = () => this.goBack();
      nav.appendChild(backBtn);
    }
    backBtn.style.display = 'flex';
  },

  hideBackButton() {
    const backBtn = document.querySelector('.nav-back');
    if (backBtn) backBtn.style.display = 'none';
  },

  async render() {
    const content = document.getElementById('content');
    let html = '';

    try {
      if (this.currentSubView) {
        switch (this.currentSubView) {
          case 'hr': html = Views.hrMonitor(); break;
          case 'gym': html = await Views.gym(); break;
          case 'history': html = await Views.history(); break;
          case 'calories': html = await Views.calories(); break;
          case 'profile': html = await Views.profile(); break;
          case 'simulate': html = Views.simulate(); break;
          case 'capture': html = Views.capture(); break;
          default: html = await Views.dashboard();
        }
      } else {
        switch (this.currentTab) {
          case 'dashboard': html = await Views.dashboard(); break;
          case 'body': html = await Views.body(); break;
          case 'coach': html = await Views.coach(); break;
          case 'more': html = Views.more(); break;
          default: html = await Views.dashboard();
        }
      }
    } catch (e) {
      console.error('Render error:', e);
      html = `<div class="empty-state"><div class="empty-icon">&#9888;</div><div class="empty-title">Error</div><div class="empty-subtitle">${e.message}</div></div>`;
    }

    content.innerHTML = html;
    content.scrollTop = 0;
  },

  // Body sub-tab
  async renderBody(subTab) {
    const content = document.getElementById('content');
    content.innerHTML = await Views.body(subTab);
  },

  // Coach sub-tab
  async renderCoach(subTab) {
    const content = document.getElementById('content');
    content.innerHTML = await Views.coach(subTab);
  },

  // ===== Score Management =====

  parseSplitToSeconds(splitStr) {
    if (!splitStr) return null;
    const parts = splitStr.split(':');
    if (parts.length !== 2) return null;
    return parseInt(parts[0]) * 60 + parseFloat(parts[1]);
  },

  async saveScore() {
    const type = document.getElementById('score-type').value;
    const timeStr = document.getElementById('score-time').value;
    const distance = parseInt(document.getElementById('score-distance').value) || null;
    const splitStr = document.getElementById('score-split').value;
    const sr = parseInt(document.getElementById('score-sr').value) || null;
    const hr = parseInt(document.getElementById('score-hr').value) || null;
    const cal = parseInt(document.getElementById('score-cal').value) || null;

    const splitSeconds = this.parseSplitToSeconds(splitStr);
    if (!splitSeconds && !timeStr && !distance) {
      alert('Please enter at least a split, time, or distance.');
      return;
    }

    const score = {
      workoutType: type,
      timeStr: timeStr || null,
      distance: distance,
      splitSeconds: splitSeconds,
      strokeRate: sr,
      avgHR: hr,
      calories: cal,
      capturedFromPhoto: false,
      date: new Date().toISOString()
    };

    await Store.addScore(score);

    // Update profile
    const profile = await Store.getProfile();
    if (profile) {
      profile.totalWorkouts = (profile.totalWorkouts || 0) + 1;
      if (distance) profile.totalLifetimeMeters = (profile.totalLifetimeMeters || 0) + distance;
      profile.currentWeekSessions = (profile.currentWeekSessions || 0) + 1;
      if (distance) profile.currentWeekMeters = (profile.currentWeekMeters || 0) + distance;

      // Update PR
      if (type === '2k' && splitSeconds && (!profile.pr2k || splitSeconds < profile.pr2k)) {
        profile.pr2k = splitSeconds;
      }
      if (type === '5k' && splitSeconds && (!profile.pr5k || splitSeconds < profile.pr5k)) {
        profile.pr5k = splitSeconds;
      }

      await Store.saveProfile(profile);
    }

    alert('Score saved!');
    this.switchTab('dashboard');
  },

  // ===== Camera =====

  async startCamera() {
    try {
      const video = document.getElementById('camera-video');
      this.cameraStream = await navigator.mediaDevices.getUserMedia({
        video: { facingMode: 'environment' }
      });
      video.srcObject = this.cameraStream;
      video.style.display = 'block';

      const btn = document.getElementById('btn-camera');
      btn.textContent = '📷 Capture';
      btn.onclick = () => this.capturePhoto();
    } catch (e) {
      alert('Camera access denied or not available. Use the upload button or manual entry instead.');
    }
  },

  capturePhoto() {
    const video = document.getElementById('camera-video');
    const canvas = document.getElementById('camera-canvas');
    const img = document.getElementById('captured-img');

    canvas.width = video.videoWidth;
    canvas.height = video.videoHeight;
    canvas.getContext('2d').drawImage(video, 0, 0);

    const dataUrl = canvas.toDataURL('image/jpeg');
    img.src = dataUrl;
    img.style.display = 'block';
    video.style.display = 'none';

    // Stop camera
    if (this.cameraStream) {
      this.cameraStream.getTracks().forEach(t => t.stop());
      this.cameraStream = null;
    }

    // Show result area with message
    document.getElementById('capture-result').style.display = 'block';
    document.getElementById('ocr-result').innerHTML = `
      <div class="text-sm color-secondary">Photo captured. In-browser OCR is limited — please verify and enter values manually below, or use a native app for automatic OCR.</div>
    `;
  },

  uploadPhoto() {
    const input = document.getElementById('photo-upload');
    input.onchange = (e) => {
      const file = e.target.files[0];
      if (!file) return;
      const reader = new FileReader();
      reader.onload = (ev) => {
        const img = document.getElementById('captured-img');
        img.src = ev.target.result;
        img.style.display = 'block';
        document.getElementById('capture-result').style.display = 'block';
        document.getElementById('ocr-result').innerHTML = `
          <div class="text-sm color-secondary">Photo uploaded. Enter the values you see on the erg screen into the fields below.</div>
        `;
      };
      reader.readAsDataURL(file);
    };
    input.click();
  },

  // ===== Profile =====

  async saveProfile() {
    const profile = (await Store.getProfile()) || createDefaultProfile();

    profile.name = document.getElementById('prof-name').value;
    profile.age = parseInt(document.getElementById('prof-age').value) || 20;
    profile.weight = parseInt(document.getElementById('prof-weight').value) || 80;
    profile.height = parseInt(document.getElementById('prof-height').value) || 180;
    profile.gender = document.getElementById('prof-gender').value;
    profile.maxHR = parseInt(document.getElementById('prof-maxhr').value) || 195;
    profile.restingHR = parseInt(document.getElementById('prof-resthr').value) || 60;
    profile.calorieTarget = parseInt(document.getElementById('prof-cal').value) || 2500;
    profile.proteinTarget = parseInt(document.getElementById('prof-protein').value) || 150;
    profile.carbTarget = parseInt(document.getElementById('prof-carbs').value) || 300;
    profile.fatTarget = parseInt(document.getElementById('prof-fat').value) || 80;

    const pr2k = document.getElementById('prof-2k').value;
    if (pr2k) profile.pr2k = this.parseSplitToSeconds(pr2k);
    const pr5k = document.getElementById('prof-5k').value;
    if (pr5k) profile.pr5k = this.parseSplitToSeconds(pr5k);

    await Store.saveProfile(profile);
    alert('Profile saved!');
    this.switchTab('dashboard');
  },

  // ===== Bluetooth HR =====

  async scanHR() {
    try {
      const device = await BluetoothHR.scan();
      if (device) {
        await BluetoothHR.connect();
        this.render();
      }
    } catch (e) {
      alert(e.message);
    }
  },

  disconnectHR() {
    BluetoothHR.disconnect();
    this.render();
  },

  // ===== Gym =====

  startGymSession() {
    const name = prompt('Session name (e.g., Push Day, Pull Day):', 'Push Day');
    if (!name) return;

    this.activeGymSession = {
      sessionName: name,
      sessionType: 'custom',
      exercises: [],
      totalVolume: 0,
      totalSets: 0,
      durationMinutes: 0,
      strainScore: 0,
      startTime: new Date().toISOString(),
      date: new Date().toISOString()
    };

    this.render();
  },

  addExercise() {
    if (!this.activeGymSession) return;

    // Show exercise picker
    const names = ExerciseLibrary.map(e => e.name);
    const name = prompt('Exercise name:\n\nSuggestions: ' + names.slice(0, 10).join(', ') + '...');
    if (!name) return;

    const lib = ExerciseLibrary.find(e => e.name.toLowerCase() === name.toLowerCase());
    this.activeGymSession.exercises.push({
      name: name,
      muscleGroup: lib?.muscle || 'other',
      category: lib?.category || 'barbell',
      sets: []
    });

    this.render();
  },

  addSet(exerciseIdx) {
    if (!this.activeGymSession) return;
    const ex = this.activeGymSession.exercises[exerciseIdx];
    if (!ex) return;

    const lastSet = ex.sets[ex.sets.length - 1];
    const weight = prompt('Weight (kg):', lastSet?.weightKg || '60');
    if (!weight) return;
    const reps = prompt('Reps:', lastSet?.reps || '10');
    if (!reps) return;
    const rpe = prompt('RPE (1-10, optional):', '');

    ex.sets.push({
      weightKg: parseFloat(weight),
      reps: parseInt(reps),
      rpe: rpe ? parseFloat(rpe) : null,
      isWarmup: false
    });

    this.render();
  },

  async finishGymSession() {
    if (!this.activeGymSession) return;

    const session = this.activeGymSession;
    session.endTime = new Date().toISOString();
    session.durationMinutes = Math.round((new Date(session.endTime) - new Date(session.startTime)) / 60000);

    // Calculate totals
    let totalVol = 0, totalSets = 0;
    for (const ex of session.exercises) {
      for (const s of ex.sets) {
        if (!s.isWarmup) {
          totalVol += s.weightKg * s.reps;
          totalSets++;
        }
      }
    }
    session.totalVolume = totalVol;
    session.totalSets = totalSets;

    // Calculate strain
    const profile = await Store.getProfile();
    const maxHR = profile?.maxHR || 195;
    session.strainScore = RecoveryEngine.calculateGymStrain(totalVol, totalSets, session.durationMinutes, null, maxHR);

    await Store.saveGymSession(session);
    this.activeGymSession = null;

    alert(`Session saved! Volume: ${totalVol >= 1000 ? (totalVol/1000).toFixed(1) + 'k' : Math.round(totalVol)} kg, Strain: ${session.strainScore.toFixed(1)}`);
    this.render();
  },

  // ===== Calories =====

  async addFood(food) {
    await Store.addCalorieEntry({
      name: food.name,
      calories: food.cal,
      protein: food.protein,
      carbs: food.carbs,
      fat: food.fat,
      date: new Date().toISOString()
    });
    this.render();
  },

  filterFoods(query) {
    const list = document.getElementById('food-list');
    const filtered = query
      ? FoodLibrary.filter(f => f.name.toLowerCase().includes(query.toLowerCase()))
      : FoodLibrary.slice(0, 8);

    list.innerHTML = filtered.map(f =>
      `<div class="food-item" onclick="App.addFood(${JSON.stringify(f).replace(/"/g, '&quot;')})">
        <div><div class="food-name">${f.name}</div><div class="food-macros">P:${f.protein}g C:${f.carbs}g F:${f.fat}g</div></div>
        <div class="food-cal">${f.cal} cal</div>
      </div>`
    ).join('');
  },

  setWater(count) {
    this.waterCount = count;
    this.render();
  },

  // ===== Sample Data Generation =====

  async generateSampleData() {
    // Profile
    const profile = createDefaultProfile();
    profile.name = 'Alex';
    profile.age = 22;
    profile.weight = 82;
    profile.height = 185;
    profile.maxHR = 195;
    profile.restingHR = 55;
    profile.pr2k = 105; // 1:45.0
    profile.pr5k = 115; // 1:55.0
    profile.totalWorkouts = 47;
    profile.totalLifetimeMeters = 892000;
    profile.currentWeekSessions = 4;
    profile.currentWeekMeters = 38000;
    profile.streakDays = 12;
    profile.fitnessScore = 72;
    profile.fatigueScore = 35;
    profile.formScore = 37;
    await Store.saveProfile(profile);

    // Erg Scores
    const scores = [
      { workoutType: '2k', splitSeconds: 105, distance: 2000, strokeRate: 30, avgHR: 182, date: new Date(Date.now() - 86400000 * 2).toISOString() },
      { workoutType: '5k', splitSeconds: 115.5, distance: 5000, strokeRate: 24, avgHR: 168, date: new Date(Date.now() - 86400000 * 4).toISOString() },
      { workoutType: 'steady_state', splitSeconds: 125, distance: 10000, strokeRate: 20, avgHR: 148, date: new Date(Date.now() - 86400000 * 5).toISOString() },
      { workoutType: '2k', splitSeconds: 106.5, distance: 2000, strokeRate: 29, avgHR: 180, date: new Date(Date.now() - 86400000 * 10).toISOString() },
      { workoutType: 'interval', splitSeconds: 100, distance: 4000, strokeRate: 28, avgHR: 175, date: new Date(Date.now() - 86400000 * 7).toISOString() },
    ];
    for (const s of scores) await Store.addScore(s);

    // Daily Statuses (7 days)
    for (let i = 0; i < 7; i++) {
      const date = new Date(Date.now() - 86400000 * i);
      const recovery = 40 + Math.random() * 50;
      const sleepMin = 350 + Math.floor(Math.random() * 150);
      const sleepScore = RecoveryEngine.calculateSleepScore(sleepMin, Math.floor(sleepMin * 0.17), Math.floor(sleepMin * 0.22));
      const strain = 10 + Math.random() * 60;
      const baseline = RecoveryEngine.calculateBaselineEnergy(recovery, sleepScore);

      const status = {
        date: date.toISOString(),
        recoveryScore: Math.round(recovery * 10) / 10,
        sleepScore: Math.round(sleepScore * 10) / 10,
        strainScore: Math.round(strain * 10) / 10,
        energyBaseline: Math.round(baseline),
        energyLevel: Math.round(baseline - strain * 0.3),
        totalSleepMinutes: sleepMin,
        deepSleepMinutes: Math.floor(sleepMin * 0.17),
        remSleepMinutes: Math.floor(sleepMin * 0.22),
        lightSleepMinutes: Math.floor(sleepMin * 0.5),
        awakeMinutes: Math.floor(sleepMin * 0.05),
        hrv: 40 + Math.random() * 40,
        rhr: 50 + Math.random() * 15,
        bloodOxygen: 95 + Math.random() * 4,
        respiratoryRate: 13 + Math.random() * 4,
        wristTemp: -0.3 + Math.random() * 0.6,
        steps: 5000 + Math.floor(Math.random() * 8000),
        activeCalories: 200 + Math.floor(Math.random() * 500),
        activeMinutes: 20 + Math.floor(Math.random() * 60),
        energyDrains: i === 0 ? [
          { source: 'Morning Row (SS)', durationMinutes: 50, amount: 18, time: new Date(date.getTime() + 28800000).toISOString() },
          { source: 'Gym Session', durationMinutes: 60, amount: 22, time: new Date(date.getTime() + 54000000).toISOString() }
        ] : []
      };

      await Store.saveDailyStatus(status);
    }

    // Gym session
    const gymSession = {
      sessionName: 'Push Day',
      sessionType: 'push',
      exercises: [
        { name: 'Bench Press', muscleGroup: 'chest', category: 'barbell', sets: [
          { weightKg: 80, reps: 8, rpe: 7, isWarmup: false },
          { weightKg: 85, reps: 6, rpe: 8, isWarmup: false },
          { weightKg: 85, reps: 5, rpe: 9, isWarmup: false }
        ]},
        { name: 'Overhead Press', muscleGroup: 'shoulders', category: 'barbell', sets: [
          { weightKg: 50, reps: 8, rpe: 7, isWarmup: false },
          { weightKg: 50, reps: 7, rpe: 8, isWarmup: false }
        ]},
        { name: 'Lateral Raise', muscleGroup: 'shoulders', category: 'dumbbell', sets: [
          { weightKg: 12, reps: 15, rpe: 8, isWarmup: false },
          { weightKg: 12, reps: 12, rpe: 9, isWarmup: false }
        ]}
      ],
      totalVolume: 80*8 + 85*6 + 85*5 + 50*8 + 50*7 + 12*15 + 12*12,
      totalSets: 7,
      durationMinutes: 55,
      strainScore: 42,
      date: new Date(Date.now() - 86400000).toISOString()
    };
    await Store.saveGymSession(gymSession);

    // Calorie entries
    const foods = [
      { name: 'Oatmeal (1 cup)', calories: 300, protein: 10, carbs: 54, fat: 5 },
      { name: 'Whey Protein Shake', calories: 150, protein: 30, carbs: 3, fat: 2 },
      { name: 'Chicken Breast (6oz)', calories: 280, protein: 53, carbs: 0, fat: 6 },
      { name: 'Brown Rice (1 cup)', calories: 215, protein: 5, carbs: 45, fat: 2 }
    ];
    for (const f of foods) {
      await Store.addCalorieEntry({ ...f, name: f.name, date: new Date().toISOString() });
    }

    alert('Sample data generated! Explore the app to see everything in action.');
    this.switchTab('dashboard');
  },

  async clearAllData() {
    if (!confirm('Delete ALL app data? This cannot be undone.')) return;

    await Store.clear('profile');
    await Store.clear('scores');
    await Store.clear('dailyStatus');
    await Store.clear('gymSessions');
    await Store.clear('calorieEntries');
    await Store.clear('hrSessions');
    await Store.clear('baselines');

    this.activeGymSession = null;
    this.waterCount = 0;

    alert('All data cleared.');
    this.switchTab('dashboard');
  }
};

// ===== Boot =====
document.addEventListener('DOMContentLoaded', () => App.init());
