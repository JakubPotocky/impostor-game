(() => {
  'use strict';

  const PROTOCOL_VERSION = '1.0';
  const APP_VERSION = 'web-1.0';
  const HEARTBEAT_MS = 2000;
  const MAX_AUTO_RECONNECTS = 3;

  const els = {
    connDot: document.getElementById('conn-dot'),
    nameInput: document.getElementById('name-input'),
    joinBtn: document.getElementById('join-btn'),
    connectError: document.getElementById('connect-error'),
    pickerList: document.getElementById('picker-list'),
    pickerEmpty: document.getElementById('picker-empty'),
    waitingName: document.getElementById('waiting-name'),
    waitingCount: document.getElementById('waiting-count'),
    changeIdentityBtn: document.getElementById('change-identity-btn'),
    revealProgressFill: document.getElementById('reveal-progress-fill'),
    revealCounter: document.getElementById('reveal-counter'),
    revealCard: document.getElementById('reveal-card'),
    revealHidden: document.getElementById('reveal-hidden'),
    revealShown: document.getElementById('reveal-shown'),
    revealPlayerName: document.getElementById('reveal-player-name'),
    revealRoleIcon: document.getElementById('reveal-role-icon'),
    revealRoleTitle: document.getElementById('reveal-role-title'),
    revealRoleSub: document.getElementById('reveal-role-sub'),
    revealTheme: document.getElementById('reveal-theme'),
    revealHint: document.getElementById('reveal-hint'),
    revealHintText: document.getElementById('reveal-hint-text'),
    revealActionBtn: document.getElementById('reveal-action-btn'),
    doneTitle: document.getElementById('done-title'),
    doneSub: document.getElementById('done-sub'),
    endedTitle: document.getElementById('ended-title'),
    endedMessage: document.getElementById('ended-message'),
    retryBtn: document.getElementById('retry-btn'),
  };

  // ── Identity (persists across a page refresh, not across tabs) ─────────────
  function uuid() {
    if (crypto.randomUUID) return crypto.randomUUID();
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
      const r = (Math.random() * 16) | 0;
      const v = c === 'x' ? r : (r & 0x3) | 0x8;
      return v.toString(16);
    });
  }

  let deviceId = sessionStorage.getItem('impostor_device_id');
  if (!deviceId) {
    deviceId = uuid();
    sessionStorage.setItem('impostor_device_id', deviceId);
  }

  // ── Connection state ─────────────────────────────────────────────────────
  let ws = null;
  let sessionId = '';
  let sessionToken = '';
  let displayName = '';
  let myPlayerName = null;
  let latestPlayers = [];
  let latestDevices = [];
  let reconnectAttempts = 0;
  let reconnectTimer = null;
  let heartbeatTimer = null;
  let deliberateClose = false;

  // ── Reveal state ─────────────────────────────────────────────────────────
  let assignments = [];
  let assignmentMeta = {};
  let revealIndex = 0;
  let revealShown = false;

  function wsUrl() {
    const proto = location.protocol === 'https:' ? 'wss://' : 'ws://';
    return proto + location.host + '/';
  }

  function send(messageType, payload) {
    if (!ws || ws.readyState !== WebSocket.OPEN) return;
    ws.send(JSON.stringify({
      messageType,
      sessionId,
      payload,
      protocolVersion: PROTOCOL_VERSION,
    }));
  }

  function setConnDot(state) {
    els.connDot.className = 'conn-dot conn-' + state;
  }

  function showScreen(id) {
    document.querySelectorAll('.screen').forEach((s) => s.classList.remove('active'));
    document.getElementById(id).classList.add('active');
  }

  // ── Connection lifecycle ─────────────────────────────────────────────────
  function connect() {
    deliberateClose = false;
    setConnDot('connecting');
    ws = new WebSocket(wsUrl());
    ws.addEventListener('open', onOpen);
    ws.addEventListener('message', onMessage);
    ws.addEventListener('close', onClose);
    ws.addEventListener('error', () => {});
  }

  function onOpen() {
    reconnectAttempts = 0;
    send('helloClient', { deviceId, displayName, appVersion: APP_VERSION });
  }

  function onMessage(evt) {
    let msg;
    try {
      msg = JSON.parse(evt.data);
    } catch (_) {
      return;
    }
    if (msg.sessionId) sessionId = msg.sessionId;

    switch (msg.messageType) {
      case 'helloHostAck':
        sessionToken = msg.payload.sessionToken || '';
        send('joinRequest', { deviceId, sessionToken });
        break;

      case 'joinAccepted':
        setConnDot('connected');
        startHeartbeat();
        if (myPlayerName) {
          // Reconnect mid-session: reclaim identity, resume waiting room.
          send('playerIdentitySelect', { deviceId, playerName: myPlayerName, sessionToken });
          showScreen('screen-waiting');
        } else {
          showScreen('screen-picker');
        }
        break;

      case 'joinRejected':
        setConnDot('lost');
        showConnectError(friendlyRejectReason(msg.payload.reason));
        break;

      case 'lobbyStateSync':
        latestPlayers = msg.payload.players || [];
        latestDevices = msg.payload.devices || [];
        onLobbyState();
        break;

      case 'playerIdentityConfirmed':
        myPlayerName = msg.payload.playerName || myPlayerName;
        els.waitingName.textContent = myPlayerName || '—';
        showScreen('screen-waiting');
        break;

      case 'heartbeat':
        send('heartbeat', { deviceId });
        break;

      case 'startGame':
        // The host sends this device's assignmentDistribution (if any)
        // before broadcasting startGame, over the same connection, so if
        // we already switched to the reveal screen, leave it alone.
        if (document.getElementById('screen-reveal').classList.contains('active')) {
          break;
        }
        if (!myPlayerName) {
          showEnded(
            "You didn't pick a player before the host started. You'll be included next round.",
            "Round Started Without You"
          );
          break;
        }
        showScreen('screen-starting');
        break;

      case 'assignmentDistribution':
        onAssignmentDistribution(msg.payload);
        break;

      case 'allRevealsComplete':
        els.doneTitle.textContent = "Everyone's ready!";
        els.doneSub.textContent = 'Head back to the table and start the discussion.';
        showScreen('screen-done');
        break;

      case 'disconnectNotice':
        // Host-initiated notice; the socket close (below) drives the actual UI.
        break;

      default:
        break;
    }
  }

  function onClose(evt) {
    stopHeartbeat();
    if (deliberateClose) return;

    const hostEnded = evt.reason === 'host_stopped';
    if (hostEnded || reconnectAttempts >= MAX_AUTO_RECONNECTS) {
      setConnDot('lost');
      showEnded(hostEnded
        ? 'The host ended the game.'
        : "Couldn't reach the host. Make sure you're still on their Wi-Fi.");
      return;
    }

    reconnectAttempts += 1;
    setConnDot('connecting');
    const delay = Math.min(1000 * 2 ** (reconnectAttempts - 1), 4000);
    reconnectTimer = setTimeout(connect, delay);
  }

  function startHeartbeat() {
    stopHeartbeat();
    heartbeatTimer = setInterval(() => send('heartbeat', { deviceId }), HEARTBEAT_MS);
  }
  function stopHeartbeat() {
    if (heartbeatTimer) clearInterval(heartbeatTimer);
    heartbeatTimer = null;
  }

  // ── Screen: connect ──────────────────────────────────────────────────────
  function showConnectError(text) {
    els.connectError.textContent = text;
    els.connectError.classList.remove('hidden');
    els.joinBtn.disabled = false;
    showScreen('screen-connect');
  }

  els.joinBtn.addEventListener('click', () => {
    const typed = els.nameInput.value.trim();
    displayName = typed || 'Guest';
    els.connectError.classList.add('hidden');
    els.joinBtn.disabled = true;
    connect();
  });

  // ── Screen: identity picker ──────────────────────────────────────────────
  function onLobbyState() {
    if (document.getElementById('screen-picker').classList.contains('active')) {
      renderPicker();
    }
    if (document.getElementById('screen-waiting').classList.contains('active')) {
      updateWaitingCount();
    }
  }

  function renderPicker() {
    els.pickerList.innerHTML = '';
    els.pickerEmpty.classList.toggle('hidden', latestPlayers.length > 0);

    latestPlayers.forEach((name) => {
      const takenByOther = latestDevices.some(
        (d) => d.selectedPlayerName === name && d.deviceId !== deviceId
      );
      const chip = document.createElement('div');
      chip.className = 'chip' + (takenByOther ? ' taken' : '');
      chip.innerHTML = `<span>${escapeHtml(name)}</span>` +
        (takenByOther ? '<span class="chip-tag">taken</span>' : '');
      if (!takenByOther) {
        chip.addEventListener('click', () => {
          send('playerIdentitySelect', { deviceId, playerName: name, sessionToken });
        });
      }
      els.pickerList.appendChild(chip);
    });
  }

  els.changeIdentityBtn.addEventListener('click', () => {
    myPlayerName = null;
    showScreen('screen-picker');
    renderPicker();
  });

  // ── Screen: waiting room ─────────────────────────────────────────────────
  function updateWaitingCount() {
    const connected = latestDevices.filter((d) => d.connectionState === 'connected').length;
    els.waitingCount.textContent = String(connected);
  }

  // ── Screen: reveal ───────────────────────────────────────────────────────
  function onAssignmentDistribution(payload) {
    assignments = payload.assignments || [];
    assignmentMeta = {
      word: payload.word || '',
      themeName: payload.themeName || '',
      hintsEnabled: !!payload.hintsEnabled,
      themeVisibilityMode: payload.themeVisibilityMode ?? 1,
      impostorHintWord: payload.impostorHintWord || null,
      reducedMotion: !!payload.reducedMotion,
    };
    revealIndex = 0;
    revealShown = false;
    renderReveal();
    showScreen('screen-reveal');
  }

  function shouldShowTheme(isImpostor) {
    switch (assignmentMeta.themeVisibilityMode) {
      case 0: return false;
      case 2: return true;
      default: return !isImpostor; // 1: innocentsOnly
    }
  }

  function renderReveal() {
    const total = assignments.length;
    const a = assignments[revealIndex] || { playerName: '—', isImpostor: false, word: null };

    els.revealCounter.textContent = `Player ${revealIndex + 1} of ${total}`;
    els.revealProgressFill.style.width = `${((revealIndex) / Math.max(total, 1)) * 100}%`;

    els.revealCard.classList.remove('impostor', 'innocent');
    els.revealHidden.classList.toggle('hidden', revealShown);
    els.revealShown.classList.toggle('hidden', !revealShown);

    if (!revealShown) {
      els.revealPlayerName.textContent = a.playerName;
      els.revealActionBtn.textContent = 'Reveal My Role';
      return;
    }

    const isImpostor = a.isImpostor;
    const word = a.word || assignmentMeta.word;
    els.revealCard.classList.add(isImpostor ? 'impostor' : 'innocent');
    els.revealRoleIcon.textContent = isImpostor ? '⚠️' : '✅';
    els.revealRoleTitle.textContent = isImpostor ? 'You are the IMPOSTOR' : word;
    els.revealRoleSub.textContent = isImpostor
      ? "Blend in. Don't get caught!"
      : 'This is the secret word.';

    const showTheme = shouldShowTheme(isImpostor) && assignmentMeta.themeName.trim() !== '';
    els.revealTheme.classList.toggle('hidden', !showTheme);
    if (showTheme) els.revealTheme.textContent = `Theme: ${assignmentMeta.themeName.trim()}`;

    const showHint = isImpostor && assignmentMeta.hintsEnabled &&
      (assignmentMeta.impostorHintWord || '').trim() !== '';
    els.revealHint.classList.toggle('hidden', !showHint);
    if (showHint) els.revealHintText.textContent = `Hint word: ${assignmentMeta.impostorHintWord.trim()}`;

    els.revealActionBtn.textContent =
      revealIndex + 1 >= total ? 'Finish' : 'Pass to Next Player';
  }

  els.revealActionBtn.addEventListener('click', () => {
    if (!revealShown) {
      revealShown = true;
      renderReveal();
      return;
    }
    const total = assignments.length;
    const next = revealIndex + 1;
    if (next >= total) {
      send('revealProgressUpdate', { deviceId, revealsCompleted: total, revealsTotal: total });
      els.doneTitle.textContent = 'All your reveals are done!';
      els.doneSub.textContent = 'Waiting for other devices to finish…';
      showScreen('screen-done');
      // Clear the last shown word from memory once we've moved on.
      assignments = [];
      return;
    }
    revealIndex = next;
    revealShown = false;
    renderReveal();
    send('revealProgressUpdate', { deviceId, revealsCompleted: revealIndex, revealsTotal: total });
  });

  // ── Screen: ended / retry ────────────────────────────────────────────────
  function showEnded(message, title) {
    els.endedTitle.textContent = title || 'Disconnected';
    els.endedMessage.textContent = message;
    showScreen('screen-ended');
  }

  els.retryBtn.addEventListener('click', () => {
    reconnectAttempts = 0;
    showScreen('screen-connect');
  });

  // ── Utilities ────────────────────────────────────────────────────────────
  function friendlyRejectReason(reason) {
    if (reason === 'incompatible_version') {
      return "This game host is running a different app version. Ask them to update.";
    }
    return "The host couldn't accept your join request. Try again.";
  }

  function escapeHtml(str) {
    return str.replace(/[&<>"']/g, (c) => ({
      '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
    }[c]));
  }

  document.addEventListener('visibilitychange', () => {
    if (document.visibilityState === 'visible' && ws && ws.readyState === WebSocket.CLOSED &&
        !deliberateClose && !document.getElementById('screen-ended').classList.contains('active') &&
        !document.getElementById('screen-connect').classList.contains('active')) {
      reconnectAttempts = 0;
      connect();
    }
  });

  window.addEventListener('beforeunload', () => {
    deliberateClose = true;
  });
})();
