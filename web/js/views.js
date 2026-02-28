// ===== View Rendering =====
// Each view function returns an HTML string and optionally attaches events after render.

const Views = {

  // =========================================
  // DASHBOARD
  // =========================================
  async dashboard() {
    const profile = await Store.getProfile();
    const scores = await Store.getScores();
    const status = await Store.getTodayStatus();
    const rec = AICoach.generateRecommendation(profile, scores, status);

    let html = '<div class="fade-in">';

    // Header
    html += `<div class="card">
      <div class="flex items-center justify-between">
        <div>
          <div style="font-size:20px;font-weight:700">Hey, ${profile?.name || 'Rower'}</div>
          <div class="text-sm color-secondary">${profile?.currentWeekSessions || 0} sessions this week &middot; ${(profile?.currentWeekMeters || 0).toLocaleString()}m</div>
        </div>
        ${profile?.streakDays > 0 ? `<div class="text-center"><div style="font-size:24px;font-weight:700;color:var(--orange)">${profile.streakDays}</div><div class="text-xxs color-secondary">day streak</div></div>` : ''}
      </div>
    </div>`;

    // Body Status Strip
    if (status) {
      const rc = recoveryColor(status.recoveryScore);
      const sc = status.strainScore < 40 ? 'var(--blue)' : status.strainScore < 70 ? 'var(--orange)' : 'var(--red)';
      const ec = energyColor(status.energyLevel);
      html += `<div class="card">
        <div class="status-strip">
          <div class="status-item">
            <div class="status-icon" style="color:${rc}">&#10084;</div>
            <div class="status-value" style="color:${rc}">${Math.round(status.recoveryScore)}%</div>
            <div class="status-label">Recovery</div>
          </div>
          <div class="status-item">
            <div class="status-icon" style="color:${sc}">&#128293;</div>
            <div class="status-value" style="color:${sc}">${status.strainScore.toFixed(1)}</div>
            <div class="status-label">Strain</div>
          </div>
          <div class="status-item">
            <div class="status-icon" style="color:${ec}">&#9889;</div>
            <div class="status-value" style="color:${ec}">${Math.round(status.energyLevel)}%</div>
            <div class="status-label">Energy</div>
          </div>
          <div class="status-item">
            <div class="status-icon" style="color:var(--indigo)">&#127769;</div>
            <div class="status-value" style="color:var(--indigo)">${formatDuration(status.totalSleepMinutes || 0)}</div>
            <div class="status-label">Sleep</div>
          </div>
        </div>
      </div>`;
    }

    // AI Recommendation
    if (rec) {
      const catColors = { workout: 'var(--blue)', recovery: 'var(--green)', technique: 'var(--purple)', milestone: 'var(--yellow)', warning: 'var(--red)' };
      const c = catColors[rec.category] || 'var(--blue)';
      html += `<div class="card rec-card">
        <div class="rec-header">
          <span class="rec-icon">${rec.icon || '🚣'}</span>
          <span class="rec-title">${rec.title}</span>
          <span class="rec-badge" style="background:${c}22;color:${c}">${rec.category}</span>
        </div>
        <div class="rec-message">${rec.message}</div>
        ${rec.suggestedWorkout ? `<div class="rec-workout">
          <div class="rec-workout-info">
            ${rec.suggestedWorkout.split ? `${rec.suggestedWorkout.split} /500m` : ''}
            ${rec.suggestedWorkout.strokeRate ? `&middot; ${rec.suggestedWorkout.strokeRate} s/m` : ''}
            ${rec.suggestedWorkout.duration ? `&middot; ${rec.suggestedWorkout.duration} min` : ''}
          </div>
        </div>` : ''}
      </div>`;
    } else {
      html += `<div class="card text-center" style="padding:24px">
        <div style="font-size:36px;margin-bottom:8px">🧠</div>
        <div class="font-bold">Get Today's Recommendation</div>
        <div class="text-sm color-secondary mt-8">Set up your profile and log data to get AI coaching</div>
      </div>`;
    }

    // Quick Stats
    html += `<div class="stats-grid">
      <div class="stat-card">
        <div class="stat-icon">🚣</div>
        <div class="stat-value">${(profile?.totalLifetimeMeters || 0).toLocaleString()}</div>
        <div class="stat-label">Total Meters</div>
      </div>
      <div class="stat-card">
        <div class="stat-icon">🔥</div>
        <div class="stat-value">${profile?.totalWorkouts || 0}</div>
        <div class="stat-label">Workouts</div>
      </div>
      <div class="stat-card">
        <div class="stat-icon">🏆</div>
        <div class="stat-value">${profile?.pr2k ? formatSplit(profile.pr2k) : '--'}</div>
        <div class="stat-label">2K PR</div>
      </div>
    </div>`;

    // Recent Scores
    html += `<div class="card" style="margin-top:16px">
      <div class="card-header">
        <span class="card-title">Recent Scores</span>
        <span class="text-sm color-blue" style="cursor:pointer" onclick="App.navigate('history')">See All</span>
      </div>`;

    if (scores.length === 0) {
      html += `<div class="empty-state">
        <div class="empty-icon">📸</div>
        <div class="empty-title">No scores yet</div>
        <div class="empty-subtitle">Capture your erg screen to get started</div>
      </div>`;
    } else {
      for (const s of scores.slice(0, 3)) {
        html += `<div class="score-row">
          <div class="score-info">
            <div class="score-type">${s.workoutType || '2k'}</div>
            <div class="score-split">${formatSplit(s.splitSeconds)} /500m</div>
          </div>
          <div class="score-meta">
            <div class="score-distance">${s.distance ? s.distance.toLocaleString() + 'm' : '--'}</div>
            <div class="score-date">${formatDate(s.date)}</div>
          </div>
        </div>`;
      }
    }
    html += '</div>';

    // Fitness Trends
    if (profile) {
      html += `<div class="card" style="margin-top:16px">
        <div class="card-title mb-8">Fitness & Form</div>
        <div class="trend-bars">
          <div class="trend-bar">
            <div class="trend-value" style="color:var(--blue)">${Math.round(profile.fitnessScore)}</div>
            <div class="trend-fill-container"><div class="trend-fill" style="height:${Math.min(profile.fitnessScore, 100)}%;background:var(--blue)"></div></div>
            <div class="trend-label">Fitness</div>
          </div>
          <div class="trend-bar">
            <div class="trend-value" style="color:var(--red)">${Math.round(profile.fatigueScore)}</div>
            <div class="trend-fill-container"><div class="trend-fill" style="height:${Math.min(profile.fatigueScore, 100)}%;background:var(--red)"></div></div>
            <div class="trend-label">Fatigue</div>
          </div>
          <div class="trend-bar">
            <div class="trend-value" style="color:var(--green)">${Math.round(Math.max(profile.formScore + 50, 0))}</div>
            <div class="trend-fill-container"><div class="trend-fill" style="height:${Math.min(Math.max(profile.formScore + 50, 0), 100)}%;background:var(--green)"></div></div>
            <div class="trend-label">Form</div>
          </div>
        </div>
        <div class="text-xs color-secondary mt-8">Form = Fitness - Fatigue. Higher form = ready to race.</div>
      </div>`;
    }

    html += '</div>';
    return html;
  },

  // =========================================
  // BODY / RECOVERY DASHBOARD
  // =========================================
  async body(subTab = 'recovery') {
    const status = await Store.getTodayStatus();
    const statuses = await Store.getDailyStatuses();

    let html = '<div class="fade-in">';

    // Segmented control
    html += `<div class="segmented">
      <button ${subTab === 'recovery' ? 'class="active"' : ''} onclick="App.renderBody('recovery')">Recovery</button>
      <button ${subTab === 'sleep' ? 'class="active"' : ''} onclick="App.renderBody('sleep')">Sleep</button>
      <button ${subTab === 'strain' ? 'class="active"' : ''} onclick="App.renderBody('strain')">Strain</button>
      <button ${subTab === 'energy' ? 'class="active"' : ''} onclick="App.renderBody('energy')">Energy</button>
    </div>`;

    if (subTab === 'recovery') {
      html += this.recoveryTab(status, statuses);
    } else if (subTab === 'sleep') {
      html += this.sleepTab(status);
    } else if (subTab === 'strain') {
      html += this.strainTab(status);
    } else if (subTab === 'energy') {
      html += this.energyTab(status);
    }

    html += '</div>';
    return html;
  },

  recoveryTab(status, statuses) {
    const score = status?.recoveryScore ?? 0;
    const cat = recoveryCategory(score);
    const color = recoveryColor(score);

    let html = '';

    // Recovery Ring
    html += `<div class="ring-container">
      <div class="ring">
        ${ringSVG(200, 20, score / 100, color)}
        <div class="ring-label">
          <div class="ring-value" style="font-size:56px;color:${color}">${Math.round(score)}</div>
          <div class="ring-caption">Recovery</div>
          <div class="ring-status" style="color:${color}">${cat}</div>
        </div>
      </div>
    </div>`;

    // Recommendation
    const recText = score >= 67 ? 'Recovery is strong. Great day for hard training or testing.' : score >= 34 ? 'Moderate recovery. Stick to steady state or easy work today.' : 'Low recovery. Rest day or very light activity recommended.';
    const recIcon = score >= 67 ? '&#9989;' : score >= 34 ? '&#9888;' : '&#10060;';
    html += `<div class="card" style="background:${color}11">
      <div class="flex items-center gap-12">
        <span style="font-size:24px">${recIcon}</span>
        <span class="text-sm color-secondary">${recText}</span>
      </div>
    </div>`;

    // Biometrics Grid
    html += `<div class="card">
      <div class="flex items-center gap-8 mb-8">
        <span style="color:var(--blue)">&#9201;</span>
        <span class="text-sm font-bold">Apple Watch Ultra Data</span>
      </div>
      <div class="bio-grid">
        <div class="bio-card">
          <div class="bio-icon" style="color:var(--purple)">&#128147;</div>
          <div class="bio-value">${status?.hrv != null ? Math.round(status.hrv) + ' ms' : '--'}</div>
          <div class="bio-title">HRV</div>
          <div class="bio-detail">Heart Rate Variability</div>
        </div>
        <div class="bio-card">
          <div class="bio-icon" style="color:var(--red)">&#10084;</div>
          <div class="bio-value">${status?.rhr != null ? Math.round(status.rhr) + ' bpm' : '--'}</div>
          <div class="bio-title">Resting HR</div>
          <div class="bio-detail">Lower is better</div>
        </div>
        <div class="bio-card">
          <div class="bio-icon" style="color:var(--cyan)">&#129729;</div>
          <div class="bio-value">${status?.bloodOxygen != null ? status.bloodOxygen.toFixed(1) + '%' : '--'}</div>
          <div class="bio-title">Blood Oxygen</div>
          <div class="bio-detail">SpO2</div>
        </div>
        <div class="bio-card">
          <div class="bio-icon" style="color:var(--green)">&#127811;</div>
          <div class="bio-value">${status?.respiratoryRate != null ? status.respiratoryRate.toFixed(1) + ' br/m' : '--'}</div>
          <div class="bio-title">Respiratory</div>
          <div class="bio-detail">Breaths per minute</div>
        </div>
        <div class="bio-card">
          <div class="bio-icon" style="color:var(--orange)">&#127777;</div>
          <div class="bio-value">${status?.wristTemp != null ? (status.wristTemp >= 0 ? '+' : '') + status.wristTemp.toFixed(1) + '°C' : '--'}</div>
          <div class="bio-title">Wrist Temp</div>
          <div class="bio-detail">Deviation</div>
        </div>
        <div class="bio-card">
          <div class="bio-icon" style="color:var(--blue)">&#128694;</div>
          <div class="bio-value">${(status?.steps || 0).toLocaleString()}</div>
          <div class="bio-title">Steps</div>
          <div class="bio-detail">Today</div>
        </div>
      </div>
    </div>`;

    // 7-Day Recovery History
    const last7 = (statuses || []).slice(0, 7).reverse();
    if (last7.length > 1) {
      html += `<div class="card">
        <div class="card-title mb-8">7-Day Recovery</div>
        <div class="history-bars">
          ${last7.map(s => {
            const c = recoveryColor(s.recoveryScore);
            const d = new Date(s.date);
            const dayName = d.toLocaleDateString('en-US', { weekday: 'short' });
            return `<div class="history-bar">
              <div class="history-bar-value" style="color:${c}">${Math.round(s.recoveryScore)}</div>
              <div class="history-bar-fill" style="height:${Math.max(s.recoveryScore * 0.6, 4)}px;background:${c}"></div>
              <div class="history-bar-label">${dayName}</div>
            </div>`;
          }).join('')}
        </div>
      </div>`;
    }

    return html;
  },

  sleepTab(status) {
    const sleepScore = status?.sleepScore ?? 0;
    const totalMin = status?.totalSleepMinutes ?? 0;
    const deepMin = status?.deepSleepMinutes ?? 0;
    const remMin = status?.remSleepMinutes ?? 0;
    const lightMin = status?.lightSleepMinutes ?? 0;
    const awakeMin = status?.awakeMinutes ?? 0;

    let html = '';

    // Sleep Score Ring
    html += `<div class="ring-container">
      <div class="ring">
        ${ringSVG(160, 16, sleepScore / 100, 'var(--indigo)')}
        <div class="ring-label">
          <div class="ring-value" style="font-size:44px;color:var(--indigo)">${Math.round(sleepScore)}</div>
          <div class="ring-caption">Sleep Score</div>
        </div>
      </div>
    </div>`;

    // Duration
    html += `<div class="text-center mb-16">
      <div style="font-size:28px;font-weight:700">${formatDuration(totalMin)}</div>
      <div class="text-sm color-secondary">Total Sleep</div>
    </div>`;

    // Sleep Stages
    html += '<div class="card"><div class="card-title mb-8">Sleep Stages</div>';
    const stages = [
      { label: 'Deep', min: deepMin, color: 'var(--indigo)', ideal: '1-2h' },
      { label: 'REM', min: remMin, color: 'var(--purple)', ideal: '1.5-2h' },
      { label: 'Light', min: lightMin, color: 'rgba(88,86,214,0.5)', ideal: '3-4h' },
      { label: 'Awake', min: awakeMin, color: 'var(--orange)', ideal: '<30m' }
    ];

    for (const s of stages) {
      const frac = totalMin > 0 ? s.min / totalMin : 0;
      html += `<div class="sleep-stage">
        <div class="sleep-stage-header">
          <span class="sleep-stage-label" style="color:${s.color}">${s.label}</span>
          <span class="sleep-stage-time">${Math.floor(s.min / 60)}h ${s.min % 60}m</span>
          <span class="sleep-stage-ideal">(ideal: ${s.ideal})</span>
        </div>
        <div class="progress-bar"><div class="progress-fill" style="width:${frac * 100}%;background:${s.color}"></div></div>
      </div>`;
    }
    html += '</div>';

    // Sleep Tip
    const hours = totalMin / 60;
    let tip;
    if (hours < 6) tip = "Less than 6 hours significantly impacts recovery, HRV, and performance. Aim for 7-9 hours.";
    else if (hours < 7) tip = "Close to minimum. Athletes perform best with 7-9 hours.";
    else if (hours <= 9) tip = "Great sleep duration! Check deep and REM for quality.";
    else tip = "Over 9 hours can indicate high fatigue. Monitor how you feel.";

    html += `<div class="card" style="background:var(--indigo)08">
      <div class="flex items-center gap-8">
        <span>&#127769;</span>
        <span class="text-sm color-secondary">${tip}</span>
      </div>
    </div>`;

    return html;
  },

  strainTab(status) {
    const strain = status?.strainScore ?? 0;
    const color = strainColor(strain);
    const cat = strainCategory(strain);

    let html = '';

    // Strain Gauge
    html += `<div class="ring-container">
      <div class="ring">
        ${gaugeArcSVG(200, 20, strain / 100, color)}
        <div class="ring-label">
          <div class="ring-value" style="font-size:48px;color:${color}">${strain.toFixed(1)}</div>
          <div class="ring-caption">/ 100</div>
          <div class="ring-status" style="color:${color}">${cat}</div>
        </div>
      </div>
    </div>`;

    // Activity Stats
    html += `<div class="flex gap-8" style="margin-bottom:16px">
      <div class="stat-card" style="flex:1">
        <div class="stat-icon" style="color:var(--red)">&#128293;</div>
        <div class="stat-value">${status?.activeCalories ?? 0}</div>
        <div class="stat-label">Active Cal</div>
      </div>
      <div class="stat-card" style="flex:1">
        <div class="stat-icon" style="color:var(--green)">&#127939;</div>
        <div class="stat-value">${status?.activeMinutes ?? 0}</div>
        <div class="stat-label">Active Min</div>
      </div>
      <div class="stat-card" style="flex:1">
        <div class="stat-icon" style="color:var(--blue)">&#128095;</div>
        <div class="stat-value">${(status?.steps ?? 0).toLocaleString()}</div>
        <div class="stat-label">Steps</div>
      </div>
    </div>`;

    // Strain vs Recovery Balance
    const recovery = status?.recoveryScore ?? 50;
    let optLow, optHigh;
    if (recovery >= 67) { optLow = 40; optHigh = 85; }
    else if (recovery >= 34) { optLow = 20; optHigh = 55; }
    else { optLow = 0; optHigh = 30; }

    const isOptimal = strain >= optLow && strain <= optHigh;
    const balanceMsg = isOptimal ? 'Strain is well-matched to your recovery.' : strain > optHigh ? 'Strain is high relative to recovery. Consider easing off.' : 'You have more capacity today. Room for harder training.';

    html += `<div class="card">
      <div class="card-title mb-8">Strain vs Recovery Balance</div>
      <div class="flex items-center gap-8">
        <span style="color:${isOptimal ? 'var(--green)' : 'var(--orange)'};font-size:20px">${isOptimal ? '&#9989;' : '&#9888;'}</span>
        <span class="text-sm color-secondary">${balanceMsg}</span>
      </div>
      <div class="text-xs color-tertiary mt-8">Optimal strain range for today: ${optLow}-${optHigh}</div>
    </div>`;

    return html;
  },

  energyTab(status) {
    const energy = status?.energyLevel ?? 100;
    const baseline = status?.energyBaseline ?? 100;
    const color = energyColor(energy);
    const cat = energyCategory(energy);

    let html = '';

    // Battery
    html += `<div style="padding:16px 0">
      <div class="battery" style="border-color:${color}50">
        <div class="battery-fill" style="height:${Math.max(energy, 2)}%;background:linear-gradient(to top, ${color}, ${color}aa)"></div>
        <div class="battery-label">
          <div style="font-size:36px;font-weight:700;color:#fff;text-shadow:0 1px 4px rgba(0,0,0,0.5)">${Math.round(energy)}%</div>
          <div style="font-size:12px;font-weight:600;color:#fff;text-shadow:0 1px 3px rgba(0,0,0,0.5)">${cat}</div>
        </div>
      </div>
      <div class="text-center text-sm color-secondary mt-8">Started at ${Math.round(baseline)}% based on recovery</div>
    </div>`;

    // Energy Drains
    if (status?.energyDrains?.length > 0) {
      html += '<div class="card"><div class="card-title mb-8">Energy Drains</div>';
      for (const d of status.energyDrains) {
        html += `<div class="flex items-center justify-between" style="padding:8px 0;border-bottom:0.5px solid rgba(255,255,255,0.05)">
          <div>
            <div class="text-sm">${d.source}</div>
            <div class="text-xs color-secondary">${d.durationMinutes} min</div>
          </div>
          <div class="flex items-center gap-8">
            <span class="text-sm font-bold color-red">-${Math.round(d.amount)}%</span>
            <span class="text-xs color-secondary">${formatTime(d.time)}</span>
          </div>
        </div>`;
      }
      html += '</div>';
    }

    // Energy Tip
    let tip, tipIcon;
    if (energy >= 70) { tip = "Energy is high. Great time for a hard workout or test piece."; tipIcon = "&#9889;"; }
    else if (energy >= 40) { tip = "Moderate energy. Steady state or moderate gym session would be appropriate."; tipIcon = "&#9196;"; }
    else if (energy >= 20) { tip = "Energy is low. Light activity only — easy row, walk, or mobility."; tipIcon = "&#9196;"; }
    else { tip = "Energy depleted. Rest is the priority."; tipIcon = "&#128267;"; }

    html += `<div class="card" style="background:${color}08">
      <div class="flex items-center gap-8">
        <span>${tipIcon}</span>
        <span class="text-sm color-secondary">${tip}</span>
      </div>
    </div>`;

    return html;
  },

  // =========================================
  // CAPTURE
  // =========================================
  capture() {
    return `<div class="fade-in">
      <div class="text-center" style="padding:20px 0">
        <div style="font-size:48px;margin-bottom:12px">📸</div>
        <div style="font-size:20px;font-weight:700;margin-bottom:8px">Capture Erg Score</div>
        <div class="text-sm color-secondary mb-16">Take a photo of your Concept2 monitor or enter scores manually</div>
      </div>

      <video id="camera-video" autoplay playsinline style="display:none;width:100%;border-radius:16px;margin-bottom:16px"></video>
      <canvas id="camera-canvas"></canvas>
      <img id="captured-img" style="display:none;width:100%;border-radius:16px;margin-bottom:16px" />

      <div class="flex gap-8 mb-16">
        <button class="btn btn-blue" onclick="App.startCamera()" id="btn-camera">
          <span>&#128247;</span> Take Photo
        </button>
        <button class="btn btn-gray" onclick="App.uploadPhoto()">
          <span>&#128194;</span> Upload
        </button>
      </div>

      <input type="file" id="photo-upload" accept="image/*" style="display:none" />

      <div id="capture-result" style="display:none">
        <div class="card">
          <div class="card-title mb-8">Detected Score</div>
          <div id="ocr-result"></div>
        </div>
      </div>

      <div class="card">
        <div class="card-title mb-8">Manual Entry</div>
        <div class="form-group">
          <label class="form-label">Workout Type</label>
          <select class="form-select" id="score-type">
            <option value="2k">2K Test</option>
            <option value="5k">5K</option>
            <option value="6k">6K</option>
            <option value="10k">10K</option>
            <option value="30min">30 Min</option>
            <option value="60min">60 Min</option>
            <option value="interval">Interval</option>
            <option value="steady_state">Steady State</option>
          </select>
        </div>
        <div class="flex gap-8">
          <div class="form-group" style="flex:1">
            <label class="form-label">Time (mm:ss.s)</label>
            <input class="form-input" type="text" id="score-time" placeholder="7:00.0">
          </div>
          <div class="form-group" style="flex:1">
            <label class="form-label">Distance (m)</label>
            <input class="form-input" type="number" id="score-distance" placeholder="2000">
          </div>
        </div>
        <div class="flex gap-8">
          <div class="form-group" style="flex:1">
            <label class="form-label">Split (/500m)</label>
            <input class="form-input" type="text" id="score-split" placeholder="1:45.0">
          </div>
          <div class="form-group" style="flex:1">
            <label class="form-label">Stroke Rate</label>
            <input class="form-input" type="number" id="score-sr" placeholder="28">
          </div>
        </div>
        <div class="flex gap-8">
          <div class="form-group" style="flex:1">
            <label class="form-label">Avg HR</label>
            <input class="form-input" type="number" id="score-hr" placeholder="175">
          </div>
          <div class="form-group" style="flex:1">
            <label class="form-label">Calories</label>
            <input class="form-input" type="number" id="score-cal" placeholder="">
          </div>
        </div>
        <button class="btn btn-blue mt-8" onclick="App.saveScore()">Save Score</button>
      </div>
    </div>`;
  },

  // =========================================
  // COACH
  // =========================================
  async coach(subTab = 'today') {
    const profile = await Store.getProfile();
    const scores = await Store.getScores();
    const status = await Store.getTodayStatus();

    let html = '<div class="fade-in">';

    html += `<div class="segmented">
      <button ${subTab === 'today' ? 'class="active"' : ''} onclick="App.renderCoach('today')">Today</button>
      <button ${subTab === 'weekly' ? 'class="active"' : ''} onclick="App.renderCoach('weekly')">Weekly Plan</button>
      <button ${subTab === 'insights' ? 'class="active"' : ''} onclick="App.renderCoach('insights')">Insights</button>
    </div>`;

    if (subTab === 'today') {
      const rec = AICoach.generateRecommendation(profile, scores, status);
      if (rec) {
        const catColors = { workout: 'var(--blue)', recovery: 'var(--green)', technique: 'var(--purple)', milestone: 'var(--yellow)', warning: 'var(--red)' };
        const c = catColors[rec.category] || 'var(--blue)';
        html += `<div class="card">
          <div style="font-size:48px;text-align:center;margin-bottom:12px">${rec.icon || '🚣'}</div>
          <div style="font-size:20px;font-weight:700;text-align:center;margin-bottom:4px">${rec.title}</div>
          <div class="text-center mb-16"><span class="badge" style="background:${c}22;color:${c}">${rec.category}</span></div>
          <div class="text-sm color-secondary" style="line-height:1.5;margin-bottom:16px">${rec.message}</div>
          ${rec.suggestedWorkout ? `<div class="card" style="background:var(--bg-tertiary)">
            <div class="card-title mb-8">Suggested Workout</div>
            <div class="flex justify-between">
              <div><div class="text-xs color-secondary">Split</div><div class="font-bold">${rec.suggestedWorkout.split || '--'} /500m</div></div>
              <div><div class="text-xs color-secondary">Rate</div><div class="font-bold">${rec.suggestedWorkout.strokeRate || '--'} s/m</div></div>
              <div><div class="text-xs color-secondary">Duration</div><div class="font-bold">${rec.suggestedWorkout.duration || '--'} min</div></div>
              <div><div class="text-xs color-secondary">Intensity</div><div class="font-bold">${rec.suggestedWorkout.intensity || '--'}</div></div>
            </div>
          </div>` : ''}
        </div>`;
      } else {
        html += `<div class="empty-state">
          <div class="empty-icon">🧠</div>
          <div class="empty-title">Set Up Profile</div>
          <div class="empty-subtitle">Complete your profile to get personalized coaching</div>
        </div>`;
      }
    } else if (subTab === 'weekly') {
      const plan = AICoach.generateWeeklyPlan(profile, status);
      const todayIdx = (new Date().getDay() + 6) % 7;

      html += '<div class="card"><div class="card-title mb-16">Weekly Training Plan</div>';
      for (let i = 0; i < plan.length; i++) {
        const p = plan[i];
        const isToday = i === todayIdx;
        const intensityColors = { Easy: 'var(--green)', Moderate: 'var(--blue)', Hard: 'var(--red)', Recovery: 'var(--text-tertiary)', Max: 'var(--orange)' };
        const c = intensityColors[p.intensity] || 'var(--blue)';

        html += `<div class="flex items-center justify-between" style="padding:12px 0;border-bottom:0.5px solid rgba(255,255,255,0.05);${isToday ? 'background:var(--blue)08;margin:0 -16px;padding-left:16px;padding-right:16px;border-radius:8px' : ''}">
          <div>
            <div class="flex items-center gap-8">
              <span class="text-sm font-bold" style="${isToday ? 'color:var(--blue)' : ''}">${p.day}</span>
              ${isToday ? '<span class="badge" style="background:var(--blue)22;color:var(--blue);font-size:10px">TODAY</span>' : ''}
            </div>
            <div class="text-sm color-secondary mt-8">${p.type}</div>
          </div>
          <div class="text-right">
            <span class="badge" style="background:${c}22;color:${c}">${p.intensity}</span>
            ${p.duration > 0 ? `<div class="text-xs color-secondary mt-8">${p.duration} min · ${p.sr} s/m</div>` : ''}
          </div>
        </div>`;
      }
      html += '</div>';
    } else if (subTab === 'insights') {
      html += '<div class="card"><div class="card-title mb-8">Training Insights</div>';

      if (scores.length >= 3) {
        const recent = scores.slice(0, 5);
        const avgSplit = recent.reduce((a, s) => a + (s.splitSeconds || 0), 0) / recent.length;
        html += `<div class="flex items-center gap-12" style="padding:12px 0;border-bottom:0.5px solid rgba(255,255,255,0.05)">
          <span style="font-size:24px">&#128200;</span>
          <div><div class="text-sm font-bold">Avg Split (Last 5)</div><div class="text-sm color-secondary">${formatSplit(avgSplit)} /500m</div></div>
        </div>`;
      }

      html += `<div class="flex items-center gap-12" style="padding:12px 0;border-bottom:0.5px solid rgba(255,255,255,0.05)">
        <span style="font-size:24px">&#127942;</span>
        <div><div class="text-sm font-bold">Total Workouts</div><div class="text-sm color-secondary">${profile?.totalWorkouts ?? 0} sessions logged</div></div>
      </div>`;

      html += `<div class="flex items-center gap-12" style="padding:12px 0">
        <span style="font-size:24px">&#128170;</span>
        <div><div class="text-sm font-bold">Consistency</div><div class="text-sm color-secondary">${profile?.streakDays ?? 0} day streak · ${profile?.currentWeekSessions ?? 0} this week</div></div>
      </div>`;

      html += '</div>';

      html += `<div class="card" style="background:var(--blue)08">
        <div class="flex items-center gap-8">
          <span>&#128161;</span>
          <span class="text-sm color-secondary">The AI coach learns from your data over time. Log more scores and workouts for better personalized recommendations.</span>
        </div>
      </div>`;
    }

    html += '</div>';
    return html;
  },

  // =========================================
  // MORE
  // =========================================
  more() {
    return `<div class="fade-in">
      <div class="list-section">
        <div class="list-section-title">Training</div>
        <div class="list-item" onclick="App.navigate('hr')">
          <div class="list-icon" style="background:var(--red)22;color:var(--red)">&#10084;</div>
          <div class="list-item-content"><div class="list-item-title">HR Monitor</div></div>
          <div class="list-arrow">&#8250;</div>
        </div>
        <div class="list-item" onclick="App.navigate('gym')">
          <div class="list-icon" style="background:var(--blue)22;color:var(--blue)">&#127947;</div>
          <div class="list-item-content"><div class="list-item-title">Gym Tracker</div></div>
          <div class="list-arrow">&#8250;</div>
        </div>
        <div class="list-item" onclick="App.navigate('history')">
          <div class="list-icon" style="background:var(--purple)22;color:var(--purple)">&#128336;</div>
          <div class="list-item-content"><div class="list-item-title">Erg History</div></div>
          <div class="list-arrow">&#8250;</div>
        </div>
      </div>

      <div class="list-section">
        <div class="list-section-title">Body</div>
        <div class="list-item" onclick="App.navigate('calories')">
          <div class="list-icon" style="background:var(--green)22;color:var(--green)">&#127860;</div>
          <div class="list-item-content"><div class="list-item-title">Nutrition</div></div>
          <div class="list-arrow">&#8250;</div>
        </div>
        <div class="list-item" onclick="App.navigate('body')">
          <div class="list-icon" style="background:var(--indigo)22;color:var(--indigo)">&#128716;</div>
          <div class="list-item-content"><div class="list-item-title">Recovery & Sleep</div></div>
          <div class="list-arrow">&#8250;</div>
        </div>
      </div>

      <div class="list-section">
        <div class="list-section-title">Settings</div>
        <div class="list-item" onclick="App.navigate('profile')">
          <div class="list-icon" style="background:var(--orange)22;color:var(--orange)">&#128100;</div>
          <div class="list-item-content"><div class="list-item-title">Profile</div></div>
          <div class="list-arrow">&#8250;</div>
        </div>
        <div class="list-item" onclick="App.navigate('simulate')">
          <div class="list-icon" style="background:var(--teal)22;color:var(--teal)">&#128202;</div>
          <div class="list-item-content"><div class="list-item-title">Simulate Data</div><div class="list-item-subtitle">Generate sample data to see the app in action</div></div>
          <div class="list-arrow">&#8250;</div>
        </div>
      </div>
    </div>`;
  },

  // =========================================
  // HR MONITOR
  // =========================================
  hrMonitor() {
    const isSupported = BluetoothHR.isSupported();
    const connected = BluetoothHR.connected;

    let html = '<div class="fade-in">';

    // Source badge
    const source = connected ? 'Polar' : 'No Device';
    const sourceIcon = connected ? '&#10084;' : '&#128148;';
    const sourceColor = connected ? 'var(--red)' : 'var(--text-tertiary)';
    html += `<div class="hr-source-badge">
      <span style="color:${sourceColor}">${sourceIcon}</span>
      <span class="font-bold text-sm">${source}</span>
      ${connected ? `<span class="text-sm color-secondary font-mono">${BluetoothHR.currentHR} BPM</span>` : ''}
    </div>`;

    if (connected) {
      // Connected view
      html += `<div class="card">
        <div class="flex items-center justify-between mb-16">
          <div class="flex items-center gap-8">
            <span style="color:var(--red)">&#10084;</span>
            <span class="font-bold text-sm">${BluetoothHR.deviceName}</span>
          </div>
          ${BluetoothHR.batteryLevel != null ? `<span class="text-xs color-secondary">&#128267; ${BluetoothHR.batteryLevel}%</span>` : ''}
          <button class="btn-small btn-outline" style="color:var(--red);border-color:var(--red)" onclick="App.disconnectHR()">Disconnect</button>
        </div>
      </div>`;

      // Big HR
      html += `<div class="ring-container">
        <div class="ring">
          ${ringSVG(200, 12, BluetoothHR.currentHR / 200, 'var(--red)')}
          <div class="ring-label">
            <div class="hr-big" style="color:var(--red)">${BluetoothHR.currentHR}</div>
            <div class="ring-caption">BPM</div>
          </div>
        </div>
      </div>`;

      // Session stats
      const stats = BluetoothHR.getSessionStats();
      if (stats.count > 0) {
        html += `<div class="flex gap-8 mt-16">
          <div class="stat-card" style="flex:1"><div class="stat-value">${stats.avg}</div><div class="stat-label">Avg</div></div>
          <div class="stat-card" style="flex:1"><div class="stat-value">${stats.max}</div><div class="stat-label">Max</div></div>
          <div class="stat-card" style="flex:1"><div class="stat-value">${stats.min}</div><div class="stat-label">Min</div></div>
        </div>`;
      }
    } else {
      // Disconnected view
      html += `<div class="text-center" style="padding:30px 0">
        <div style="font-size:80px;margin-bottom:16px;opacity:0.8">&#10084;</div>
        <div style="font-size:20px;font-weight:700;margin-bottom:8px">Connect HR Monitor</div>
        <div class="text-sm color-secondary mb-16">Connect your Polar H10, H9, or other BLE heart rate monitor for real-time tracking.</div>
        ${isSupported ? `<button class="btn btn-red" onclick="App.scanHR()">
          <span>&#128225;</span> Scan for Devices
        </button>` : `<div class="card" style="background:var(--red)11">
          <div class="text-sm color-red">Web Bluetooth is not supported in this browser. Use Chrome or Edge on desktop, or Chrome on Android.</div>
        </div>`}
      </div>`;

      html += `<div class="card">
        <div class="text-xs font-bold mb-8">Supported Devices</div>
        <div class="flex gap-8">
          <span class="badge" style="background:var(--blue)22;color:var(--blue)">Polar H10</span>
          <span class="badge" style="background:var(--blue)22;color:var(--blue)">Polar H9</span>
          <span class="badge" style="background:var(--blue)22;color:var(--blue)">Polar OH1</span>
        </div>
        <div class="text-xs color-tertiary mt-8">Any Bluetooth LE heart rate monitor will work</div>
      </div>`;
    }

    html += '</div>';
    return html;
  },

  // =========================================
  // GYM TRACKER
  // =========================================
  async gym() {
    const sessions = await Store.getGymSessions();

    let html = '<div class="fade-in">';

    // New session button
    html += `<button class="btn btn-blue mb-16" onclick="App.startGymSession()">
      <span>&#127947;</span> Start New Session
    </button>`;

    // Active session
    if (App.activeGymSession) {
      html += this.activeGymSession(App.activeGymSession);
    }

    // Recent sessions
    html += '<div class="card"><div class="card-title mb-8">Recent Sessions</div>';
    if (sessions.length === 0) {
      html += `<div class="empty-state"><div class="empty-icon">&#127947;</div><div class="empty-title">No gym sessions yet</div><div class="empty-subtitle">Start a session to track your lifts</div></div>`;
    } else {
      for (const s of sessions.slice(0, 5)) {
        html += `<div class="exercise-item">
          <div style="flex:1">
            <div class="font-bold">${s.sessionName}</div>
            <div class="text-xs color-secondary">${s.exercises?.length || 0} exercises &middot; ${s.totalSets || 0} sets &middot; ${formatDate(s.date)}</div>
          </div>
          <div class="text-right">
            <div class="font-bold">${s.totalVolume >= 1000 ? (s.totalVolume / 1000).toFixed(1) + 'k' : Math.round(s.totalVolume)} kg</div>
            <div class="text-xs color-secondary">Strain: ${(s.strainScore || 0).toFixed(1)}</div>
          </div>
        </div>`;
      }
    }
    html += '</div></div>';
    return html;
  },

  activeGymSession(session) {
    let html = `<div class="card" style="border:1px solid var(--blue)33">
      <div class="card-header">
        <span class="card-title">${session.sessionName}</span>
        <button class="btn-small btn-blue" onclick="App.finishGymSession()">Finish</button>
      </div>`;

    // Exercises
    for (let i = 0; i < session.exercises.length; i++) {
      const ex = session.exercises[i];
      html += `<div style="margin-bottom:16px;padding:12px;background:var(--bg-tertiary);border-radius:12px">
        <div class="flex items-center justify-between mb-8">
          <span class="font-bold">${ex.name}</span>
          <span class="text-xs color-secondary">${ex.muscleGroup}</span>
        </div>
        <div class="set-row" style="color:var(--text-secondary)">
          <span>Set</span><span>Weight (kg)</span><span>Reps</span><span>RPE</span>
        </div>`;

      for (let j = 0; j < ex.sets.length; j++) {
        const s = ex.sets[j];
        html += `<div class="set-row">
          <span class="set-number">${j + 1}</span>
          <span class="font-bold">${s.weightKg}</span>
          <span>${s.reps}</span>
          <span class="color-secondary">${s.rpe || '-'}</span>
        </div>`;
      }

      html += `<button class="btn-small btn-gray mt-8" onclick="App.addSet(${i})">+ Add Set</button>
      </div>`;
    }

    html += `<button class="btn btn-gray mt-8" onclick="App.addExercise()">+ Add Exercise</button>
    </div>`;
    return html;
  },

  // =========================================
  // CALORIES
  // =========================================
  async calories() {
    const profile = await Store.getProfile();
    const todayEntries = await Store.getTodayCalories();

    const totalCal = todayEntries.reduce((a, e) => a + e.calories, 0);
    const totalProtein = todayEntries.reduce((a, e) => a + (e.protein || 0), 0);
    const totalCarbs = todayEntries.reduce((a, e) => a + (e.carbs || 0), 0);
    const totalFat = todayEntries.reduce((a, e) => a + (e.fat || 0), 0);

    const target = profile?.calorieTarget || 2500;
    const protTarget = profile?.proteinTarget || 150;
    const carbTarget = profile?.carbTarget || 300;
    const fatTarget = profile?.fatTarget || 80;

    let html = '<div class="fade-in">';

    // Calorie Ring
    html += `<div class="ring-container">
      <div class="ring">
        ${ringSVG(160, 14, totalCal / target, totalCal > target ? 'var(--red)' : 'var(--green)')}
        <div class="ring-label">
          <div class="ring-value" style="font-size:36px">${totalCal}</div>
          <div class="ring-caption">/ ${target} cal</div>
        </div>
      </div>
    </div>`;

    // Macros
    html += `<div class="card">
      <div class="card-title mb-8">Macros</div>
      <div class="macro-bar-container">
        <div class="macro-label"><span style="color:var(--red)">Protein</span><span>${totalProtein}g / ${protTarget}g</span></div>
        <div class="progress-bar"><div class="progress-fill" style="width:${Math.min(totalProtein / protTarget * 100, 100)}%;background:var(--red)"></div></div>
      </div>
      <div class="macro-bar-container">
        <div class="macro-label"><span style="color:var(--blue)">Carbs</span><span>${totalCarbs}g / ${carbTarget}g</span></div>
        <div class="progress-bar"><div class="progress-fill" style="width:${Math.min(totalCarbs / carbTarget * 100, 100)}%;background:var(--blue)"></div></div>
      </div>
      <div class="macro-bar-container">
        <div class="macro-label"><span style="color:var(--yellow)">Fat</span><span>${totalFat}g / ${fatTarget}g</span></div>
        <div class="progress-bar"><div class="progress-fill" style="width:${Math.min(totalFat / fatTarget * 100, 100)}%;background:var(--yellow)"></div></div>
      </div>
    </div>`;

    // Water tracker
    const waterGlasses = App.waterCount || 0;
    html += `<div class="card">
      <div class="card-title mb-8">Water (${waterGlasses} / 8 glasses)</div>
      <div class="water-dots">
        ${Array.from({length: 8}, (_, i) => `<button class="water-dot ${i < waterGlasses ? 'filled' : ''}" onclick="App.setWater(${i + 1})">&#128167;</button>`).join('')}
      </div>
    </div>`;

    // Quick Add from Library
    html += `<div class="card">
      <div class="card-header">
        <span class="card-title">Quick Add</span>
      </div>
      <input class="form-input mb-8" type="text" id="food-search" placeholder="Search foods..." oninput="App.filterFoods(this.value)">
      <div id="food-list">`;

    for (const f of FoodLibrary.slice(0, 8)) {
      html += `<div class="food-item" onclick="App.addFood(${JSON.stringify(f).replace(/"/g, '&quot;')})">
        <div><div class="food-name">${f.name}</div><div class="food-macros">P:${f.protein}g C:${f.carbs}g F:${f.fat}g</div></div>
        <div class="food-cal">${f.cal} cal</div>
      </div>`;
    }
    html += '</div></div>';

    // Today's entries
    if (todayEntries.length > 0) {
      html += '<div class="card"><div class="card-title mb-8">Today\'s Log</div>';
      for (const e of todayEntries) {
        html += `<div class="exercise-item">
          <div style="flex:1"><div class="text-sm">${e.name}</div></div>
          <div class="text-right"><div class="font-bold">${e.calories} cal</div></div>
        </div>`;
      }
      html += '</div>';
    }

    html += '</div>';
    return html;
  },

  // =========================================
  // HISTORY
  // =========================================
  async history() {
    const scores = await Store.getScores();

    let html = '<div class="fade-in">';

    if (scores.length === 0) {
      html += `<div class="empty-state">
        <div class="empty-icon">&#128336;</div>
        <div class="empty-title">No erg scores yet</div>
        <div class="empty-subtitle">Capture or manually enter your erg scores</div>
      </div>`;
    } else {
      html += '<div class="card">';
      for (const s of scores) {
        html += `<div class="score-row">
          <div class="score-info">
            <div class="score-type">${s.workoutType}</div>
            <div class="score-split">${formatSplit(s.splitSeconds)} /500m</div>
          </div>
          <div class="score-meta">
            <div class="score-distance">${s.distance ? s.distance.toLocaleString() + 'm' : '--'}</div>
            <div class="score-date">${formatDate(s.date)} ${s.avgHR ? '&middot; ' + s.avgHR + ' bpm' : ''}</div>
          </div>
          ${s.capturedFromPhoto ? '<span class="text-xs color-secondary">&#128247;</span>' : ''}
        </div>`;
      }
      html += '</div>';
    }

    html += '</div>';
    return html;
  },

  // =========================================
  // PROFILE
  // =========================================
  async profile() {
    const profile = (await Store.getProfile()) || createDefaultProfile();

    return `<div class="fade-in">
      <div class="text-center" style="padding:20px 0">
        <div style="font-size:64px;margin-bottom:8px">&#128100;</div>
        <div style="font-size:20px;font-weight:700">Athlete Profile</div>
      </div>

      <div class="card">
        <div class="form-group">
          <label class="form-label">Name</label>
          <input class="form-input" type="text" id="prof-name" value="${profile.name}" placeholder="Your name">
        </div>
        <div class="flex gap-8">
          <div class="form-group" style="flex:1">
            <label class="form-label">Age</label>
            <input class="form-input" type="number" id="prof-age" value="${profile.age}">
          </div>
          <div class="form-group" style="flex:1">
            <label class="form-label">Weight (kg)</label>
            <input class="form-input" type="number" id="prof-weight" value="${profile.weight}">
          </div>
        </div>
        <div class="flex gap-8">
          <div class="form-group" style="flex:1">
            <label class="form-label">Height (cm)</label>
            <input class="form-input" type="number" id="prof-height" value="${profile.height}">
          </div>
          <div class="form-group" style="flex:1">
            <label class="form-label">Gender</label>
            <select class="form-select" id="prof-gender">
              <option value="male" ${profile.gender === 'male' ? 'selected' : ''}>Male</option>
              <option value="female" ${profile.gender === 'female' ? 'selected' : ''}>Female</option>
            </select>
          </div>
        </div>
      </div>

      <div class="card">
        <div class="card-title mb-8">Heart Rate</div>
        <div class="flex gap-8">
          <div class="form-group" style="flex:1">
            <label class="form-label">Max HR</label>
            <input class="form-input" type="number" id="prof-maxhr" value="${profile.maxHR}">
          </div>
          <div class="form-group" style="flex:1">
            <label class="form-label">Resting HR</label>
            <input class="form-input" type="number" id="prof-resthr" value="${profile.restingHR}">
          </div>
        </div>
      </div>

      <div class="card">
        <div class="card-title mb-8">Personal Records (split in seconds)</div>
        <div class="flex gap-8">
          <div class="form-group" style="flex:1">
            <label class="form-label">2K Split</label>
            <input class="form-input" type="text" id="prof-2k" value="${profile.pr2k || ''}" placeholder="1:45.0">
          </div>
          <div class="form-group" style="flex:1">
            <label class="form-label">5K Split</label>
            <input class="form-input" type="text" id="prof-5k" value="${profile.pr5k || ''}" placeholder="1:55.0">
          </div>
        </div>
      </div>

      <div class="card">
        <div class="card-title mb-8">Nutrition Targets</div>
        <div class="flex gap-8">
          <div class="form-group" style="flex:1">
            <label class="form-label">Daily Cal</label>
            <input class="form-input" type="number" id="prof-cal" value="${profile.calorieTarget}">
          </div>
          <div class="form-group" style="flex:1">
            <label class="form-label">Protein (g)</label>
            <input class="form-input" type="number" id="prof-protein" value="${profile.proteinTarget}">
          </div>
        </div>
        <div class="flex gap-8">
          <div class="form-group" style="flex:1">
            <label class="form-label">Carbs (g)</label>
            <input class="form-input" type="number" id="prof-carbs" value="${profile.carbTarget}">
          </div>
          <div class="form-group" style="flex:1">
            <label class="form-label">Fat (g)</label>
            <input class="form-input" type="number" id="prof-fat" value="${profile.fatTarget}">
          </div>
        </div>
      </div>

      <button class="btn btn-blue mb-16" onclick="App.saveProfile()">Save Profile</button>
    </div>`;
  },

  // =========================================
  // SIMULATE DATA
  // =========================================
  simulate() {
    return `<div class="fade-in">
      <div class="text-center" style="padding:20px 0">
        <div style="font-size:48px;margin-bottom:12px">&#128202;</div>
        <div style="font-size:20px;font-weight:700;margin-bottom:8px">Generate Sample Data</div>
        <div class="text-sm color-secondary mb-16">Since this is a web app without real Apple Watch / HealthKit data, you can generate realistic sample data to see all features in action.</div>
      </div>

      <button class="btn btn-blue mb-16" onclick="App.generateSampleData()">Generate Sample Data</button>
      <button class="btn btn-red mb-16" onclick="App.clearAllData()">Clear All Data</button>

      <div class="card" style="background:var(--blue)08">
        <div class="text-sm color-secondary">This will create:
          <ul style="margin-top:8px;padding-left:20px;line-height:1.6">
            <li>A sample athlete profile</li>
            <li>7 days of recovery/sleep/strain data</li>
            <li>Several erg scores (2K, 5K, steady state)</li>
            <li>A gym session with exercises</li>
            <li>Some calorie entries</li>
          </ul>
        </div>
      </div>
    </div>`;
  }
};
