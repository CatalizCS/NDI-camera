// TamaNDI Web Controller — app.js
// WebSocket + REST client with auto-reconnect, optimistic UI, and authoritative state.

'use strict';

const API_BASE = '';  // Same origin
const WS_RECONNECT_DELAY = 1500;
const PRESETS = [
    { id: 'streaming_1080p60', name: 'Streaming 1080p60', desc: '1920×1080 @ 60fps' },
    { id: 'streaming_4k30', name: 'Streaming 4K30', desc: '3840×2160 @ 30fps' },
    { id: 'low_bandwidth', name: 'Low Bandwidth', desc: '1280×720 @ 30fps' },
    { id: 'high_quality', name: 'High Quality', desc: '4K @ 60fps, Cinematic' },
    { id: 'dual_camera', name: 'Dual Camera', desc: 'Dual independent streams' },
    { id: 'triple_composite', name: 'Triple Composite', desc: 'Triple composite stream' },
];

// ─── State ───────────────────────────────────────────────────────────

let ws = null;
let token = localStorage.getItem('tamandiToken');
let state = {};
let isStreaming = false;

// ─── Init ────────────────────────────────────────────────────────────

document.addEventListener('DOMContentLoaded', () => {
    setupNavigation();
    setupControls();
    renderPresets();

    if (!token) {
        showPairingModal();
    } else {
        connectWebSocket();
    }
});

// ─── Navigation ──────────────────────────────────────────────────────

function setupNavigation() {
    document.querySelectorAll('.nav-btn').forEach(btn => {
        btn.addEventListener('click', () => {
            document.querySelectorAll('.nav-btn').forEach(b => b.classList.remove('active'));
            document.querySelectorAll('.panel').forEach(p => p.classList.remove('active'));
            btn.classList.add('active');
            document.getElementById('panel-' + btn.dataset.panel).classList.add('active');
        });
    });
}

// ─── Pairing ─────────────────────────────────────────────────────────

function showPairingModal() {
    document.getElementById('pairingModal').classList.add('active');
}

function hidePairingModal() {
    document.getElementById('pairingModal').classList.remove('active');
}

document.getElementById('pairBtn')?.addEventListener('click', async () => {
    const code = document.getElementById('pairingCode').value.trim();
    const errorEl = document.getElementById('pairingError');
    errorEl.textContent = '';

    if (code.length !== 6) {
        errorEl.textContent = 'Enter a 6-digit code';
        return;
    }

    try {
        const res = await fetch(API_BASE + '/api/v1/pair', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ code }),
        });
        const data = await res.json();
        if (data.ok && data.token) {
            token = data.token;
            localStorage.setItem('tamandiToken', token);
            hidePairingModal();
            connectWebSocket();
        } else {
            errorEl.textContent = data.error || 'Pairing failed';
        }
    } catch (e) {
        errorEl.textContent = 'Connection failed: ' + e.message;
    }
});

// ─── WebSocket ───────────────────────────────────────────────────────

function connectWebSocket() {
    if (ws) {
        ws.close();
    }

    const proto = location.protocol === 'https:' ? 'wss:' : 'ws:';
    const url = `${proto}//${location.host}/ws?token=${encodeURIComponent(token)}`;

    ws = new WebSocket(url);

    ws.onopen = () => {
        updateConnectionStatus(true);
        // Request initial state
        apiGet('/api/v1/status');
    };

    ws.onmessage = (event) => {
        try {
            const msg = JSON.parse(event.data);
            if (msg.type === 'state') {
                handleStateUpdate(msg.payload);
            } else if (msg.type === 'diagnostics') {
                handleDiagnosticsUpdate(msg.payload);
            }
        } catch (e) {
            console.warn('Invalid WebSocket message:', e);
        }
    };

    ws.onclose = () => {
        updateConnectionStatus(false);
        setTimeout(connectWebSocket, WS_RECONNECT_DELAY);
    };

    ws.onerror = () => {
        ws.close();
    };
}

function updateConnectionStatus(connected) {
    const el = document.getElementById('connectionStatus');
    el.textContent = connected ? 'Connected' : 'Disconnected';
    el.className = 'connection-status' + (connected ? ' connected' : '');
}

