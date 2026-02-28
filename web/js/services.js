// ===== Recovery Engine =====
const RecoveryEngine = {
  async calculateRecoveryScore(data, baselines) {
    let score = 0, totalWeight = 0;

    // 1. HRV (30%)
    if (data.hrv != null) {
      const w = 0.30;
      const ratio = data.hrv / Math.max(baselines.hrvBaseline, 1);
      const s = Math.min(Math.max(ratio * 50 + 25, 0), 100);
      score += s * w;
      totalWeight += w;
    }

    // 2. Resting HR (20%)
    if (data.rhr != null) {
      const w = 0.20;
      const ratio = baselines.rhrBaseline / Math.max(data.rhr, 1);
      const s = Math.min(Math.max(ratio * 50 + 25, 0), 100);
      score += s * w;
      totalWeight += w;
    }

    // 3. Respiratory Rate (10%)
    if (data.respiratoryRate != null) {
      const w = 0.10;
      const dev = Math.abs(data.respiratoryRate - baselines.respRateBaseline) / baselines.respRateBaseline;
      const s = Math.max(100 - dev * 200, 0);
      score += s * w;
      totalWeight += w;
    }

    // 4. Blood Oxygen (10%)
    if (data.bloodOxygen != null) {
      const w = 0.10;
      let s;
      if (data.bloodOxygen >= 98) s = 100;
      else if (data.bloodOxygen >= 96) s = 80;
      else if (data.bloodOxygen >= 94) s = 60;
      else if (data.bloodOxygen >= 92) s = 40;
      else s = 20;
      score += s * w;
      totalWeight += w;
    }

    // 5. Sleep (25%)
    const sleepW = 0.25;
    const sleepS = this.calculateSleepScore(data.sleepMinutes || 0, data.deepSleepMinutes || 0, data.remSleepMinutes || 0);
    score += sleepS * sleepW;
    totalWeight += sleepW;

    // 6. Wrist Temp (5%)
    if (data.wristTemp != null) {
      const w = 0.05;
      const dev = Math.abs(data.wristTemp - baselines.tempBaseline);
      let s;
      if (dev < 0.2) s = 100;
      else if (dev < 0.5) s = 75;
      else if (dev < 1.0) s = 50;
      else s = 25;
      score += s * w;
      totalWeight += w;
    }

    if (totalWeight > 0) score = score / totalWeight;
    else score = 50;

    // Strain penalty
    const penalty = Math.max(0, ((data.previousDayStrain || 0) - 60) * 0.3);
    score = Math.max(0, Math.min(100, score - penalty));

    return Math.round(score * 10) / 10;
  },

  calculateSleepScore(totalMin, deepMin, remMin) {
    let score = 0;

    // Duration (60%)
    let durScore;
    if (totalMin >= 420 && totalMin <= 540) durScore = 100;
    else if (totalMin >= 360) durScore = 80;
    else if (totalMin >= 300) durScore = 60;
    else if (totalMin >= 240) durScore = 40;
    else durScore = Math.max(totalMin / 420 * 40, 0);
    score += durScore * 0.6;

    // Deep (25%)
    const deepTarget = totalMin * 0.175;
    const deepRatio = totalMin > 0 ? deepMin / deepTarget : 0;
    score += Math.min(deepRatio * 100, 100) * 0.25;

    // REM (15%)
    const remTarget = totalMin * 0.225;
    const remRatio = totalMin > 0 ? remMin / remTarget : 0;
    score += Math.min(remRatio * 100, 100) * 0.15;

    return Math.min(score, 100);
  },

  calculateActivityStrain(durationMinutes, avgHR, maxHR, maxHeartRate, activityType) {
    const durationHours = durationMinutes / 60;
    let strain = 0;

    if (avgHR) {
      const pct = avgHR / maxHeartRate;
      let factor;
      if (pct < 0.5) factor = 12;
      else if (pct < 0.6) factor = 33;
      else if (pct < 0.7) factor = 67;
      else if (pct < 0.8) factor = 124;
      else if (pct < 0.9) factor = 205;
      else factor = 319;

      strain = durationHours * factor;

      if (maxHR) {
        const maxPct = maxHR / maxHeartRate;
        if (maxPct > 0.9) strain += 7;
        if (maxPct > 0.95) strain += 5;
      }
    } else {
      const factors = {
        'rowing_hard': 180, 'interval': 180, '2k': 180, 'test': 180,
        'rowing_moderate': 114, 'threshold': 114,
        'steady_state': 67, 'rowing_easy': 67,
        'gym_heavy': 124, 'gym_moderate': 90,
        'walking': 33, 'recovery': 24
      };
      strain = durationHours * (factors[activityType] || 67);
    }

    return Math.min(strain, 100);
  },

  calculateGymStrain(totalVolume, sets, durationMinutes, avgHR, maxHeartRate) {
    const durationHours = durationMinutes / 60;
    const volumeStrain = Math.log10(Math.max(totalVolume, 1)) * 18;
    const durationStrain = durationHours * 57;
    const setStrain = sets * 3.3;
    let strain = volumeStrain + durationStrain + setStrain;

    if (avgHR) {
      const pct = avgHR / maxHeartRate;
      strain *= (0.5 + pct);
    }

    return Math.min(strain, 100);
  },

  calculateBaselineEnergy(recoveryScore, sleepScore) {
    return Math.min(recoveryScore * 0.7 + sleepScore * 0.3, 100);
  },

  calculateEnergyDrain(strain, durationMinutes, currentEnergy, activityType) {
    let drain = strain * 0.6;
    const durationFactor = 1.0 + (durationMinutes / 120) * 0.3;
    drain *= durationFactor;

    const mods = { '2k': 1.3, 'test': 1.3, 'interval': 1.3, 'gym_heavy': 1.1, 'steady_state': 0.8, 'recovery': 0.5, 'walking': 0.5 };
    if (mods[activityType]) drain *= mods[activityType];

    if (currentEnergy < 30) drain *= 1.2;

    return Math.min(drain, currentEnergy);
  },

  updateBaselines(baselines, data) {
    const alpha = baselines.sampleCount < 14 ? 0.3 : 0.1;
    baselines.sampleCount++;
    if (data.hrv != null) baselines.hrvBaseline = baselines.hrvBaseline * (1 - alpha) + data.hrv * alpha;
    if (data.rhr != null) baselines.rhrBaseline = baselines.rhrBaseline * (1 - alpha) + data.rhr * alpha;
    if (data.respiratoryRate != null) baselines.respRateBaseline = baselines.respRateBaseline * (1 - alpha) + data.respiratoryRate * alpha;
    if (data.bloodOxygen != null) baselines.spo2Baseline = baselines.spo2Baseline * (1 - alpha) + data.bloodOxygen * alpha;
    if (data.sleepMinutes != null) baselines.sleepBaseline = baselines.sleepBaseline * (1 - alpha) + data.sleepMinutes * alpha;
    if (data.wristTemp != null) baselines.tempBaseline = baselines.tempBaseline * (1 - alpha) + data.wristTemp * alpha;
    return baselines;
  }
};

