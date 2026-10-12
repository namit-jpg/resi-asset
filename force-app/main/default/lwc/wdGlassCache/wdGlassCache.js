// Tab-lifetime cache for the glass pages' Apex loads. Module state is shared by every component instance
// in the Lightning session, so revisiting a record or switching console tabs can paint the last result
// straight away while a fresh load runs. Concurrent loads of the same key share one request.

const MAX_ENTRIES = 100;
const store = new Map(); // key -> { data, at }
const inflight = new Map(); // key -> Promise

/** Last loaded value for the key, or undefined. */
export function peek(key) {
    return store.get(key)?.data;
}

/**
 * Loads the key through `loader`, sharing any request already in flight. When `maxAgeMs` is set and the
 * cached value is younger than that, it is returned without a new request.
 */
export function load(key, loader, maxAgeMs = 0) {
    const hit = store.get(key);
    if (maxAgeMs > 0 && hit && Date.now() - hit.at < maxAgeMs) {
        return Promise.resolve(hit.data);
    }
    if (inflight.has(key)) {
        return inflight.get(key);
    }
    const request = Promise.resolve()
        .then(loader)
        .then((data) => {
            store.delete(key);
            store.set(key, { data, at: Date.now() });
            if (store.size > MAX_ENTRIES) {
                store.delete(store.keys().next().value);
            }
            return data;
        })
        .finally(() => inflight.delete(key));
    inflight.set(key, request);
    return request;
}