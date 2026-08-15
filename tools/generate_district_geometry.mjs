import { readFile, writeFile } from 'node:fs/promises';
import { extname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

export const MAP_PROJECTION = Object.freeze({
  width: 2048,
  height: 2048,
  // Calibrated against the supplied GTA neighborhood map. The previous
  // estimate overstated both scales, which accumulated as a visible
  // north-east drift over the world-coordinate footprint.
  originX: 939,
  originY: 1381,
  scaleX: 0.16425,
  scaleY: 0.16425,
});

export const CODE_ALIASES = Object.freeze({ BANHAMCA: 'BANHAMC' });
export const EXCLUDED_CODES = new Set(['ISHEISTZONE', 'OCEANA', 'PROL']);

// popzone.ipl only carries the native code. These labels keep the map useful
// without making the visual dataset depend on the power registry.
export const DISPLAY_LABELS = Object.freeze({
  AIRP: 'Los Santos International Airport',
  ALAMO: 'Alamo Sea',
  ALTA: 'Alta',
  ARMYB: 'Fort Zancudo',
  BANHAMC: 'Banham Canyon',
  BANNING: 'Banning',
  BAYTRE: 'Baytree Canyon',
  BEACH: 'Vespucci Beach',
  BHAMCA: 'Banham Canyon',
  BRADP: 'Braddock Pass',
  BRADT: 'Braddock Tunnel',
  BURTON: 'Burton',
  CALAFB: 'Calafia Bridge',
  CANNY: 'Raton Canyon',
  CCREAK: 'Cassidy Creek',
  CHAMH: 'Chamberlain Hills',
  CHIL: 'Vinewood Hills',
  CHU: 'Chumash',
  CMSW: 'Chiliad Mountain State Wilderness',
  CYPRE: 'Cypress Flats',
  DAVIS: 'Davis',
  DELBE: 'Del Perro Beach',
  DELPE: 'Del Perro',
  DELSOL: 'La Puerta',
  DESRT: 'Grand Senora Desert',
  DOWNT: 'Downtown',
  DTVINE: 'Downtown Vinewood',
  EAST_V: 'East Vinewood',
  EBURO: 'El Burro Heights',
  ELGORL: 'El Gordo Lighthouse',
  ELYSIAN: 'Elysian Island',
  GALFISH: 'Galilee',
  GALLI: 'Galileo Park',
  GOLF: 'GWC and Golfing Society',
  GRAPES: 'Grapeseed',
  GREATC: 'Great Chaparral',
  HARMO: 'Harmony',
  HAWICK: 'Hawick',
  HORS: 'Vinewood Racetrack',
  HUMLAB: 'Humane Labs and Research',
  JAIL: 'Bolingbroke Penitentiary',
  KOREAT: 'Little Seoul',
  LACT: 'Land Act Reservoir',
  LAGO: 'Lago Zancudo',
  LDAM: 'Land Act Dam',
  LEGSQU: 'Legion Square',
  LMESA: 'La Mesa',
  LOSPUER: 'La Puerta',
  MIRR: 'Mirror Park',
  MORN: 'Morningwood',
  MOVIE: 'Richards Majestic',
  MTCHIL: 'Mount Chiliad',
  MTGORDO: 'Mount Gordo',
  MTJOSE: 'Mount Josiah',
  MURRI: 'Murrieta Heights',
  NCHU: 'North Chumash',
  NOOSE: 'N.O.O.S.E',
  OBSERV: 'Galileo Observatory',
  PALCOV: 'Paleto Cove',
  PALETO: 'Paleto Bay',
  PALFOR: 'Paleto Forest',
  PALHIGH: 'Palomino Highlands',
  PALMPOW: 'Palmer-Taylor Power Station',
  PBLUFF: 'Pacific Bluffs',
  PBOX: 'Pillbox Hill',
  PROCOB: 'Procopio Beach',
  RANCHO: 'Rancho',
  RGLEN: 'Richman Glen',
  RICHM: 'Richman',
  ROCKF: 'Rockford Hills',
  RTRAK: 'Redwood Lights Track',
  SANCHIA: 'San Chianski Mountain Range',
  SANDY: 'Sandy Shores',
  SKID: 'Mission Row',
  SLAB: 'Stab City',
  STAD: 'Maze Bank Arena',
  STRAW: 'Strawberry',
  TATAMO: 'Tataviam Mountains',
  TERMINA: 'Terminal',
  TEXTI: 'Textile City',
  TONGVAH: 'Tongva Hills',
  TONGVAV: 'Tongva Valley',
  VCANA: 'Vespucci Canals',
  VESP: 'Vespucci',
  VINE: 'Vinewood',
  WINDF: 'Ron Alternates Wind Farm',
  WVINE: 'West Vinewood',
  ZANCUDO: 'Zancudo River',
  ZP_ORT: 'Port of South Los Santos',
  ZQ_UAR: 'Davis Quartz',
});

export function finite(value, name = 'coordinate') {
  const number = Number(value);
  if (!Number.isFinite(number)) throw new TypeError(`Invalid ${name}: ${value}`);
  return number;
}

export function normalizeCode(value) {
  const code = String(value || '').trim().toUpperCase();
  return CODE_ALIASES[code] || code;
}

function rectangleFromCoordinates(x1, y1, x2, y2) {
  const minX = Math.min(finite(x1, 'minX'), finite(x2, 'maxX'));
  const minY = Math.min(finite(y1, 'minY'), finite(y2, 'maxY'));
  const maxX = Math.max(finite(x1, 'minX'), finite(x2, 'maxX'));
  const maxY = Math.max(finite(y1, 'minY'), finite(y2, 'maxY'));
  if (maxX <= minX || maxY <= minY) return null;
  return [minX, minY, maxX, maxY];
}

function makeRecord({
  sourceRecordIndex,
  sourceLine = null,
  sourceZone,
  rawCode,
  code,
  rect,
  z1 = null,
  z2 = null,
  label = null,
}) {
  const minZ = z1 === null || z2 === null ? null : Math.min(z1, z2);
  const maxZ = z1 === null || z2 === null ? null : Math.max(z1, z2);
  return {
    sourceRecordIndex,
    sourceLine,
    sourceZone,
    rawCode,
    code,
    rect,
    minZ,
    maxZ,
    zInverted: z1 !== null && z2 !== null && z1 > z2,
    label: label || DISPLAY_LABELS[code] || code,
  };
}

export function parsePopzoneIpl(text) {
  if (typeof text !== 'string') throw new TypeError('popzone.ipl source must be text');

  const records = [];
  let inZoneSection = false;
  let sourceRecordIndex = 0;

  text.split(/\r?\n/).forEach((rawLine, lineIndex) => {
    const line = rawLine.trim();
    if (!line || line.startsWith('#')) return;

    const section = line.toLowerCase();
    if (section === 'zone') {
      inZoneSection = true;
      return;
    }
    if (section === 'end') {
      inZoneSection = false;
      return;
    }
    if (!inZoneSection) return;

    const fields = line.split(',').map((field) => field.trim());
    if (fields.length < 8) {
      throw new TypeError(`Invalid popzone.ipl record at line ${lineIndex + 1}`);
    }

    const [sourceZone, x1, y1, z1, x2, y2, z2, rawCode] = fields;
    const code = normalizeCode(rawCode);
    if (!sourceZone || !code) {
      throw new TypeError(`Missing zone identity at line ${lineIndex + 1}`);
    }

    const rect = rectangleFromCoordinates(x1, y1, x2, y2);
    if (!rect) throw new TypeError(`Invalid rectangle at line ${lineIndex + 1}`);

    sourceRecordIndex += 1;
    records.push(makeRecord({
      sourceRecordIndex,
      sourceLine: lineIndex + 1,
      sourceZone,
      rawCode: String(rawCode).trim(),
      code,
      rect,
      z1: finite(z1, 'minZ'),
      z2: finite(z2, 'maxZ'),
    }));
  });

  if (!records.length) throw new TypeError('popzone.ipl contains no zone records');
  return { format: 'popzone.ipl', records };
}

function rectangleFromBound(bound) {
  const minimum = bound && bound.Minimum;
  const maximum = bound && bound.Maximum;
  if (!minimum || !maximum) return null;
  return rectangleFromCoordinates(minimum.X, minimum.Y, maximum.X, maximum.Y);
}

export function parseZonesJson(source) {
  if (!Array.isArray(source)) throw new TypeError('Zone JSON source must be an array.');

  const records = [];
  let sourceRecordIndex = 0;
  source.forEach((zone, zoneIndex) => {
    const rawCode = String(zone && zone.Name || '').trim();
    const code = normalizeCode(rawCode);
    const bounds = Array.isArray(zone && zone.Bounds) ? zone.Bounds : [];
    bounds.forEach((bound, boundIndex) => {
      const rect = rectangleFromBound(bound);
      if (!rect) return;
      sourceRecordIndex += 1;
      records.push(makeRecord({
        sourceRecordIndex,
        sourceLine: `${zoneIndex + 1}:${boundIndex + 1}`,
        sourceZone: rawCode || `zone-${zoneIndex + 1}`,
        rawCode,
        code,
        rect,
        label: String(zone && zone.DisplayName || DISPLAY_LABELS[code] || code),
      }));
    });
  });

  if (!records.length) throw new TypeError('Zone JSON contains no usable rectangles.');
  return { format: 'zones.json', records };
}

export function parseSourceText(text, sourcePath = '') {
  const extension = extname(sourcePath).toLowerCase();
  const trimmed = String(text || '').trim();
  if (extension === '.ipl' || (trimmed && !trimmed.startsWith('[') && !trimmed.startsWith('{'))) {
    return parsePopzoneIpl(text);
  }
  return parseZonesJson(JSON.parse(text));
}

function uniqueSorted(values) {
  return [...new Set(values)].sort((left, right) => left - right);
}

function mergeSegments(segments) {
  const groups = new Map();
  segments.forEach(([axis, fixed, start, end]) => {
    const key = `${axis}:${fixed}`;
    const current = groups.get(key) || [];
    groups.set(key, [...current, [start, end]]);
  });

  const merged = [];
  groups.forEach((ranges, key) => {
    const [axis, fixedText] = key.split(':');
    const fixed = Number(fixedText);
    const ordered = [...ranges].sort((left, right) => left[0] - right[0] || left[1] - right[1]);
    let [start, end] = ordered[0];
    for (let index = 1; index < ordered.length; index += 1) {
      const [nextStart, nextEnd] = ordered[index];
      if (nextStart <= end) {
        end = Math.max(end, nextEnd);
      } else {
        merged.push(axis === 'h' ? [start, fixed, end, fixed] : [fixed, start, fixed, end]);
        [start, end] = [nextStart, nextEnd];
      }
    }
    merged.push(axis === 'h' ? [start, fixed, end, fixed] : [fixed, start, fixed, end]);
  });
  return merged;
}

export function unionEdges(rectangles) {
  const xs = uniqueSorted(rectangles.flatMap((rect) => [rect[0], rect[2]]));
  const ys = uniqueSorted(rectangles.flatMap((rect) => [rect[1], rect[3]]));
  const covered = Array.from({ length: ys.length - 1 }, () => Array(xs.length - 1).fill(false));

  for (let row = 0; row < ys.length - 1; row += 1) {
    const centerY = (ys[row] + ys[row + 1]) / 2;
    for (let column = 0; column < xs.length - 1; column += 1) {
      const centerX = (xs[column] + xs[column + 1]) / 2;
      covered[row][column] = rectangles.some((rect) => (
        centerX >= rect[0] && centerX <= rect[2] && centerY >= rect[1] && centerY <= rect[3]
      ));
    }
  }

  const segments = [];
  for (let row = 0; row < covered.length; row += 1) {
    for (let column = 0; column < covered[row].length; column += 1) {
      if (!covered[row][column]) continue;
      if (row === 0 || !covered[row - 1][column]) segments.push(['h', ys[row], xs[column], xs[column + 1]]);
      if (row === covered.length - 1 || !covered[row + 1][column]) segments.push(['h', ys[row + 1], xs[column], xs[column + 1]]);
      if (column === 0 || !covered[row][column - 1]) segments.push(['v', xs[column], ys[row], ys[row + 1]]);
      if (column === covered[row].length - 1 || !covered[row][column + 1]) {
        segments.push(['v', xs[column + 1], ys[row], ys[row + 1]]);
      }
    }
  }
  return mergeSegments(segments);
}

function geometryEntry(group) {
  const items = [...group.items].sort((left, right) => (
    left.rect[1] - right.rect[1]
      || left.rect[0] - right.rect[0]
      || left.sourceRecordIndex - right.sourceRecordIndex
  ));
  const rects = items.map((item) => item.rect);
  const worldBounds = {
    minX: Math.min(...rects.map((rect) => rect[0])),
    minY: Math.min(...rects.map((rect) => rect[1])),
    maxX: Math.max(...rects.map((rect) => rect[2])),
    maxY: Math.max(...rects.map((rect) => rect[3])),
  };

  return {
    label: group.label,
    rects,
    edges: unionEdges(rects),
    worldBounds,
    sourceRecordCount: items.length,
    sourceZoneCount: group.sourceZones.size,
    sourceZones: [...group.sourceZones].sort(),
    sourceRecords: items.map((item) => ({
      index: item.sourceRecordIndex,
      line: item.sourceLine,
      zone: item.sourceZone,
      minZ: item.minZ,
      maxZ: item.maxZ,
    })),
  };
}

function countBy(values) {
  const counts = new Map();
  values.forEach((value) => counts.set(value, (counts.get(value) || 0) + 1));
  return Object.fromEntries([...counts.entries()].sort(([left], [right]) => left.localeCompare(right)));
}

export function buildDistrictOutput({ format, records }) {
  const groups = new Map();
  const excludedCodes = [];
  const sourceZoneNames = records.map((record) => record.sourceZone);

  records.forEach((record) => {
    if (EXCLUDED_CODES.has(record.code)) {
      excludedCodes.push(record.code);
      return;
    }

    const current = groups.get(record.code) || {
      label: DISPLAY_LABELS[record.code] || record.label || record.code,
      items: [],
      sourceZones: new Set(),
    };
    groups.set(record.code, {
      ...current,
      items: [...current.items, record],
      sourceZones: new Set([...current.sourceZones, record.sourceZone]),
    });
  });

  const districts = Object.fromEntries(
    [...groups.entries()]
      .sort(([left], [right]) => left.localeCompare(right))
      .map(([code, group]) => [code, geometryEntry(group)]),
  );
  const entries = Object.values(districts);
  const bounds = {
    minX: Math.min(...entries.map((entry) => entry.worldBounds.minX)),
    minY: Math.min(...entries.map((entry) => entry.worldBounds.minY)),
    maxX: Math.max(...entries.map((entry) => entry.worldBounds.maxX)),
    maxY: Math.max(...entries.map((entry) => entry.worldBounds.maxY)),
  };
  const duplicateSourceZoneNames = Object.fromEntries(
    Object.entries(countBy(sourceZoneNames)).filter(([, count]) => count > 1),
  );

  return {
    version: 3,
    format: 'world-rects',
    source: format === 'popzone.ipl' ? 'popzone.ipl' : 'zones.json',
    sourceFormat: format,
    sourceReference: format === 'popzone.ipl'
      ? 'popzone.ipl / zone rectangle source'
      : 'DurtyFree gta-v-data-dumps zones.json converted to world rectangles',
    verticalMode: 'two-dimensional-footprint',
    projection: MAP_PROJECTION,
    bounds,
    sourceStats: {
      records: records.length,
      distinctCodes: new Set(records.map((record) => record.code)).size,
      includedRecords: records.length - excludedCodes.length,
      includedDistricts: Object.keys(districts).length,
      excludedRecords: excludedCodes.length,
      excludedCodes: countBy(excludedCodes),
      invertedZRecords: records.filter((record) => record.zInverted).length,
      duplicateSourceZoneNames,
      aliases: CODE_ALIASES,
    },
    districts,
  };
}

export async function generateDistrictGeometry(inputArgument, outputArgument) {
  if (!inputArgument || !outputArgument) {
    throw new Error('Usage: node tools/generate_district_geometry.mjs <popzone.ipl|zones.json> <output.json>');
  }

  const sourcePath = resolve(inputArgument);
  const outputPath = resolve(outputArgument);
  const sourceText = await readFile(sourcePath, 'utf8');
  const source = parseSourceText(sourceText, sourcePath);
  const output = buildDistrictOutput(source);
  await writeFile(outputPath, `${JSON.stringify(output)}\n`, 'utf8');
  console.log(
    `Generated ${output.sourceStats.includedDistricts} native districts `
      + `(${output.sourceStats.includedRecords}/${output.sourceStats.records} rectangles) at ${outputPath}`,
  );
  return output;
}

const isMainModule = process.argv[1]
  && resolve(process.argv[1]) === fileURLToPath(import.meta.url);
if (isMainModule) {
  try {
    await generateDistrictGeometry(process.argv[2], process.argv[3]);
  } catch (error) {
    console.error(`[district-geometry] ${error.message}`);
    process.exitCode = 1;
  }
}