// ===== AI Coach =====
const AICoach = {
  generateRecommendation(profile, scores, todayStatus) {
    if (!profile) return null;

    const recovery = todayStatus?.recoveryScore ?? 50;
    const strain = todayStatus?.strainScore ?? 0;
    const energy = todayStatus?.energyLevel ?? 70;
    const sleepScore = todayStatus?.sleepScore ?? 50;

    // Recovery-based logic
    if (recovery < 33) {
      return {
        category: 'recovery',
        title: 'Rest Day Recommended',
        message: `Your recovery is at ${Math.round(recovery)}%. Your body needs time to repair. Take a rest day or do very light activity only — a 20-minute easy walk or gentle stretching. Focus on hydration and nutrition.`,
        icon: '😴',
        color: 'red'
      };
    }

    if (recovery < 50) {
      return {
        category: 'recovery',
        title: 'Easy Day — Active Recovery',
        message: `Recovery at ${Math.round(recovery)}%. Keep it light today — a 30-40 min steady state row at rate 18-20, or easy mobility work. Stay below zone 2.`,
        suggestedWorkout: { type: 'steady_state', duration: 35, split: '2:10', strokeRate: 18, intensity: 'Easy' },
        icon: '🚣',
        color: 'green'
      };
    }

    if (energy < 30) {
      return {
        category: 'warning',
        title: 'Energy Depleted',
        message: `Energy is at ${Math.round(energy)}%. Even though recovery is decent, you've already done a lot today. Rest up and recharge for tomorrow.`,
        icon: '🔋',
        color: 'orange'
      };
    }

    // Check recent scores for progress
    const recent2ks = scores.filter(s => s.workoutType === '2k').slice(0, 3);

    if (recovery >= 80 && energy >= 70) {
      // High recovery = good day for hard work
      if (profile.totalWorkouts % 7 === 0 && profile.totalWorkouts > 0) {
        return {
          category: 'milestone',
          title: 'Test Piece Day',
          message: `Recovery is ${Math.round(recovery)}% — excellent! Great day for a 2K test or hard intervals. Your body is primed for peak performance.`,
          suggestedWorkout: { type: '2k', duration: 10, split: profile.pr2k ? formatSplit(profile.pr2k) : '1:50', strokeRate: 30, intensity: 'Max' },
          icon: '🏆',
          color: 'yellow'
        };
      }

      return {
        category: 'workout',
        title: 'Hard Interval Day',
        message: `Recovery at ${Math.round(recovery)}% with good energy. Push hard today — 8x500m intervals with 2 min rest, or a 6K at threshold pace.`,
        suggestedWorkout: { type: 'interval', duration: 45, split: '1:45', strokeRate: 28, intensity: 'Hard' },
        icon: '💪',
        color: 'blue'
      };
    }

    if (recovery >= 50) {
      return {
        category: 'workout',
        title: 'Moderate Steady State',
        message: `Recovery at ${Math.round(recovery)}%. Good day for a solid 45-60 minute steady state piece. Focus on technique and consistent splits.`,
        suggestedWorkout: { type: 'steady_state', duration: 50, split: '2:05', strokeRate: 20, intensity: 'Moderate' },
        icon: '🚣',
        color: 'blue'
      };
    }

    return {
      category: 'workout',
      title: 'Light Training Day',
      message: 'Moderate recovery. Keep the intensity down — easy steady state or technique work.',
      suggestedWorkout: { type: 'steady_state', duration: 30, split: '2:10', strokeRate: 18, intensity: 'Easy' },
      icon: '🚣',
      color: 'green'
    };
  },

  generateWeeklyPlan(profile, todayStatus) {
    if (!profile) return [];

    const recovery = todayStatus?.recoveryScore ?? 60;
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const today = new Date().getDay();
    const plan = [];

    // Polarized model: 80% easy, 20% hard
    const template = [
      { day: 'Monday', type: 'Steady State', intensity: 'Easy', duration: 50, sr: 18 },
      { day: 'Tuesday', type: 'Intervals', intensity: 'Hard', duration: 40, sr: 28 },
      { day: 'Wednesday', type: 'Steady State', intensity: 'Easy', duration: 60, sr: 20 },
      { day: 'Thursday', type: 'Gym + Easy Row', intensity: 'Moderate', duration: 45, sr: 18 },
      { day: 'Friday', type: 'Steady State', intensity: 'Easy', duration: 50, sr: 20 },
      { day: 'Saturday', type: 'Hard Pieces', intensity: 'Hard', duration: 35, sr: 30 },
      { day: 'Sunday', type: 'Rest / Light', intensity: 'Recovery', duration: 0, sr: 0 }
    ];

    // Adjust based on recovery
    for (const t of template) {
      if (recovery < 40 && t.intensity === 'Hard') {
        t.type = 'Easy Steady State';
        t.intensity = 'Easy';
        t.sr = 18;
      }
      plan.push(t);
    }

    return plan;
  }
};

