(function () {
  const menu = document.getElementById('menu');
  const menuOptions = document.getElementById('menu-options');
  const menuTitle = document.getElementById('menu-title');
  const menuSubtitle = document.getElementById('menu-subtitle');
  const menuCount = document.getElementById('menu-count');
  const linkStatus = document.getElementById('link-status');
  const linkState = document.getElementById('link-state');
  const admin = document.getElementById('admin');
  const adminTitle = document.getElementById('admin-title');
  const adminSubtitle = document.getElementById('admin-subtitle');
  const adminLiveState = document.getElementById('admin-live-state');
  const adminDistrictCount = document.getElementById('admin-district-count');
  const adminCommandCount = document.getElementById('admin-command-count');
  const adminMapCamera = document.getElementById('admin-map-camera');
  const adminMapRaster = document.getElementById('admin-map-raster');
  const adminMapSvg = document.getElementById('admin-map-svg');
  const adminMapBoundaries = document.getElementById('admin-map-boundaries');
  const adminMapViewport = document.querySelector('.admin-map-viewport');
  const adminMapZoomLabel = document.getElementById('admin-map-zoom-label');
  const adminMapZoomIn = document.getElementById('admin-map-zoom-in');
  const adminMapZoomOut = document.getElementById('admin-map-zoom-out');
  const adminMapReset = document.getElementById('admin-map-reset');
  const adminMapZones = document.getElementById('admin-map-zones');
  const adminMapMarkers = document.getElementById('admin-map-markers');
  const adminMapUpdated = document.getElementById('admin-map-updated');
  const adminInspector = document.querySelector('.admin-inspector');
  const adminInspectorDot = document.getElementById('admin-inspector-dot');
  const adminInspectorTitle = document.getElementById('admin-inspector-title');
  const adminInspectorCopy = document.getElementById('admin-inspector-copy');
  const adminInspectorStatus = document.querySelector('.admin-inspector-status');
  const adminInspectorStatusLabel = document.getElementById('admin-inspector-status-label');
  const adminInspectorStatusValue = document.getElementById('admin-inspector-status-value');
  const adminInspectorGrid = document.getElementById('admin-inspector-grid');
  const adminInspectorAssignment = document.getElementById('admin-inspector-assignment');
  const adminInspectorLevel = document.getElementById('admin-inspector-level');
  const adminInspectorRevision = document.getElementById('admin-inspector-revision');
  const adminInspectorBounds = document.getElementById('admin-inspector-bounds');
  const adminInspectorList = document.getElementById('admin-inspector-list');
  const adminTabButtons = [...document.querySelectorAll('[data-admin-tab]')];
  const adminTabPanels = {
    map: document.getElementById('admin-tab-map'),
    commands: document.getElementById('admin-tab-commands'),
  };
  const adminRegionActions = document.getElementById('admin-region-actions');
  const adminCommandList = document.getElementById('admin-command-list');
  const adminCommandTitle = document.getElementById('admin-command-title');
  const adminCommandDescription = document.getElementById('admin-command-description');
  const adminCommandCode = document.getElementById('admin-command-code');
  const adminCommandForm = document.getElementById('admin-command-form');
  const adminCommandFields = document.getElementById('admin-command-fields');
  const adminCommandSubmit = document.getElementById('admin-command-submit');
  const adminCommandStatus = document.getElementById('admin-command-status');
  const adminCloseButton = document.getElementById('admin-close');
  const adminRefreshButton = document.getElementById('admin-refresh');
  const progress = document.getElementById('progress');
  const progressLabel = document.getElementById('progress-label');
  const progressStage = document.getElementById('progress-stage');
  const progressFill = document.getElementById('progress-fill');
  const progressPercent = document.getElementById('progress-percent');
  const progressStep = document.getElementById('progress-step');
  const progressKicker = document.getElementById('progress-kicker');
  const progressCancelButton = document.getElementById('progress-cancel');
  const skill = document.getElementById('skillcheck');
  const skillTitle = document.getElementById('skill-title');
  const skillLabel = document.getElementById('skill-label');
  const skillKey = document.getElementById('skill-key');
  const skillKeyLabel = document.getElementById('skill-key-label');
  const skillStage = document.getElementById('skill-stage');
  const skillTimer = document.getElementById('skill-timer');
  const skillTimeFill = document.getElementById('skill-time-fill');
  const notifications = document.getElementById('notifications');

  const state = {
    menuToken: null,
    menuBusy: false,
    progressToken: null,
    progressDuration: 0,
    progressStartedAt: 0,
    progressCanCancel: false,
    progressTimer: null,
    progressFrame: null,
    skillToken: null,
    skillStages: [],
    skillInputs: [],
    skillIndex: 0,
    skillExpected: null,
    skillDeadline: 0,
    skillWindow: 0,
    skillFrame: null,
    adminToken: null,
    adminTab: 'map',
    adminSnapshot: { districts: [], commands: [], regions: [] },
    adminDistrict: null,
    adminCommand: null,
    adminMapZoom: 1,
    adminMapPan: { x: 0, y: 0 },
    adminMapPointer: null,
    adminMapCameraFrame: null,
    adminMapSuppressClick: false,
    adminMapHitRegions: [],
    adminMapRasterScale: 0,
    adminGeometry: null,
    adminGeometryPromise: null,
    adminRegionBusy: false,
  };

  const adminWorldBounds = Object.freeze({ minX: -3429, maxX: 3988, minY: -3557, maxY: 7166 });
  const adminMapSize = Object.freeze({ width: 2048, height: 2048 });
  const adminDefaultProjection = Object.freeze({ originX: 939, originY: 1381, scaleX: 0.16425, scaleY: 0.16425 });
  const adminMapZoomMin = 1;
  const adminMapZoomMax = 12;
  const adminMapDragThreshold = 5;
  const adminGeometryUrl = 'assets/gta-native-districts.json';

  const iconPaths = {
    'dumpster-fire': '<path d="M5 7h14M7 7l1 12h8l1-12M9 4h6l1 3H8l1-3M10 11v5M14 11v5M19 3l1 2-2 2"/>',
    bomb: '<circle cx="12" cy="13" r="6"/><path d="M12 7V4M12 4l3-2M12 4h-2M16.5 8.5l2-2M18.5 6.5l1 1"/>',
    'screwdriver-wrench': '<path d="m14 6 4 4M13 7l-3-3a4 4 0 0 0-5 5l3 3 3-3 2 2-3 3 3 3 2-2M16 13l4 4-3 3-4-4M7 17l-4 4"/>',
    default: '<path d="M12 3v18M3 12h18M5.5 5.5l13 13M18.5 5.5l-13 13"/>',
  };

  function resourceName() {
    return typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'gnsh-blackout';
  }

  function post(name, payload) {
    return fetch(`https://${resourceName()}/${name}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(payload || {}),
    }).catch(() => null);
  }

  function show(element) {
    element.classList.remove('hidden');
  }

  function hide(element) {
    element.classList.add('hidden');
  }

  function syncVisibility() {
    const activePanel = [admin, menu, progress, skill].some((element) => !element.classList.contains('hidden'));
    const active = activePanel || notifications.children.length > 0;
    document.documentElement.classList.toggle('ui-active', active);
    document.body.classList.toggle('ui-active', active);
  }

  function adminProjectPoint(x, y) {
    const safeX = Number.isFinite(Number(x)) ? Number(x) : adminWorldBounds.minX;
    const safeY = Number.isFinite(Number(y)) ? Number(y) : adminWorldBounds.minY;
    const projection = state.adminGeometry && state.adminGeometry.projection;
    if (projection && Number(projection.scaleX) > 0 && Number(projection.scaleY) > 0) {
      return {
        x: Number(projection.originX) + (safeX * Number(projection.scaleX)),
        y: Number(projection.originY) - (safeY * Number(projection.scaleY)),
      };
    }
    return {
      x: adminDefaultProjection.originX + (safeX * adminDefaultProjection.scaleX),
      y: adminDefaultProjection.originY - (safeY * adminDefaultProjection.scaleY),
    };
  }

  function validAdminGeometry(data) {
    if (!data || !data.districts || typeof data.districts !== 'object') return false;
    if (data.format === 'world-rects') {
      return Number(data.version) >= 2 && data.projection && data.bounds;
    }
    return Number(data.version) === 1 && data.source === 'GetNameOfZone'
      && data.bounds && Number(data.cellSize) > 0
      && Number.isInteger(Number(data.columns)) && Number.isInteger(Number(data.rows));
  }

  function loadAdminGeometry() {
    if (state.adminGeometryPromise) return state.adminGeometryPromise;
    state.adminGeometryPromise = fetch(adminGeometryUrl, { cache: 'no-store' })
      .then((response) => {
        if (!response.ok) throw new Error(`district geometry ${response.status}`);
        return response.json();
      })
      .then((data) => {
        state.adminGeometry = validAdminGeometry(data) ? data : null;
        return state.adminGeometry;
      })
      .catch(() => {
        state.adminGeometry = null;
        return null;
      });
    return state.adminGeometryPromise;
  }

  function adminDistrictGeometry(district) {
    const geometry = state.adminGeometry;
    if (!district || !geometry || !geometry.districts) return null;
    const entry = geometry.districts[district.id];
    const hasWorldRects = entry && Array.isArray(entry.rects) && entry.rects.length > 0;
    const hasGridRuns = entry && Array.isArray(entry.runs) && entry.runs.length > 0;
    if (!hasWorldRects && !hasGridRuns) return null;
    return entry;
  }

  function adminDisplayDistricts() {
    const serverDistricts = Array.isArray(state.adminSnapshot.districts) ? state.adminSnapshot.districts : [];
    const geometryDistricts = state.adminGeometry && state.adminGeometry.districts;
    if (!geometryDistricts) return serverDistricts;
    const nativeOnly = state.adminGeometry.format === 'world-rects';
    const mappedServerDistricts = nativeOnly
      ? serverDistricts.filter((district) => geometryDistricts[district.id])
      : serverDistricts;
    const known = new Set(mappedServerDistricts.map((district) => district.id));
    const geometryOnly = Object.entries(geometryDistricts)
      .filter(([id]) => !known.has(id))
      .map(([id, geometry]) => ({
        id,
        label: geometry.label || id,
        category: 'native',
        assignment: 'UNASSIGNED',
        state: { powered: true, level: 1, revision: 0, status: 'UNTRACKED' },
      }));
    return [...mappedServerDistricts, ...geometryOnly];
  }

  function adminGridPoint(gridX, gridY) {
    const geometry = state.adminGeometry;
    if (!geometry) return adminProjectPoint(adminWorldBounds.minX, adminWorldBounds.minY);
    const worldX = Number(geometry.bounds.minX) + (Number(gridX) * Number(geometry.cellSize));
    const worldY = Number(geometry.bounds.maxY) - (Number(gridY) * Number(geometry.cellSize));
    return adminProjectPoint(worldX, worldY);
  }

  function adminDistrictBounds(district) {
    const nativeGeometry = adminDistrictGeometry(district);
    const geometry = state.adminGeometry;
    if (nativeGeometry && nativeGeometry.worldBounds) return nativeGeometry.worldBounds;
    const gridBounds = nativeGeometry && nativeGeometry.gridBounds;
    if (geometry && gridBounds) {
      return {
        minX: Number(geometry.bounds.minX) + (Number(gridBounds.minCol) * Number(geometry.cellSize)),
        maxX: Number(geometry.bounds.minX) + (Number(gridBounds.maxCol) * Number(geometry.cellSize)),
        minY: Number(geometry.bounds.maxY) - (Number(gridBounds.maxRow) * Number(geometry.cellSize)),
        maxY: Number(geometry.bounds.maxY) - (Number(gridBounds.minRow) * Number(geometry.cellSize)),
      };
    }
    return district && district.bounds ? district.bounds : {};
  }

  function adminNativePaths(nativeGeometry) {
    if (Array.isArray(nativeGeometry.rects)) {
      const fill = nativeGeometry.rects.map((rect) => {
        const topLeft = adminProjectPoint(rect[0], rect[3]);
        const bottomRight = adminProjectPoint(rect[2], rect[1]);
        return `M${topLeft.x} ${topLeft.y}H${bottomRight.x}V${bottomRight.y}H${topLeft.x}Z`;
      }).join('');
      const outline = (nativeGeometry.edges || []).map((edge) => {
        const start = adminProjectPoint(edge[0], edge[1]);
        const end = adminProjectPoint(edge[2], edge[3]);
        return `M${start.x} ${start.y}L${end.x} ${end.y}`;
      }).join('');
      return { fill, outline };
    }
    const fill = nativeGeometry.runs.map((run) => {
      const topLeft = adminGridPoint(run[1], run[0]);
      const bottomRight = adminGridPoint(run[2], run[0] + 1);
      return `M${topLeft.x} ${topLeft.y}H${bottomRight.x}V${bottomRight.y}H${topLeft.x}Z`;
    }).join('');
    const outline = (nativeGeometry.edges || []).map((edge) => {
      const start = adminGridPoint(edge[0], edge[1]);
      const end = adminGridPoint(edge[2], edge[3]);
      return `M${start.x} ${start.y}L${end.x} ${end.y}`;
    }).join('');
    return { fill, outline };
  }

  function adminNativeBoundaryPath() {
    const geometry = state.adminGeometry;
    if (!geometry || !geometry.districts) return '';
    const segments = [];
    const seen = new Set();
    Object.values(geometry.districts).forEach((districtGeometry) => {
      const worldEdges = Array.isArray(districtGeometry.rects);
      (districtGeometry.edges || []).forEach((edge) => {
        if (!Array.isArray(edge) || edge.length < 4) return;
        const first = `${Number(edge[0]).toFixed(2)},${Number(edge[1]).toFixed(2)}`;
        const second = `${Number(edge[2]).toFixed(2)},${Number(edge[3]).toFixed(2)}`;
        const key = `${worldEdges ? 'world' : 'grid'}:${[first, second].sort().join('|')}`;
        if (seen.has(key)) return;
        seen.add(key);
        const start = worldEdges ? adminProjectPoint(edge[0], edge[1]) : adminGridPoint(edge[0], edge[1]);
        const end = worldEdges ? adminProjectPoint(edge[2], edge[3]) : adminGridPoint(edge[2], edge[3]);
        segments.push(`M${start.x.toFixed(2)} ${start.y.toFixed(2)}L${end.x.toFixed(2)} ${end.y.toFixed(2)}`);
      });
    });
    return segments.join('');
  }

  function adminMapPanLimit(zoom) {
    return Math.max(120, (zoom - 1) * (adminMapSize.width / 2));
  }

  function adminClampMapPan(pan, zoom) {
    const limit = adminMapPanLimit(zoom);
    return {
      x: Math.max(-limit, Math.min(limit, Number(pan.x) || 0)),
      y: Math.max(-limit, Math.min(limit, Number(pan.y) || 0)),
    };
  }

  function adminMapPointFromClient(clientX, clientY) {
    const rect = adminMapSvg.getBoundingClientRect();
    const scale = Math.min(rect.width / adminMapSize.width, rect.height / adminMapSize.height);
    const offsetX = (rect.width - (adminMapSize.width * scale)) / 2;
    const offsetY = (rect.height - (adminMapSize.height * scale)) / 2;
    return {
      x: (clientX - rect.left - offsetX) / scale,
      y: (clientY - rect.top - offsetY) / scale,
    };
  }

  function adminMapCameraPointFromClient(clientX, clientY) {
    const viewportPoint = adminMapPointFromClient(clientX, clientY);
    const centerX = adminMapSize.width / 2;
    const centerY = adminMapSize.height / 2;
    const zoom = Math.max(0.0001, Number(state.adminMapZoom) || 1);
    return {
      x: centerX + ((viewportPoint.x - centerX - state.adminMapPan.x) / zoom),
      y: centerY + ((viewportPoint.y - centerY - state.adminMapPan.y) / zoom),
    };
  }

  function adminMapWorldPointFromClient(clientX, clientY) {
    const mapPoint = adminMapCameraPointFromClient(clientX, clientY);
    const projection = state.adminGeometry && state.adminGeometry.projection;
    const activeProjection = projection && Number(projection.scaleX) > 0 && Number(projection.scaleY) > 0
      ? projection
      : adminDefaultProjection;
    return {
      x: (mapPoint.x - Number(activeProjection.originX)) / Number(activeProjection.scaleX),
      y: (Number(activeProjection.originY) - mapPoint.y) / Number(activeProjection.scaleY),
    };
  }

  function adminDistrictAtClient(clientX, clientY) {
    const point = adminMapWorldPointFromClient(clientX, clientY);
    let selected = null;
    let selectedArea = Number.POSITIVE_INFINITY;
    for (const region of state.adminMapHitRegions) {
      const bounds = region.bounds;
      if (!bounds
        || point.x < Number(bounds.minX)
        || point.x > Number(bounds.maxX)
        || point.y < Number(bounds.minY)
        || point.y > Number(bounds.maxY)) continue;

      if (Array.isArray(region.rects) && region.rects.length > 0) {
        const insideNativeRect = region.rects.some((rect) => point.x >= Number(rect[0])
          && point.x <= Number(rect[2])
          && point.y >= Number(rect[1])
          && point.y <= Number(rect[3]));
        if (!insideNativeRect) continue;
      }

      const area = Math.max(1, (Number(bounds.maxX) - Number(bounds.minX))
        * (Number(bounds.maxY) - Number(bounds.minY)));
      if (area < selectedArea) {
        selected = region.id;
        selectedArea = area;
      }
    }
    return selected;
  }

  function adminMapDisplayScale() {
    if (state.adminMapRasterScale > 0) return state.adminMapRasterScale;
    const rect = adminMapSvg.getBoundingClientRect();
    return Math.max(0.0001, Math.min(rect.width / adminMapSize.width, rect.height / adminMapSize.height));
  }

  function scheduleAdminMapCamera() {
    if (state.adminMapCameraFrame !== null) return;
    state.adminMapCameraFrame = requestAnimationFrame(() => {
      state.adminMapCameraFrame = null;
      applyAdminMapCamera(false);
    });
  }

  function cancelAdminMapCameraFrame() {
    if (state.adminMapCameraFrame === null) return;
    cancelAnimationFrame(state.adminMapCameraFrame);
    state.adminMapCameraFrame = null;
  }

  function syncAdminMapRasterBounds() {
    if (!adminMapRaster) return 0;
    const svgRect = adminMapSvg.getBoundingClientRect();
    const viewportRect = adminMapViewport.getBoundingClientRect();
    if (svgRect.width <= 0 || svgRect.height <= 0) return state.adminMapRasterScale;
    const displayScale = Math.max(0.0001, Math.min(
      svgRect.width / adminMapSize.width,
      svgRect.height / adminMapSize.height,
    ));
    state.adminMapRasterScale = displayScale;
    const size = adminMapSize.width * displayScale;
    adminMapRaster.style.width = `${size}px`;
    adminMapRaster.style.height = `${size}px`;
    adminMapRaster.style.left = `${(svgRect.left - viewportRect.left) + ((svgRect.width - size) / 2)}px`;
    adminMapRaster.style.top = `${(svgRect.top - viewportRect.top) + ((svgRect.height - size) / 2)}px`;
    return displayScale;
  }

  function applyAdminMapCamera(updateControls = true) {
    const zoom = state.adminMapZoom;
    const centerX = adminMapSize.width / 2;
    const centerY = adminMapSize.height / 2;
    const viewportCenterX = adminMapSize.width / 2;
    const viewportCenterY = adminMapSize.height / 2;
    const pan = adminClampMapPan(state.adminMapPan, zoom);
    state.adminMapPan = pan;
    const translateX = viewportCenterX + pan.x - (centerX * zoom);
    const translateY = viewportCenterY + pan.y - (centerY * zoom);
    adminMapCamera.setAttribute('transform', `translate(${translateX} ${translateY}) scale(${zoom})`);
    const displayScale = state.adminMapRasterScale || syncAdminMapRasterBounds();
    if (adminMapRaster) {
      adminMapRaster.style.transform = `translate3d(${pan.x * displayScale}px, ${pan.y * displayScale}px, 0) scale(${zoom})`;
    }
    if (!updateControls) return;
    adminMapZoomLabel.textContent = `%${Math.round(zoom * 100)}`;
    adminMapZoomOut.disabled = zoom <= adminMapZoomMin;
    adminMapZoomIn.disabled = zoom >= adminMapZoomMax;
  }

  function setAdminMapZoom(nextZoom, anchor) {
    const previousZoom = state.adminMapZoom;
    const zoom = Math.max(adminMapZoomMin, Math.min(adminMapZoomMax, Number(nextZoom) || previousZoom));
    if (zoom === previousZoom) return;
    cancelAdminMapCameraFrame();
    const viewportCenter = { x: adminMapSize.width / 2, y: adminMapSize.height / 2 };
    if (anchor && previousZoom > 0) {
      const mapPoint = {
        x: viewportCenter.x + ((anchor.x - viewportCenter.x - state.adminMapPan.x) / previousZoom),
        y: viewportCenter.y + ((anchor.y - viewportCenter.y - state.adminMapPan.y) / previousZoom),
      };
      state.adminMapPan = adminClampMapPan({
        x: anchor.x - viewportCenter.x - ((mapPoint.x - viewportCenter.x) * zoom),
        y: anchor.y - viewportCenter.y - ((mapPoint.y - viewportCenter.y) * zoom),
      }, zoom);
    }
    state.adminMapZoom = zoom;
    applyAdminMapCamera();
  }

  function finishAdminMapPointer(event) {
    const pointer = state.adminMapPointer;
    if (!pointer || pointer.id !== event.pointerId) return;
    if (typeof adminMapViewport.hasPointerCapture === 'function'
      && adminMapViewport.hasPointerCapture(event.pointerId)
      && typeof adminMapViewport.releasePointerCapture === 'function') {
      adminMapViewport.releasePointerCapture(event.pointerId);
    }
    state.adminMapPointer = null;
    adminMapViewport.classList.remove('is-dragging');
    if (pointer.moved) {
      state.adminMapSuppressClick = true;
      window.setTimeout(() => { state.adminMapSuppressClick = false; }, 250);
    }
  }

  function startAdminMapPointer(event) {
    const target = event.target instanceof Element ? event.target : null;
    if (event.button !== 0 || !event.ctrlKey || (target && target.closest('.admin-map-tools'))) return;
    state.adminMapPointer = {
      id: event.pointerId,
      startX: event.clientX,
      startY: event.clientY,
      lastX: event.clientX,
      lastY: event.clientY,
      scale: adminMapDisplayScale(),
      moved: false,
    };
    if (typeof adminMapViewport.setPointerCapture === 'function') {
      adminMapViewport.setPointerCapture(event.pointerId);
    }
    adminMapViewport.classList.add('is-dragging');
    event.preventDefault();
  }

  function moveAdminMapPointer(event) {
    const pointer = state.adminMapPointer;
    if (!pointer || pointer.id !== event.pointerId) return;
    const dx = event.clientX - pointer.lastX;
    const dy = event.clientY - pointer.lastY;
    if (Math.abs(event.clientX - pointer.startX) > adminMapDragThreshold
      || Math.abs(event.clientY - pointer.startY) > adminMapDragThreshold) pointer.moved = true;
    const scale = pointer.scale || adminMapDisplayScale();
    if (dx || dy) {
      state.adminMapPan = adminClampMapPan({
        x: state.adminMapPan.x + (dx / scale),
        y: state.adminMapPan.y + (dy / scale),
      }, state.adminMapZoom);
      scheduleAdminMapCamera();
    }
    pointer.lastX = event.clientX;
    pointer.lastY = event.clientY;
    event.preventDefault();
  }

  function adminDistrictState(district) {
    const stateValue = district && district.state ? district.state : {};
    const assigned = district && district.assignment === 'ASSIGNED';
    if (!assigned) return 'unassigned';
    return stateValue.powered === false ? 'offline' : 'online';
  }

  function adminStatusCopy(status) {
    if (status === 'offline') return { label: 'KESİNTİ', value: 'ENERJİ YOK' };
    if (status === 'unassigned') return { label: 'ATAMA YOK', value: 'İZLENMİYOR' };
    return { label: 'ENERJİ AKTİF', value: 'ÇALIŞIYOR' };
  }

  function adminCategoryCopy(category) {
    const labels = {
      los_santos: 'LOS SANTOS',
      wilderness: 'YABANIL BÖLGE',
      water: 'SU ALANI',
      restricted: 'KISITLI ALAN',
      native: 'OYUN BÖLGESİ',
    };
    return labels[String(category || '').toLowerCase()] || category || 'BÖLGE';
  }

  function adminStateCopy(value) {
    const normalized = String(value || '').toUpperCase();
    if (normalized === 'ONLINE') return 'ÇALIŞIYOR';
    if (normalized === 'OFFLINE') return 'ENERJİ YOK';
    return value || '—';
  }

  function selectedAdminDistrict() {
    return adminDisplayDistricts().find((district) => district.id === state.adminDistrict) || null;
  }

  function renderAdminInspector(district) {
    if (!district) {
      adminInspectorTitle.textContent = 'Bölge seçin';
      adminInspectorCopy.textContent = 'Harita üzerindeki bir bölgeye tıklayarak canlı altyapı durumunu görüntüleyin.';
      adminInspectorStatusLabel.textContent = 'BEKLEMEDE';
      adminInspectorStatusValue.textContent = '—';
      adminInspectorStatus.classList.remove('is-offline');
      adminInspectorDot.className = 'legend-dot is-online';
      adminInspectorGrid.textContent = '—';
      adminInspectorAssignment.textContent = '—';
      adminInspectorLevel.textContent = '—';
      adminInspectorRevision.textContent = '—';
      adminInspectorBounds.textContent = '—';
      adminInspectorList.replaceChildren();
      return;
    }

    const status = adminDistrictState(district);
    const copy = adminStatusCopy(status);
    const districtState = district.state || {};
    const level = Math.max(0, Math.min(1, Number(districtState.level) || 0));
    adminInspectorTitle.textContent = district.label || district.id;
    adminInspectorCopy.textContent = `${district.id} / ${adminCategoryCopy(district.category)} bölgesinin canlı enerji görünümü.`;
    adminInspectorStatusLabel.textContent = copy.label;
    adminInspectorStatusValue.textContent = copy.value;
    adminInspectorStatus.classList.toggle('is-offline', status === 'offline');
    adminInspectorDot.className = `legend-dot ${status === 'offline' ? 'is-offline' : status === 'unassigned' ? 'is-unassigned' : 'is-online'}`;
    adminInspectorGrid.textContent = district.grid || 'ATANMAMIŞ';
    adminInspectorAssignment.textContent = district.assignment === 'ASSIGNED' ? 'ATANMIŞ' : 'ATANMAMIŞ';
    adminInspectorLevel.textContent = `${Math.round(level * 100)}%`;
    adminInspectorRevision.textContent = String(Number(districtState.revision) || 0).padStart(4, '0');

    const bounds = adminDistrictBounds(district);
    adminInspectorBounds.textContent = `X ${Math.round(bounds.minX || 0)} … ${Math.round(bounds.maxX || 0)}  /  Y ${Math.round(bounds.minY || 0)} … ${Math.round(bounds.maxY || 0)}`;
    adminInspectorList.replaceChildren();
    [
      ['BÖLGE KODU', district.id],
      ['KATEGORİ', adminCategoryCopy(district.category)],
      ['DURUM KODU', adminStateCopy(districtState.status)],
    ].forEach(([label, value]) => {
      const row = document.createElement('span');
      const rowLabel = document.createElement('span');
      rowLabel.textContent = label;
      const rowValue = document.createElement('strong');
      rowValue.textContent = value;
      row.append(rowLabel, rowValue);
      adminInspectorList.append(row);
    });
  }

  function renderAdminMap() {
    adminMapZones.replaceChildren();
    adminMapMarkers.replaceChildren();
    const districts = adminDisplayDistricts();
    adminDistrictCount.textContent = String(districts.length).padStart(2, '0');
    if (adminMapBoundaries) adminMapBoundaries.setAttribute('d', adminNativeBoundaryPath());
    state.adminMapHitRegions = districts.map((district) => ({
      id: district.id,
      bounds: adminDistrictBounds(district),
      rects: (adminDistrictGeometry(district) || {}).rects || null,
    }));

    districts.forEach((district) => {
      const bounds = adminDistrictBounds(district);
      const topLeft = adminProjectPoint(bounds.minX, bounds.maxY);
      const bottomRight = adminProjectPoint(bounds.maxX, bounds.minY);
      const width = Math.max(16, Math.min(adminMapSize.width, bottomRight.x - topLeft.x));
      const height = Math.max(12, Math.min(adminMapSize.height, bottomRight.y - topLeft.y));
      const center = { x: topLeft.x + width / 2, y: topLeft.y + height / 2 };
      const status = adminDistrictState(district);
      const group = document.createElementNS('http://www.w3.org/2000/svg', 'g');
      group.classList.add('admin-zone');
      if (status === 'offline') group.classList.add('is-offline');
      if (status === 'unassigned') group.classList.add('is-unassigned');
      if (state.adminDistrict === district.id) group.classList.add('is-selected');
      group.dataset.districtId = district.id;
      group.setAttribute('role', 'button');
      group.setAttribute('tabindex', '0');
      group.setAttribute('aria-label', `${district.label || district.id} bölgesini seç`);
      group.setAttribute('aria-pressed', state.adminDistrict === district.id ? 'true' : 'false');

      const shape = document.createElementNS('http://www.w3.org/2000/svg', 'rect');
      shape.classList.add('admin-zone__hit');
      shape.setAttribute('x', String(topLeft.x));
      shape.setAttribute('y', String(topLeft.y));
      shape.setAttribute('width', String(width));
      shape.setAttribute('height', String(height));
      shape.setAttribute('rx', '3');

      const label = document.createElementNS('http://www.w3.org/2000/svg', 'text');
      label.classList.add('admin-zone__label');
      label.setAttribute('x', String(center.x));
      label.setAttribute('y', String(center.y + 3));
      label.textContent = state.adminDistrict === district.id ? (district.label || district.id) : '';

      const select = () => {
        if (state.adminMapSuppressClick) return;
        selectAdminDistrict(district.id);
      };
      group.addEventListener('click', select);
      group.addEventListener('keydown', (event) => {
        if (event.key === 'Enter' || event.key === ' ') {
          event.preventDefault();
          select();
        }
      });
      group.append(shape);
      group.append(label);
      adminMapZones.append(group);
    });

    districts.forEach((district) => {
      const bounds = adminDistrictBounds(district);
      const topLeft = adminProjectPoint(bounds.minX, bounds.maxY);
      const bottomRight = adminProjectPoint(bounds.maxX, bounds.minY);
      const marker = document.createElementNS('http://www.w3.org/2000/svg', 'circle');
      const status = adminDistrictState(district);
      marker.classList.add('admin-marker', 'admin-marker--district');
      if (status === 'offline') marker.classList.add('is-offline');
      if (status === 'unassigned') marker.classList.add('is-unassigned');
      if (state.adminDistrict === district.id) marker.classList.add('is-selected');
      marker.setAttribute('cx', String((topLeft.x + bottomRight.x) / 2));
      marker.setAttribute('cy', String((topLeft.y + bottomRight.y) / 2));
      marker.setAttribute('r', state.adminDistrict === district.id ? '7' : '3.5');
      adminMapMarkers.append(marker);
    });
    applyAdminMapCamera();
  }

  function selectAdminDistrict(id) {
    state.adminDistrict = id;
    renderAdminMap();
    renderAdminInspector(selectedAdminDistrict());
  }

  function runAdminRegionCommand(command, actionLabel) {
    if (!state.adminToken || !command || state.adminRegionBusy) return;
    const token = state.adminToken;
    state.adminRegionBusy = true;
    adminCommandStatus.classList.remove('is-error');
    adminCommandStatus.textContent = `${actionLabel} sunucuya gönderiliyor…`;
    renderAdminRegionActions();
    post('adminCommand', { token, command, args: [] }).finally(() => {
      window.setTimeout(() => {
        if (state.adminToken !== token) return;
        state.adminRegionBusy = false;
        renderAdminRegionActions();
      }, 1500);
    });
  }

  function renderAdminRegionActions() {
    if (!adminRegionActions) return;
    adminRegionActions.replaceChildren();
    const regions = Array.isArray(state.adminSnapshot.regions) ? state.adminSnapshot.regions : [];
    regions.forEach((region) => {
      const row = document.createElement('div');
      row.className = `admin-region-action${region.active ? ' is-active' : ''}`;
      const copy = document.createElement('div');
      copy.className = 'admin-region-action__copy';
      const title = document.createElement('strong');
      title.textContent = region.label || region.id;
      const detail = document.createElement('small');
      detail.textContent = `${Number(region.districtCount) || 0} district${region.active ? ' / KESİK' : ''}`;
      copy.append(title, detail);

      const buttons = document.createElement('div');
      buttons.className = 'admin-region-action__buttons';
      const blackout = document.createElement('button');
      blackout.type = 'button';
      blackout.className = 'admin-region-action__button admin-region-action__button--cut';
      blackout.textContent = 'KES';
      blackout.title = `${region.label || region.id} elektriğini kes`;
      blackout.setAttribute('aria-label', `${region.label || region.id} elektriğini kes`);
      blackout.disabled = state.adminRegionBusy || region.active === true;
      blackout.addEventListener('click', () => runAdminRegionCommand(region.blackoutCommand, `${region.label || region.id} kesintisi`));

      const restore = document.createElement('button');
      restore.type = 'button';
      restore.className = 'admin-region-action__button admin-region-action__button--restore';
      restore.textContent = 'AÇ';
      restore.title = `${region.label || region.id} elektriğini geri ver`;
      restore.setAttribute('aria-label', `${region.label || region.id} elektriğini geri ver`);
      restore.disabled = state.adminRegionBusy || region.active !== true;
      restore.addEventListener('click', () => runAdminRegionCommand(region.restoreCommand, `${region.label || region.id} geri verme işlemi`));

      buttons.append(blackout, restore);
      row.append(copy, buttons);
      adminRegionActions.append(row);
    });
  }

  function renderAdminCommands() {
    adminCommandList.replaceChildren();
    const commands = Array.isArray(state.adminSnapshot.commands) ? state.adminSnapshot.commands : [];
    commands.forEach((command, index) => {
      const button = document.createElement('button');
      button.type = 'button';
      button.className = `admin-command-item${state.adminCommand === index ? ' is-selected' : ''}`;
      button.dataset.commandIndex = String(index);
      button.setAttribute('role', 'option');
      button.setAttribute('aria-selected', state.adminCommand === index ? 'true' : 'false');
      const number = document.createElement('span');
      number.className = 'admin-command-item__index';
      number.textContent = String(index + 1).padStart(2, '0');
      const copy = document.createElement('span');
      copy.className = 'admin-command-item__copy';
      const label = document.createElement('strong');
      label.textContent = command.label || command.command;
      const code = document.createElement('code');
      code.textContent = `/${command.command}`;
      copy.append(label, code);
      const arrow = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
      arrow.setAttribute('viewBox', '0 0 24 24');
      arrow.setAttribute('aria-hidden', 'true');
      arrow.innerHTML = '<path d="M5 12h13M13 6l6 6-6 6"/>';
      button.append(number, copy, arrow);
      button.addEventListener('click', () => selectAdminCommand(index));
      adminCommandList.append(button);
    });
  }

  function renderAdminCommandForm() {
    const command = state.adminSnapshot.commands[state.adminCommand];
    adminCommandFields.replaceChildren();
    if (!command) {
      adminCommandTitle.textContent = 'Komut seçin';
      adminCommandDescription.textContent = 'Sol taraftan bir yönetici işlemi seçin.';
      adminCommandCode.textContent = '—';
      adminCommandSubmit.disabled = true;
      return;
    }

    adminCommandTitle.textContent = command.label || command.command;
    adminCommandDescription.textContent = command.description || 'Yönetici işlemini güvenli şekilde çalıştırın.';
    adminCommandCode.textContent = `/${command.command}`;
    (command.args || []).forEach((argument, index) => {
      const field = document.createElement('label');
      field.className = 'admin-command-field';
      const fieldLabel = document.createElement('span');
      fieldLabel.textContent = argument.label || argument.key || `Parametre ${index + 1}`;
      const input = document.createElement('input');
      input.type = 'text';
      input.name = argument.key || `arg${index + 1}`;
      input.placeholder = argument.placeholder || '';
      input.autocomplete = 'off';
      input.dataset.argumentIndex = String(index);
      field.append(fieldLabel, input);
      adminCommandFields.append(field);
    });
    adminCommandSubmit.disabled = false;
  }

  function selectAdminCommand(index) {
    state.adminCommand = index;
    renderAdminCommands();
    renderAdminCommandForm();
    adminCommandStatus.classList.remove('is-error');
    adminCommandStatus.textContent = 'Hazır.';
  }

  function renderAdminSnapshot(data) {
    state.adminSnapshot = {
      districts: Array.isArray(data.districts) ? data.districts : [],
      commands: Array.isArray(data.commands) ? data.commands : [],
      regions: Array.isArray(data.regions) ? data.regions : [],
    };
    adminTitle.textContent = data.title || 'Yönetici Kontrol Merkezi';
    adminSubtitle.textContent = data.subtitle || 'Şehir altyapısı için canlı yönetim yüzeyi';
    adminLiveState.textContent = 'CANLI VERİ';
    adminDistrictCount.textContent = String(state.adminSnapshot.districts.length).padStart(2, '0');
    adminCommandCount.textContent = String(state.adminSnapshot.commands.length).padStart(2, '0');
    if (!state.adminSnapshot.districts.some((district) => district.id === state.adminDistrict)) {
      state.adminDistrict = state.adminSnapshot.districts[0] ? state.adminSnapshot.districts[0].id : null;
    }
    if (!Number.isInteger(state.adminCommand) || !state.adminSnapshot.commands[state.adminCommand]) state.adminCommand = 0;
    renderAdminMap();
    renderAdminInspector(selectedAdminDistrict());
    renderAdminRegionActions();
    renderAdminCommands();
    renderAdminCommandForm();
    const revisions = state.adminSnapshot.districts.map((district) => Number(district.state && district.state.revision) || 0);
    const latestRevision = revisions.length ? Math.max(...revisions) : 0;
    adminMapUpdated.textContent = latestRevision ? `REVİZYON ${String(latestRevision).padStart(4, '0')}` : 'REVİZYON BEKLENİYOR';
  }

  function switchAdminTab(name, focusButton) {
    if (!adminTabPanels[name]) return;
    state.adminTab = name;
    adminTabButtons.forEach((button) => {
      const active = button.dataset.adminTab === name;
      button.classList.toggle('is-active', active);
      button.setAttribute('aria-selected', active ? 'true' : 'false');
      button.tabIndex = active ? 0 : -1;
      if (active && focusButton) button.focus();
    });
    Object.entries(adminTabPanels).forEach(([key, panel]) => {
      const active = key === name;
      panel.hidden = !active;
      panel.classList.toggle('is-active', active);
    });
  }

  function openAdmin(data) {
    closeMenu(false);
    closeProgressView(false);
    clearSkillState();
    state.adminToken = data.token ? String(data.token) : null;
    state.adminTab = 'map';
    state.adminMapZoom = adminMapZoomMin;
    state.adminMapPan = { x: 0, y: 0 };
    state.adminMapPointer = null;
    state.adminMapSuppressClick = false;
    state.adminMapRasterScale = 0;
    state.adminRegionBusy = false;
    renderAdminSnapshot(data);
    switchAdminTab('map', false);
    show(admin);
    syncVisibility();
    loadAdminGeometry().then(() => {
      if (!state.adminToken) return;
      renderAdminMap();
      renderAdminInspector(selectedAdminDistrict());
    });
    requestAnimationFrame(() => document.getElementById('admin-tab-map-button').focus());
  }

  function closeAdminView(notifyLua) {
    const token = state.adminToken;
    state.adminToken = null;
    cancelAdminMapCameraFrame();
    state.adminMapRasterScale = 0;
    state.adminMapHitRegions = [];
    hide(admin);
    if (notifyLua && token) post('adminClose', { token });
    syncVisibility();
  }

  function refreshAdmin() {
    if (!state.adminToken) return;
    adminLiveState.textContent = 'YENİLENİYOR…';
    post('adminRefresh', { token: state.adminToken });
  }

  function submitAdminCommand(event) {
    event.preventDefault();
    const command = state.adminSnapshot.commands[state.adminCommand];
    if (!state.adminToken || !command) return;
    const args = [...adminCommandFields.querySelectorAll('input')].map((input) => input.value.trim());
    if (args.some((value) => !value)) {
      adminCommandStatus.classList.add('is-error');
      adminCommandStatus.textContent = 'Gerekli parametreleri doldurun.';
      const firstEmpty = [...adminCommandFields.querySelectorAll('input')].find((input) => !input.value.trim());
      if (firstEmpty) firstEmpty.focus();
      return;
    }
    const token = state.adminToken;
    adminCommandSubmit.disabled = true;
    adminCommandStatus.classList.remove('is-error');
    adminCommandStatus.textContent = 'Komut sunucuya gönderiliyor…';
    post('adminCommand', { token, command: command.command, args }).finally(() => {
      window.setTimeout(() => {
        if (state.adminToken === token) adminCommandSubmit.disabled = false;
      }, 1500);
    });
  }

  function updateLinkStatus(data) {
    const unstable = data && (data.unstable === true || data.linkUnstable === true || data.powered === false);
    const nextState = unstable ? 'KARARSIZ' : 'KARARLI';
    linkStatus.classList.toggle('is-unstable', unstable);
    linkStatus.dataset.state = unstable ? 'unstable' : 'stable';
    linkStatus.setAttribute('aria-label', `BAĞLANTI ${nextState}`);
    linkState.textContent = nextState;
  }

  function iconMarkup(icon) {
    const parts = String(icon || '').trim().split(/\s+/);
    const rawKey = parts[parts.length - 1] || 'default';
    const key = rawKey.startsWith('fa-') ? rawKey.slice(3) : rawKey;
    return `<svg viewBox="0 0 24 24" aria-hidden="true">${iconPaths[key] || iconPaths.default}</svg>`;
  }

  function allowedTone(tone) {
    return ['warning', 'danger', 'safe'].includes(tone) ? tone : '';
  }

  function optionDescription(option) {
    if (option.description) return String(option.description);
    if (option.tone === 'danger') return 'Yüksek etkili müdahale. İşlem geri alınamaz.';
    if (option.tone === 'safe') return 'Hasar planını başlatır ve sistemi hatta döndürür.';
    return 'Operasyon panelinden işlemi başlatın.';
  }

  function createMenuOption(option, fallbackIndex) {
    const index = Number.isInteger(Number(option.index)) ? Number(option.index) : fallbackIndex;
    const tone = allowedTone(option.tone);
    const button = document.createElement('button');
    button.type = 'button';
    button.className = `menu-option${tone ? ` tone-${tone}` : ''}`;
    button.dataset.index = String(index);
    button.disabled = option.disabled === true;

    const key = document.createElement('span');
    key.className = 'option-key';
    key.textContent = String(index).padStart(2, '0');

    const icon = document.createElement('span');
    icon.className = 'option-icon';
    icon.innerHTML = iconMarkup(option.icon);

    const copy = document.createElement('span');
    copy.className = 'option-copy';
    const label = document.createElement('span');
    label.className = 'option-label';
    label.textContent = option.label || 'Seçenek';
    const description = document.createElement('span');
    description.className = 'option-description';
    description.textContent = optionDescription(option);
    copy.append(label, description);

    const arrow = document.createElement('span');
    arrow.className = 'option-arrow';
    arrow.setAttribute('aria-hidden', 'true');
    arrow.textContent = '›';

    button.append(key, icon, copy, arrow);
    button.addEventListener('click', () => selectMenuOption(index));
    return button;
  }

  function openMenu(data) {
    hide(progress);
    hide(skill);
    if (Object.prototype.hasOwnProperty.call(data, 'linkUnstable')) updateLinkStatus(data);
    state.menuToken = data.token ? String(data.token) : null;
    state.menuBusy = false;
    menuTitle.textContent = data.title || 'Trafo operasyonu';
    menuSubtitle.textContent = data.subtitle || 'Operasyon seçin';
    const options = Array.isArray(data.options) ? data.options : [];
    menuCount.textContent = `${String(options.length).padStart(2, '0')} MEVCUT`;
    menuOptions.replaceChildren(...options.map((option, index) => createMenuOption(option || {}, index + 1)));
    show(menu);
    syncVisibility();
    const first = menuOptions.querySelector('button:not(:disabled)');
    if (first) requestAnimationFrame(() => first.focus());
  }

  function closeMenu(notifyLua) {
    const token = state.menuToken;
    state.menuToken = null;
    state.menuBusy = false;
    hide(menu);
    if (notifyLua && token) post('menuClose', { token });
    syncVisibility();
  }

  function selectMenuOption(index) {
    if (!state.menuToken || state.menuBusy) return;
    const token = state.menuToken;
    const button = [...menuOptions.querySelectorAll('button')].find((item) => Number(item.dataset.index) === index);
    if (!button || button.disabled) return;
    state.menuBusy = true;
    menuOptions.querySelectorAll('button').forEach((item) => { item.disabled = true; });
    closeMenu(false);
    post('menuSelect', { token, index });
  }

  function moveMenuFocus(direction) {
    const buttons = [...menuOptions.querySelectorAll('button:not(:disabled)')];
    if (!buttons.length) return;
    const current = buttons.indexOf(document.activeElement);
    const next = current < 0 ? 0 : (current + direction + buttons.length) % buttons.length;
    buttons[next].focus();
  }

  function closeProgressView(notifyLua) {
    const token = state.progressToken;
    if (state.progressTimer) clearTimeout(state.progressTimer);
    if (state.progressFrame) cancelAnimationFrame(state.progressFrame);
    state.progressToken = null;
    state.progressTimer = null;
    state.progressFrame = null;
    hide(progress);
    if (notifyLua && token) post('progressCancel', { token });
    syncVisibility();
  }

  function progressVariant(variant) {
    return variant === 'repair' ? 'TAMİR PROTOKOLÜ' : 'İŞLEM SÜRÜYOR';
  }

  function updateProgress(now) {
    if (!state.progressToken) return;
    const elapsed = Math.max(0, now - state.progressStartedAt);
    const ratio = state.progressDuration > 0 ? Math.min(1, elapsed / state.progressDuration) : 1;
    const percent = Math.round(ratio * 100);
    progressFill.style.width = `${percent}%`;
    progressPercent.textContent = `${String(percent).padStart(2, '0')}%`;
    if (ratio >= 1) {
      const token = state.progressToken;
      closeProgressView(false);
      post('progressComplete', { token });
      return;
    }
    state.progressFrame = requestAnimationFrame(updateProgress);
  }

  function startProgress(data) {
    closeProgressView(false);
    hide(menu);
    hide(skill);
    state.progressToken = data.token ? String(data.token) : null;
    state.progressDuration = Math.max(0, Number(data.duration) || 0);
    state.progressStartedAt = performance.now();
    state.progressCanCancel = data.canCancel !== false;
    progressLabel.textContent = data.label || 'İşlem sürüyor';
    progressStage.textContent = data.stage || 'Sistem yanıtı bekleniyor';
    progressKicker.innerHTML = `<span class="status-dot status-dot--amber"></span> ${progressVariant(data.variant)}`;
    const stageIndex = Number(data.stageIndex);
    const totalStages = Number(data.totalStages);
    progressStep.textContent = Number.isFinite(stageIndex) && Number.isFinite(totalStages)
      ? `${String(stageIndex).padStart(2, '0')} / ${String(totalStages).padStart(2, '0')}`
      : '-- / --';
    progressCancelButton.classList.toggle('hidden-control', !state.progressCanCancel);
    show(progress);
    syncVisibility();
    state.progressFrame = requestAnimationFrame(updateProgress);
    state.progressTimer = setTimeout(() => {
      if (state.progressToken) updateProgress(performance.now());
    }, state.progressDuration + 80);
  }

  function cancelProgress() {
    if (!state.progressToken || !state.progressCanCancel) return;
    const token = state.progressToken;
    closeProgressView(false);
    post('progressCancel', { token });
  }

  function clearSkillState() {
    if (state.skillFrame) cancelAnimationFrame(state.skillFrame);
    state.skillFrame = null;
    state.skillToken = null;
    state.skillStages = [];
    state.skillInputs = [];
    state.skillExpected = null;
    state.skillDeadline = 0;
    hide(skill);
    syncVisibility();
  }

  function skillWindow(level) {
    if (String(level).toLowerCase() === 'hard') return 720;
    if (String(level).toLowerCase() === 'medium') return 930;
    return 1250;
  }

  function finishSkill(success) {
    if (!state.skillToken) return;
    const token = state.skillToken;
    clearSkillState();
    post('skillResult', { token, success: success === true });
  }

  function updateSkill(now) {
    if (!state.skillToken) return;
    const remaining = Math.max(0, state.skillDeadline - now);
    const ratio = state.skillWindow > 0 ? remaining / state.skillWindow : 0;
    skillTimeFill.style.width = `${Math.round(ratio * 100)}%`;
    skillTimer.textContent = `${(remaining / 1000).toFixed(1).replace('.', ',')} sn`;
    if (remaining <= 0) {
      finishSkill(false);
      return;
    }
    state.skillFrame = requestAnimationFrame(updateSkill);
  }

  function renderSkillStage() {
    const level = state.skillStages[state.skillIndex] || 'easy';
    state.skillWindow = skillWindow(level);
    state.skillExpected = state.skillInputs[Math.floor(Math.random() * state.skillInputs.length)] || 'e';
    state.skillDeadline = performance.now() + state.skillWindow;
    skillStage.textContent = `${String(state.skillIndex + 1).padStart(2, '0')} / ${String(state.skillStages.length).padStart(2, '0')}`;
    skillKey.textContent = state.skillExpected.toUpperCase();
    skillKeyLabel.textContent = `${state.skillExpected.toUpperCase()} TUŞU`;
    skillLabel.textContent = level === 'hard' ? 'Pencere daralıyor. Hızlı tepki verin.' : 'Doğru tuşa zamanında basın.';
    if (state.skillFrame) cancelAnimationFrame(state.skillFrame);
    state.skillFrame = requestAnimationFrame(updateSkill);
  }

  function startSkill(data) {
    clearSkillState();
    hide(menu);
    hide(progress);
    state.skillToken = data.token ? String(data.token) : null;
    state.skillStages = Array.isArray(data.difficulty) && data.difficulty.length ? data.difficulty : ['easy'];
    state.skillInputs = (Array.isArray(data.inputs) ? data.inputs : ['e'])
      .map((input) => String(input).toLowerCase())
      .filter((input) => input.length === 1);
    if (!state.skillInputs.length) state.skillInputs = ['e'];
    state.skillIndex = 0;
    skillTitle.textContent = data.title || 'Güvenlik doğrulaması';
    show(skill);
    syncVisibility();
    renderSkillStage();
  }

  function normalizeNoticeType(type) {
    if (type === 'inform') return 'info';
    return ['success', 'warning', 'error'].includes(type) ? type : 'info';
  }

  function notify(data) {
    const type = normalizeNoticeType(data.type);
    const notice = document.createElement('article');
    notice.className = `notice ${type}`;
    const marker = document.createElement('span');
    marker.setAttribute('aria-hidden', 'true');
    const copy = document.createElement('span');
    copy.className = 'notice-copy';
    const title = document.createElement('span');
    title.className = 'notice-title';
    const noticeTitles = {
      info: 'BİLGİ',
      success: 'BAŞARILI',
      warning: 'UYARI',
      error: 'SİSTEM UYARISI',
    };
    title.textContent = noticeTitles[type] || 'BİLDİRİM';
    const message = document.createElement('span');
    message.className = 'notice-message';
    message.textContent = data.message || '';
    copy.append(title, message);
    notice.append(marker, copy);
    notifications.appendChild(notice);
    syncVisibility();
    setTimeout(() => {
      notice.remove();
      syncVisibility();
    }, 4800);
  }

  function closeAll() {
    closeAdminView(false);
    closeMenu(false);
    closeProgressView(false);
    clearSkillState();
  }

  adminCloseButton.addEventListener('click', () => closeAdminView(true));
  adminRefreshButton.addEventListener('click', refreshAdmin);
  adminMapZoomIn.addEventListener('click', () => setAdminMapZoom(state.adminMapZoom * 1.25));
  adminMapZoomOut.addEventListener('click', () => setAdminMapZoom(state.adminMapZoom / 1.25));
  adminMapReset.addEventListener('click', () => {
    cancelAdminMapCameraFrame();
    state.adminMapZoom = adminMapZoomMin;
    state.adminMapPan = { x: 0, y: 0 };
    applyAdminMapCamera();
  });
  adminMapViewport.addEventListener('pointerdown', startAdminMapPointer);
  adminMapViewport.addEventListener('pointermove', moveAdminMapPointer);
  adminMapViewport.addEventListener('pointerup', finishAdminMapPointer);
  adminMapViewport.addEventListener('pointercancel', finishAdminMapPointer);
  window.addEventListener('resize', () => {
    if (!state.adminToken) return;
    syncAdminMapRasterBounds();
    applyAdminMapCamera();
  });
  adminMapViewport.addEventListener('click', (event) => {
    const target = event.target instanceof Element ? event.target : null;
    if (state.adminMapSuppressClick) {
      state.adminMapSuppressClick = false;
      if (target && target.closest('.admin-map-tools')) return;
      event.preventDefault();
      event.stopPropagation();
      return;
    }
    if (target && target.closest('.admin-map-tools')) return;
    if (event.detail === 0) return;
    const districtId = adminDistrictAtClient(event.clientX, event.clientY);
    if (!districtId) return;
    event.preventDefault();
    event.stopPropagation();
    selectAdminDistrict(districtId);
  }, true);
  adminMapViewport.addEventListener('wheel', (event) => {
    if (!state.adminToken || event.target.closest('.admin-map-tools')) return;
    event.preventDefault();
    const anchor = adminMapPointFromClient(event.clientX, event.clientY);
    const factor = Math.exp(-Math.max(-240, Math.min(240, event.deltaY)) * 0.0015);
    setAdminMapZoom(state.adminMapZoom * factor, anchor);
  }, { passive: false });
  adminCommandForm.addEventListener('submit', submitAdminCommand);
  adminTabButtons.forEach((button, index) => {
    button.addEventListener('click', () => switchAdminTab(button.dataset.adminTab, false));
    button.addEventListener('keydown', (event) => {
      if (event.key !== 'ArrowLeft' && event.key !== 'ArrowRight' && event.key !== 'ArrowUp' && event.key !== 'ArrowDown') return;
      event.preventDefault();
      const nextIndex = (index + (event.key === 'ArrowLeft' || event.key === 'ArrowUp' ? -1 : 1) + adminTabButtons.length) % adminTabButtons.length;
      switchAdminTab(adminTabButtons[nextIndex].dataset.adminTab, true);
    });
  });
  document.getElementById('menu-close').addEventListener('click', () => closeMenu(true));
  progressCancelButton.addEventListener('click', cancelProgress);

  window.addEventListener('keydown', (event) => {
    if (state.adminToken) {
      const editing = event.target && ['INPUT', 'TEXTAREA', 'SELECT'].includes(event.target.tagName);
      if (event.key === 'Escape') {
        event.preventDefault();
        closeAdminView(true);
      } else if (!editing && (event.key === 'ArrowLeft' || event.key === 'ArrowRight' || event.key === 'ArrowUp' || event.key === 'ArrowDown')) {
        event.preventDefault();
        const currentIndex = adminTabButtons.findIndex((button) => button.dataset.adminTab === state.adminTab);
        const nextIndex = (currentIndex + (event.key === 'ArrowLeft' || event.key === 'ArrowUp' ? -1 : 1) + adminTabButtons.length) % adminTabButtons.length;
        switchAdminTab(adminTabButtons[nextIndex].dataset.adminTab, true);
      }
      return;
    }

    if (state.menuToken) {
      if (event.key === 'Escape') {
        event.preventDefault();
        closeMenu(true);
      } else if (event.key === 'ArrowUp') {
        event.preventDefault();
        moveMenuFocus(-1);
      } else if (event.key === 'ArrowDown') {
        event.preventDefault();
        moveMenuFocus(1);
      }
      return;
    }

    if (state.progressToken && event.key === 'Escape' && state.progressCanCancel) {
      event.preventDefault();
      cancelProgress();
      return;
    }

    if (!state.skillToken) return;
    const key = String(event.key || '').toLowerCase();
    if (key === state.skillExpected) {
      event.preventDefault();
      if (state.skillIndex + 1 >= state.skillStages.length) finishSkill(true);
      else {
        state.skillIndex += 1;
        renderSkillStage();
      }
    } else if (state.skillInputs.includes(key)) {
      event.preventDefault();
      finishSkill(false);
    }
  });

  window.addEventListener('message', (event) => {
    const data = event.data || {};
    if (data.action === 'linkStatus') updateLinkStatus(data);
    if (data.action === 'adminOpen') openAdmin(data);
    if (data.action === 'adminData') {
      if (state.adminToken && (!data.token || String(data.token) === state.adminToken)) renderAdminSnapshot(data);
      adminCommandSubmit.disabled = false;
    }
    if (data.action === 'adminClose') closeAdminView(false);
    if (data.action === 'openMenu') openMenu(data);
    if (data.action === 'closeMenu') closeMenu(false);
    if (data.action === 'progress') startProgress(data);
    if (data.action === 'closeProgress') closeProgressView(false);
    if (data.action === 'skillcheck') startSkill(data);
    if (data.action === 'closeSkillcheck') clearSkillState();
    if (data.action === 'closeAll') closeAll();
    if (data.action === 'notify') notify(data);
  });

  // FiveM can keep the browser document alive for a frame during resource
  // restart. Start fully inactive so no stale panel or NUI surface covers the
  // game before the first explicit UI message arrives.
  closeAll();
})();