// ─── State Updates (Authoritative from WebSocket) ────────────────────

function handleStateUpdate(payload) {
    state = { ...state, ...payload };

    // Overview
    setText('streamStatus', payload.streaming ? 'Streaming' : 'Idle');
    setText('sourceName', payload.sourceName || '—');
    setText('currentLens', payload.currentLens || '—');
    setText('resFPS', payload.resolution ? `${payload.resolution} @ ${payload.fps || '—'}fps` : '—');
    setText('measuredFPS', payload.measuredFPS ? payload.measuredFPS.toFixed(1) : '—');
    setText('bitrate', payload.bitrateMbps ? payload.bitrateMbps.toFixed(1) + ' Mbps' : '—');
    setText('droppedFrames', payload.droppedFrames ?? 0);
    setText('audioRoute', payload.audioRoute || '—');
    setText('torchStatus', payload.torchEnabled ? 'On' : 'Off');
    setText('stabMode', payload.stabilization || '—');
    setText('thermalState', payload.thermalState || 'Nominal');

    // Thermal warning styling
    const thermalCard = document.getElementById('thermalState')?.closest('.stat-card');
    if (thermalCard) {
        thermalCard.className = 'stat-card';
        if (payload.thermalState === 'serious') thermalCard.classList.add('warn');
        if (payload.thermalState === 'critical') thermalCard.classList.add('danger');
    }

    // Stream button
    isStreaming = !!payload.streaming;
    const streamBtn = document.getElementById('streamToggle');
    if (streamBtn) {
        streamBtn.textContent = isStreaming ? 'Stop Stream' : 'Start Stream';
        streamBtn.className = 'btn btn-stream' + (isStreaming ? ' streaming' : '');
    }

    // Mute button
    const muteBtn = document.getElementById('muteToggle');
    if (muteBtn && payload.audioMuted !== undefined) {
        muteBtn.textContent = payload.audioMuted ? 'Muted' : 'Unmuted';
        muteBtn.className = 'btn btn-toggle' + (payload.audioMuted ? ' active' : '');
    }
}

function handleDiagnosticsUpdate(payload) {
    setText('diagCaptureFPS', payload.captureFPS?.toFixed(1) || '—');
    setText('diagOutputFPS', payload.outputFPS?.toFixed(1) || '—');
    setText('diagDropped', payload.droppedFrames ?? '—');
    setText('diagVideoQueue', payload.videoQueueDepth ?? '—');
    setText('diagAudioQueue', payload.audioQueueDepth ?? '—');
    setText('diagBitrate', payload.estimatedBitrateMbps ? payload.estimatedBitrateMbps.toFixed(1) + ' Mbps' : '—');
    setText('diagMemory', payload.memoryFootprintMB ? payload.memoryFootprintMB.toFixed(0) + ' MB' : '—');
    setText('diagThermal', payload.thermalState || '—');
    setText('diagFormat', payload.activeFormat || '—');
    setText('diagAudioRoute', payload.activeAudioRoute || '—');
    setText('diagNetwork', payload.networkInterface || '—');
}

// ─── Controls Setup ──────────────────────────────────────────────────