// ===== Utility Functions =====
function formatSplit(seconds) {
  if (!seconds) return '--';
  const min = Math.floor(seconds / 60);
  const sec = seconds - min * 60;
  return `${min}:${sec < 10 ? '0' : ''}${sec.toFixed(1)}`;
}

function formatDuration(minutes) {
  const h = Math.floor(minutes / 60);
  const m = minutes % 60;
  if (h > 0) return `${h}h ${m}m`;
  return `${m}m`;
}

function formatDate(dateStr) {
  const d = new Date(dateStr);
  return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
}

function formatTime(dateStr) {
  const d = new Date(dateStr);
  return d.toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' });
}

function recoveryColor(score) {
  if (score >= 67) return 'var(--green)';
  if (score >= 34) return 'var(--yellow)';
  return 'var(--red)';
}

function recoveryCategory(score) {
  if (score >= 67) return 'Green';
  if (score >= 34) return 'Yellow';
  return 'Red';
}

function strainColor(strain) {
  if (strain < 25) return 'var(--blue)';
  if (strain < 50) return 'var(--green)';
  if (strain < 75) return 'var(--orange)';
  return 'var(--red)';
}

function strainCategory(strain) {
  if (strain < 25) return 'Light';
  if (strain < 50) return 'Moderate';
  if (strain < 75) return 'High';
  return 'Overload';
}

