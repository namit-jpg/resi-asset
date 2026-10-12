// Regenerates force-app/main/default/lwc/wdGlassPrefetch/wdGlassPrefetch.js from the org's UI API.
//
//   node scripts/generateWdGlassPrefetch.mjs [org-alias]
//
// The output lets wdGlassRecord request the record without first waiting for getObjectInfo, and lets
// wdGlassRelated warm the related-list records cache before its metadata wires resolve. Both components
// still compute the lists at runtime and fall back to them, so a stale file costs a round trip, not data.
// Rerun after changing SECTIONS / RECORD_CONFIG in wdGlassLayouts or the related lists on a page layout.

import { execFileSync } from 'node:child_process';
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const LWC = join(ROOT, 'force-app/main/default/lwc');
const ORG = process.argv[2] || 'my-sandbox';
const API = 'v62.0';

// Mirrors wdGlassRelated.
const SKIP = new Set([
    'OpenActivities',
    'ActivityHistories',
    'CombinedAttachments',
    'AttachedContentDocuments',
    'AttachedContentNotes',
    'ProcessSteps',
    'ProcessInstances',
    'Histories',
    'Feeds',
    'RecordActionHistories',
    'RecordActions'
]);
const MAX_LISTS = 12;
const PAGE_SIZE = 5;

async function loadLayouts() {
    const source = readFileSync(join(LWC, 'wdGlassLayouts/wdGlassLayouts.js'), 'utf8');
    const url = `data:text/javascript;base64,${Buffer.from(source).toString('base64')}`;
    return import(url);
}

// The CLI authenticates the request, so no session token is handled here.
function connect() {
    return async (path) => {
        const out = execFileSync('sf', ['api', 'request', 'rest', `/services/data/${API}${path}`, '-o', ORG], {
            encoding: 'utf8',
            env: { ...process.env, SF_DISABLE_AUTOUPDATE: 'true' },
            stdio: ['ignore', 'pipe', 'ignore'],
            maxBuffer: 64 * 1024 * 1024
        });
        const body = JSON.parse(out);
        if (Array.isArray(body) && body[0]?.errorCode) {
            throw new Error(`${path}: ${body[0].errorCode} ${body[0].message}`);
        }
        return body;
    };
}

// Same rules as wdGlassRecord.buildFieldList / highlightFields.
function fieldList(obj, info, sections, config) {
    const nameFields = new Set(info.nameFields || []);
    const first = sections[0]?.fields || [];
    const highlights = config.highlights || first.filter((f) => !nameFields.has(f)).slice(0, 4);

    const wanted = new Set(['CreatedDate', 'LastModifiedDate', ...(info.nameFields || [])]);
    sections.forEach((s) => s.fields.forEach((f) => wanted.add(f)));
    highlights.forEach((f) => wanted.add(f));
    (config.facts || []).forEach((f) => wanted.add(f));
    (config.alerts || []).forEach((a) => wanted.add(a.field));
    if (config.pathField) {
        wanted.add(config.pathField);
    }

    const result = new Set();
    wanted.forEach((api) => {
        const fi = info.fields[api];
        if (!fi) {
            return;
        }
        result.add(`${obj}.${api}`);
        if (fi.dataType === 'Reference' && fi.relationshipName) {
            const nameField = fi.referenceToInfos?.[0]?.nameFields?.[0] || 'Name';
            result.add(`${obj}.${fi.relationshipName}.${nameField}`);
        }
        if (fi.compound) {
            Object.values(info.fields)
                .filter((c) => c.compoundFieldName === api && c.apiName !== api)
                .forEach((c) => result.add(`${obj}.${c.apiName}`));
        }
    });
    return [...result];
}

