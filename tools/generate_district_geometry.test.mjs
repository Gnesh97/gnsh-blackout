import assert from 'node:assert/strict';
import test from 'node:test';

import {
  buildDistrictOutput,
  MAP_PROJECTION,
  normalizeCode,
  parsePopzoneIpl,
} from './generate_district_geometry.mjs';

const fixture = `zone
Z_A, 10, 20, 40, 30, 50, 5, BanhamCa, 0
Z_B, 30, 20, 0, 40, 50, 1250, OCEANA, 0
Z_C, 30, 50, -10, 40, 60, 10, TestZone, 0
end
`;

test('normalizes aliases and preserves inverted Z bounds', () => {
  const parsed = parsePopzoneIpl(fixture);
  assert.equal(parsed.records.length, 3);
  assert.equal(parsed.records[0].code, 'BANHAMC');
  assert.equal(parsed.records[0].minZ, 5);
  assert.equal(parsed.records[0].maxZ, 40);
  assert.equal(parsed.records[0].zInverted, true);
  assert.equal(normalizeCode('  bhamca '), 'BHAMCA');
});

test('builds native map districts while excluding special zones', () => {
  const output = buildDistrictOutput(parsePopzoneIpl(fixture));
  assert.equal(output.version, 3);
  assert.equal(output.sourceStats.records, 3);
  assert.equal(output.sourceStats.includedRecords, 2);
  assert.equal(output.sourceStats.excludedCodes.OCEANA, 1);
  assert.equal(output.sourceStats.invertedZRecords, 1);
  assert.deepEqual(Object.keys(output.districts), ['BANHAMC', 'TESTZONE']);
  assert.equal(output.districts.BANHAMC.sourceRecords[0].zone, 'Z_A');
});

test('uses the calibrated 2048px map projection', () => {
  assert.deepEqual(MAP_PROJECTION, {
    width: 2048,
    height: 2048,
    originX: 939,
    originY: 1381,
    scaleX: 0.16425,
    scaleY: 0.16425,
  });
});
