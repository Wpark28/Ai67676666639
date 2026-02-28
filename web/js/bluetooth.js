// ===== Web Bluetooth Heart Rate Service =====
// Connects to Polar H10/H9 and other BLE HR monitors via Web Bluetooth API

const BluetoothHR = {
  device: null,
  server: null,
  characteristic: null,
  connected: false,
  currentHR: 0,
  rrIntervals: [],
  batteryLevel: null,
  deviceName: null,
  hrHistory: [],
  onUpdate: null,    // callback(hr, rrIntervals)
  onConnect: null,   // callback(deviceName)
  onDisconnect: null, // callback()

  isSupported() {
    return !!navigator.bluetooth;
  },

  async scan() {
    if (!this.isSupported()) {
      throw new Error('Web Bluetooth is not supported in this browser. Use Chrome or Edge.');
    }

    try {
      this.device = await navigator.bluetooth.requestDevice({
        filters: [{ services: [0x180D] }], // Heart Rate Service
        optionalServices: [0x180F]          // Battery Service
      });

      this.device.addEventListener('gattserverdisconnected', () => {
        this.connected = false;
        this.currentHR = 0;
        if (this.onDisconnect) this.onDisconnect();
      });

      return this.device;
    } catch (e) {
      if (e.name === 'NotFoundError') return null; // User cancelled
      throw e;
    }
  },

  async connect() {
    if (!this.device) throw new Error('No device selected');

    this.server = await this.device.gatt.connect();
    this.connected = true;
    this.deviceName = this.device.name || 'HR Monitor';

    // Heart Rate Service
    try {
      const hrService = await this.server.getPrimaryService(0x180D);
      this.characteristic = await hrService.getCharacteristic(0x2A37);
      this.characteristic.addEventListener('characteristicvaluechanged', (e) => this.handleHRData(e));
      await this.characteristic.startNotifications();
    } catch (e) {
      console.error('HR service error:', e);
    }

    // Battery Service
    try {
      const batService = await this.server.getPrimaryService(0x180F);
      const batChar = await batService.getCharacteristic(0x2A19);
      const batValue = await batChar.readValue();
      this.batteryLevel = batValue.getUint8(0);
    } catch (e) {
      // Battery service not available on all devices
    }

    if (this.onConnect) this.onConnect(this.deviceName);
  },

  disconnect() {
    if (this.device && this.device.gatt.connected) {
      this.device.gatt.disconnect();
    }
    this.connected = false;
    this.currentHR = 0;
    this.deviceName = null;
    this.batteryLevel = null;
  },

  handleHRData(event) {
    const value = event.target.value;
    const flags = value.getUint8(0);
    const is16Bit = flags & 0x01;
    let hr, offset;

    if (is16Bit) {
      hr = value.getUint16(1, true);
      offset = 3;
    } else {
      hr = value.getUint8(1);
      offset = 2;
    }

    // Skip energy expended if present
    if (flags & 0x08) offset += 2;

    // Parse R-R intervals
    const rr = [];
    if (flags & 0x10) {
      while (offset + 1 < value.byteLength) {
        const raw = value.getUint16(offset, true);
        rr.push(raw * 1000.0 / 1024.0);
        offset += 2;
      }
    }

    this.currentHR = hr;
    this.rrIntervals = rr;
    this.hrHistory.push({ time: Date.now(), hr });

    // Keep last 5 min of history
    const fiveMinAgo = Date.now() - 300000;
    this.hrHistory = this.hrHistory.filter(h => h.time > fiveMinAgo);

    if (this.onUpdate) this.onUpdate(hr, rr);
  },

  clearHistory() {
    this.hrHistory = [];
  },

  getSessionStats() {
    if (this.hrHistory.length === 0) return { avg: 0, max: 0, min: 0, count: 0 };
    const hrs = this.hrHistory.map(h => h.hr);
    return {
      avg: Math.round(hrs.reduce((a, b) => a + b, 0) / hrs.length),
      max: Math.max(...hrs),
      min: Math.min(...hrs),
      count: hrs.length
    };
  }
};