// Same rules as wdGlassRelated's three wires, resolved for the object's Nikoo record type.
async function relatedParams(get, obj, recordTypeId, extraLists) {
    const lists = await get(`/ui-api/related-list-info/${obj}?recordTypeId=${recordTypeId}`);
    const layoutIds = (lists.relatedLists || []).map((l) => l.relatedListId);
    const ids = [...new Set([...extraLists, ...layoutIds])].filter((id) => !SKIP.has(id)).slice(0, MAX_LISTS);
    if (!ids.length) {
        return [];
    }
    const batch = await get(`/ui-api/related-list-info/batch/${obj}/${ids.join(',')}`);
    return (batch.results || [])
        .filter((r) => r.statusCode === 200 && r.result)
        .map((r) => {
            const info = r.result;
            return {
                relatedListId: info.listReference?.relatedListId,
                childObject: info.objectApiNames?.[0] || info.listReference?.objectApiName,
                columns: (info.displayColumns || []).slice(0, 3)
            };
        })
        .filter((i) => i.relatedListId && i.childObject && i.columns.length)
        .map((i) => ({
            relatedListId: i.relatedListId,
            optionalFields: i.columns.map((c) => `${i.childObject}.${c.fieldApiName}`),
            pageSize: PAGE_SIZE
        }));
}

async function nikooRecordTypes(get, objects) {
    const soql =
        "SELECT Id, SobjectType FROM RecordType WHERE IsActive = true AND DeveloperName LIKE '%Residential%' " +
        `AND SobjectType IN ('${objects.join("','")}') ORDER BY DeveloperName`;
    const res = await get(`/query?q=${encodeURIComponent(soql)}`);
    const byObject = {};
    res.records.forEach((r) => {
        byObject[r.SobjectType] ??= r.Id;
    });
    return byObject;
}

const { SECTIONS, RECORD_CONFIG } = await loadLayouts();
const get = connect();
const objects = Object.keys(SECTIONS);
const recordTypes = await nikooRecordTypes(get, objects);

const FIELDS = {};
const RELATED = {};
for (const obj of objects) {
    const info = await get(`/ui-api/object-info/${obj}`);
    const config = RECORD_CONFIG[obj] || {};
    FIELDS[obj] = fieldList(obj, info, SECTIONS[obj], config);
    if (!config.customer360) {
        const rt = recordTypes[obj] || info.defaultRecordTypeId;
        RELATED[obj] = await relatedParams(get, obj, rt, config.relatedLists || []);
    }
    console.log(`${obj}: ${FIELDS[obj].length} fields, ${RELATED[obj]?.length ?? 0} related lists`);
}

const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const now = new Date();
const today = `${String(now.getDate()).padStart(2, '0')} ${MONTHS[now.getMonth()]} ${now.getFullYear()}`;
const out = `// Generated by scripts/generateWdGlassPrefetch.mjs on ${today}. Do not edit by hand; rerun the script.
// Lets the glass record page start its data requests without waiting on object and related-list metadata.
// wdGlassRecord and wdGlassRelated still compute these at runtime, so a stale entry only costs a round trip.

/** getRecord optionalFields per object (what wdGlassRecord.buildFieldList produces). */
export const FIELDS = ${JSON.stringify(FIELDS, null, 4)};

/** getRelatedListRecordsBatch parameters per object, for its Nikoo Homes record type. */
export const RELATED_PARAMS = ${JSON.stringify(RELATED, null, 4)};
`;
const dir = join(LWC, 'wdGlassPrefetch');
mkdirSync(dir, { recursive: true });
writeFileSync(join(dir, 'wdGlassPrefetch.js'), out);
writeFileSync(
    join(dir, 'wdGlassPrefetch.js-meta.xml'),
    `<?xml version="1.0" encoding="UTF-8"?>
<LightningComponentBundle xmlns="http://soap.sforce.com/2006/04/metadata">
    <apiVersion>62.0</apiVersion>
    <isExposed>false</isExposed>
</LightningComponentBundle>
`
);
console.log(`Wrote ${join(dir, 'wdGlassPrefetch.js')}`);