function energyColor(energy) {
  if (energy >= 70) return 'var(--green)';
  if (energy >= 40) return 'var(--yellow)';
  if (energy >= 20) return 'var(--orange)';
  return 'var(--red)';
}

function energyCategory(energy) {
  if (energy >= 70) return 'High';
  if (energy >= 40) return 'Moderate';
  if (energy >= 20) return 'Low';
  return 'Depleted';
}

function ringSVG(size, strokeWidth, progress, color, bgOpacity = 0.15) {
  const r = (size - strokeWidth) / 2;
  const c = Math.PI * 2 * r;
  const offset = c * (1 - Math.min(Math.max(progress, 0), 1));
  return `<svg width="${size}" height="${size}" viewBox="0 0 ${size} ${size}">
    <circle cx="${size/2}" cy="${size/2}" r="${r}" fill="none" stroke="${color}" stroke-opacity="${bgOpacity}" stroke-width="${strokeWidth}"/>
    <circle cx="${size/2}" cy="${size/2}" r="${r}" fill="none" stroke="${color}" stroke-width="${strokeWidth}" stroke-linecap="round"
      stroke-dasharray="${c}" stroke-dashoffset="${offset}" style="transition:stroke-dashoffset 0.8s ease"/>
  </svg>`;
}

function gaugeArcSVG(size, strokeWidth, progress, color) {
  const r = (size - strokeWidth) / 2;
  const startAngle = 135;
  const sweepAngle = 270;
  const endAngle = startAngle + sweepAngle * Math.min(Math.max(progress, 0), 1);

  function polarToCartesian(cx, cy, r, angleDeg) {
    const rad = (angleDeg - 90) * Math.PI / 180;
    return { x: cx + r * Math.cos(rad), y: cy + r * Math.sin(rad) };
  }

  const cx = size / 2, cy = size / 2;

  // Background arc
  const bgStart = polarToCartesian(cx, cy, r, startAngle);
  const bgEnd = polarToCartesian(cx, cy, r, startAngle + sweepAngle);
  const bgLargeArc = sweepAngle > 180 ? 1 : 0;
  const bgPath = `M ${bgStart.x} ${bgStart.y} A ${r} ${r} 0 ${bgLargeArc} 1 ${bgEnd.x} ${bgEnd.y}`;

  // Value arc
  const valEnd = polarToCartesian(cx, cy, r, endAngle);
  const valSweep = sweepAngle * Math.min(Math.max(progress, 0), 1);
  const valLargeArc = valSweep > 180 ? 1 : 0;
  const valPath = `M ${bgStart.x} ${bgStart.y} A ${r} ${r} 0 ${valLargeArc} 1 ${valEnd.x} ${valEnd.y}`;

  return `<svg width="${size}" height="${size}" viewBox="0 0 ${size} ${size}">
    <path d="${bgPath}" fill="none" stroke="${color}" stroke-opacity="0.15" stroke-width="${strokeWidth}" stroke-linecap="round"/>
    <path d="${valPath}" fill="none" stroke="${color}" stroke-width="${strokeWidth}" stroke-linecap="round"
      style="transition:d 0.8s ease"/>
  </svg>`;
}