function setupControls() {
    // Stream toggle
    document.getElementById('streamToggle')?.addEventListener('click', () => {
        apiPost(isStreaming ? '/api/v1/stream/stop' : '/api/v1/stream/start');
    });

    // Zoom slider (optimistic)
    const zoomSlider = document.getElementById('zoomSlider');
    zoomSlider?.addEventListener('input', () => {
        setText('zoomValue', parseFloat(zoomSlider.value).toFixed(1) + 'x');
    });
    zoomSlider?.addEventListener('change', () => {
        apiPost('/api/v1/camera/zoom', { factor: parseFloat(zoomSlider.value) });
    });

    // EV slider (optimistic)
    const evSlider = document.getElementById('evSlider');
    evSlider?.addEventListener('input', () => {
        setText('evValue', parseFloat(evSlider.value).toFixed(1) + ' EV');
    });
    evSlider?.addEventListener('change', () => {
        apiPost('/api/v1/camera/exposure', { mode: 'custom', ev: parseFloat(evSlider.value) });
    });

    // Focus mode
    document.getElementById('focusMode')?.addEventListener('change', (e) => {
        apiPost('/api/v1/camera/focus', { mode: e.target.value });
    });

    // Exposure mode
    document.getElementById('exposureMode')?.addEventListener('change', (e) => {
        apiPost('/api/v1/camera/exposure', { mode: e.target.value });
    });

    // Video settings
    document.getElementById('resolutionSelect')?.addEventListener('change', (e) => {
        apiPost('/api/v1/video', { resolution: e.target.value });
    });

    document.getElementById('fpsSelect')?.addEventListener('change', (e) => {
        apiPost('/api/v1/video', { fps: parseFloat(e.target.value) });
    });

    document.getElementById('stabSelect')?.addEventListener('change', (e) => {
        apiPost('/api/v1/video', { stabilization: e.target.value });
    });

    // Audio mute toggle (optimistic)
    document.getElementById('muteToggle')?.addEventListener('click', () => {
        const isMuted = state.audioMuted;
        const muteBtn = document.getElementById('muteToggle');
        muteBtn.textContent = isMuted ? 'Unmuted' : 'Muted';
        muteBtn.className = 'btn btn-toggle' + (!isMuted ? ' active' : '');
        apiPost('/api/v1/audio', { muted: !isMuted });
    });

    // Gain slider
    const gainSlider = document.getElementById('gainSlider');
    gainSlider?.addEventListener('input', () => {
        setText('gainValue', parseFloat(gainSlider.value).toFixed(2));
    });
    gainSlider?.addEventListener('change', () => {
        apiPost('/api/v1/audio', { gain: parseFloat(gainSlider.value) });
    });

    // Torch toggle (optimistic)
    document.getElementById('torchStatus')?.closest('.stat-card')?.addEventListener('click', () => {
        const enabled = !state.torchEnabled;
        setText('torchStatus', enabled ? 'On' : 'Off');
        apiPost('/api/v1/torch', { enabled });
    });

    // Orientation buttons
    document.querySelectorAll('[data-orientation]').forEach(btn => {
        btn.addEventListener('click', () => {
            apiPost('/api/v1/orientation', { mode: btn.dataset.orientation });
        });
    });

    // Display mode buttons
    document.querySelectorAll('[data-display]').forEach(btn => {
        btn.addEventListener('click', () => {
            apiPost('/api/v1/display', { mode: btn.dataset.display });
        });
    });

    // Diagnostics export
    document.getElementById('exportDiagBtn')?.addEventListener('click', async () => {
        const res = await apiGet('/api/v1/status');
        if (res) {
            const blob = new Blob([JSON.stringify(res, null, 2)], { type: 'application/json' });
            const url = URL.createObjectURL(blob);
            const a = document.createElement('a');
            a.href = url;
            a.download = 'tamandicam-diagnostics.json';
            a.click();
            URL.revokeObjectURL(url);
        }
    });
}

// ─── Presets ─────────────────────────────────────────────────────────

function renderPresets() {
    const grid = document.getElementById('presetGrid');
    if (!grid) return;

    grid.innerHTML = '';
    PRESETS.forEach(preset => {
        const card = document.createElement('div');
        card.className = 'preset-card';
        card.innerHTML = `
            <div class="preset-name">${preset.name}</div>
            <div class="preset-desc">${preset.desc}</div>
        `;
        card.addEventListener('click', () => {
            apiPost('/api/v1/preset/load', { id: preset.id });
        });
        grid.appendChild(card);
    });
}

// ─── API Helpers ─────────────────────────────────────────────────────

async function apiGet(path) {
    try {
        const res = await fetch(API_BASE + path, {
            headers: { 'Authorization': 'Bearer ' + token },
        });
        return await res.json();
    } catch (e) {
        console.error('GET failed:', path, e);
        return null;
    }
}

async function apiPost(path, body = {}) {
    try {
        const res = await fetch(API_BASE + path, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer ' + token,
            },
            body: JSON.stringify(body),
        });
        return await res.json();
    } catch (e) {
        console.error('POST failed:', path, e);
        return null;
    }
}

// ─── DOM Helpers ─────────────────────────────────────────────────────

function setText(id, value) {
    const el = document.getElementById(id);
    if (el) el.textContent = String(value);
}
