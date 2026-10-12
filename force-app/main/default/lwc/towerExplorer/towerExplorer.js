import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getProjects from '@salesforce/apex/TowerExplorerController.getProjects';
import getTowerUnits from '@salesforce/apex/TowerExplorerController.getTowerUnits';
import getTowerUnitsFresh from '@salesforce/apex/TowerExplorerController.getTowerUnitsFresh';
import searchOpportunities from '@salesforce/apex/TowerExplorerController.searchOpportunities';
import tagUnit from '@salesforce/apex/TowerExplorerController.tagUnit';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { inrParts, formatInr } from 'c/wdGlassFormat';

const STATUS_CLASS = {
    Available: 's-available',
    Booked: 's-booked',
    Sold: 's-booked',
    Blocked: 's-blocked',
    Reserved: 's-reserved',
    'Management Hold': 's-hold',
    'Partner Share': 's-hold'
};
const LEGEND = [
    { label: 'Available', cls: 's-available' },
    { label: 'Reserved', cls: 's-reserved' },
    { label: 'Blocked', cls: 's-blocked' },
    { label: 'Booked / Sold', cls: 's-booked' },
    { label: 'Mgmt hold', cls: 's-hold' },
    { label: 'Other', cls: 's-other' }
];
const SOLD = new Set(['Booked', 'Sold']);
const SEARCH_DELAY = 300;

function errorMessage(error) {
    return error?.body?.message || error?.message || 'Something went wrong.';
}

function crore(amount) {
    if (amount == null) {
        return null;
    }
    const p = inrParts(amount);
    return `${p.value}${p.unit ? ' ' + p.unit : ''}`;
}

function sqft(value) {
    return value == null ? '—' : `${Math.round(value).toLocaleString('en-IN')} sft`;
}

export default class TowerExplorer extends NavigationMixin(LightningElement) {
    /** 'browse' on the Stock tab; 'select' inside the Select Inventory action. */
    @api mode = 'browse';
    /** Unit currently tagged to the opportunity (select mode). */
    @api currentUnitId;
    @api initialProjectId;
    @api initialTowerId;

    projects = [];
    projectId;
    towerId;
    tower;
    loading = true;
    error;

    bhkFilter = new Set();
    statusFilter = new Set();
    floorMin;
    floorMax;
    budgetMin;
    budgetMax;
    selectedId;

    // Tagging a unit to an opportunity from the Stock tab (browse mode).
    tagTerm = '';
    tagResults = [];
    tagSearching = false;
    tagOpp;
    tagging = false;
    tagError;
    searchTimer;

    @wire(getProjects)
    wiredProjects({ data, error }) {
        if (data) {
            this.projects = data;
            const project = data.find((p) => p.id === this.initialProjectId) || data[0];
            if (project) {
                this.projectId = project.id;
                const tower = project.towers.find((t) => t.id === this.initialTowerId) || project.towers[0];
                this.selectTower(tower?.id);
            } else {
                this.loading = false;
            }
        } else if (error) {
            this.error = errorMessage(error);
            this.loading = false;
        }
    }

    connectedCallback() {
        if (this.isSelectMode) {
            this.statusFilter = new Set(['Available']);
            this.selectedId = this.currentUnitId;
        }
    }

    /** Reloads the current tower, bypassing the wire cache (used after a save). */
    @api
    refresh() {
        return this.loadTower(this.towerId, true);
    }

    @api
    get selectedUnit() {
        return this.tower?.units.find((u) => u.id === this.selectedId);
    }

    get isSelectMode() {
        return this.mode === 'select';
    }

    // ---------- loading ----------

    selectTower(towerId) {
        this.towerId = towerId;
        this.resetRanges();
        if (towerId) {
            this.loadTower(towerId, this.isSelectMode);
        } else {
            this.tower = undefined;
            this.loading = false;
        }
    }

    async loadTower(towerId, fresh) {
        if (!towerId) {
            return;
        }
        this.loading = true;
        this.error = undefined;
        try {
            const data = fresh ? await getTowerUnitsFresh({ towerId }) : await getTowerUnits({ towerId });
            if (towerId === this.towerId) {
                this.tower = data;
                this.resetRanges();
                if (this.selectedId && !data.units.some((u) => u.id === this.selectedId)) {
                    this.selectedId = this.isSelectMode ? this.selectedId : undefined;
                }
            }
        } catch (e) {
            this.error = errorMessage(e);
        } finally {
            this.loading = false;
        }
    }

    resetRanges() {
        this.floorMin = undefined;
        this.floorMax = undefined;
        this.budgetMin = undefined;
        this.budgetMax = undefined;
    }

    // ---------- project + tower pickers ----------

    get projectOptions() {
        return this.projects.map((p) => ({ label: p.name, value: p.id }));
    }

    get towerTabs() {
        const project = this.projects.find((p) => p.id === this.projectId);
        return (project?.towers || []).map((t) => ({
            ...t,
            cls: `tab${t.id === this.towerId ? ' on' : ''}`,
            label: `${t.name} · ${t.unitCount}`
        }));
    }

    handleProject(event) {
        this.projectId = event.detail.value;
        const project = this.projects.find((p) => p.id === this.projectId);
        this.selectTower(project?.towers[0]?.id);
    }

    handleTower(event) {
        this.selectTower(event.currentTarget.dataset.id);
    }

    // ---------- units + derived ranges ----------

    get units() {
        return this.tower?.units || [];
    }

    get hasUnits() {
        return this.units.length > 0;
    }

    get floorNumbers() {
        return this.units.map((u) => u.floorNumber).filter((n) => n != null);
    }

    get floorBounds() {
        const f = this.floorNumbers;
        return f.length ? { min: Math.min(...f), max: Math.max(...f) } : { min: 0, max: 0 };
    }

    get budgetBounds() {
        const prices = this.units.map((u) => u.allInPrice).filter((n) => n != null);
        if (!prices.length) {
            return null;
        }
        // Slider works in lakhs so steps stay meaningful across cheap and premium towers.
        return { min: Math.floor(Math.min(...prices) / 1e5), max: Math.ceil(Math.max(...prices) / 1e5) };
    }

    get effFloorMin() {
        return this.floorMin ?? this.floorBounds.min;
    }

    get effFloorMax() {
        return this.floorMax ?? this.floorBounds.max;
    }

    get effBudgetMin() {
        return this.budgetMin ?? this.budgetBounds?.min;
    }

    get effBudgetMax() {
        return this.budgetMax ?? this.budgetBounds?.max;
    }

    get showFloorFilter() {
        return this.floorBounds.max > this.floorBounds.min;
    }

    get showBudgetFilter() {
        const b = this.budgetBounds;
        return b && b.max > b.min;
    }

    /** Track fill between the two thumbs, as CSS custom properties. */
    fill(min, max, lo, hi) {
        const span = max - min || 1;
        return `--lo:${((lo - min) / span) * 100}%;--hi:${((hi - min) / span) * 100}%`;
    }

    get floorFill() {
        const b = this.floorBounds;
        return this.fill(b.min, b.max, this.effFloorMin, this.effFloorMax);
    }

    get budgetFill() {
        const b = this.budgetBounds;
        return b ? this.fill(b.min, b.max, this.effBudgetMin, this.effBudgetMax) : '';
    }

    get floorLabel() {
        return `Floors · ${this.effFloorMin} to ${this.effFloorMax}`;
    }

    get budgetLabel() {
        return `All-in budget · ${crore(this.effBudgetMin * 1e5)} – ${crore(this.effBudgetMax * 1e5)}`;
    }

    // ---------- filters ----------

    get bhkPills() {
        const values = [...new Set(this.units.map((u) => u.bhk).filter(Boolean))].sort();
        return values.map((v) => ({ value: v, cls: `pill${this.bhkFilter.has(v) ? ' on' : ''}` }));
    }

    get statusPills() {
        const counts = new Map();
        this.units.forEach((u) => counts.set(u.status || 'Unknown', (counts.get(u.status || 'Unknown') || 0) + 1));
        return [...counts.entries()]
            .sort((a, b) => b[1] - a[1])
            .map(([value, count]) => ({
                value,
                label: `${value} (${count})`,
                cls: `pill${this.statusFilter.has(value) ? ' on' : ''}`
            }));
    }

    toggleIn(setName, value) {
        const next = new Set(this[setName]);
        if (next.has(value)) {
            next.delete(value);
        } else {
            next.add(value);
        }
        this[setName] = next;
    }

    handleBhk(event) {
        this.toggleIn('bhkFilter', event.currentTarget.dataset.value);
    }

    handleStatus(event) {
        this.toggleIn('statusFilter', event.currentTarget.dataset.value);
    }

    handleFloorMin(event) {
        this.floorMin = Math.min(Number(event.target.value), this.effFloorMax);
        event.target.value = this.floorMin;
    }

    handleFloorMax(event) {
        this.floorMax = Math.max(Number(event.target.value), this.effFloorMin);
        event.target.value = this.floorMax;
    }

    handleBudgetMin(event) {
        this.budgetMin = Math.min(Number(event.target.value), this.effBudgetMax);
        event.target.value = this.budgetMin;
    }

    handleBudgetMax(event) {
        this.budgetMax = Math.max(Number(event.target.value), this.effBudgetMin);
        event.target.value = this.budgetMax;
    }

    handleReset() {
        this.bhkFilter = new Set();
        this.statusFilter = this.isSelectMode ? new Set(['Available']) : new Set();
        this.resetRanges();
    }

    matches(u) {
        if (this.bhkFilter.size && !this.bhkFilter.has(u.bhk)) {
            return false;
        }
        if (this.statusFilter.size && !this.statusFilter.has(u.status || 'Unknown')) {
            return false;
        }
        if (u.floorNumber != null && (u.floorNumber < this.effFloorMin || u.floorNumber > this.effFloorMax)) {
            return false;
        }
        if (this.budgetBounds && u.allInPrice != null) {
            const lakhs = u.allInPrice / 1e5;
            if (lakhs < this.effBudgetMin - 0.5 || lakhs > this.effBudgetMax + 0.5) {
                return false;
            }
        }
        return true;
    }

    get matchSummary() {
        const hits = this.units.filter((u) => this.matches(u));
        const names = hits.slice(0, 4).map((u) => u.name).join(' · ');
        return { count: hits.length, names: hits.length > 4 ? `${names} …` : names };
    }

    get noMatches() {
        return this.hasUnits && this.matchSummary.count === 0;
    }

    // ---------- kpis ----------

    get kpis() {
        const count = (pred) => this.units.filter(pred).length;
        return [
            { key: 'a', label: 'Available', value: count((u) => u.status === 'Available') },
            { key: 'r', label: 'Reserved', value: count((u) => u.status === 'Reserved') },
            { key: 'b', label: 'Booked', value: count((u) => SOLD.has(u.status)) },
            { key: 'h', label: 'Blocked / hold', value: count((u) => ['Blocked', 'Management Hold'].includes(u.status)) }
        ];
    }

    // ---------- stack ----------

    get columns() {
        const positions = [...new Set(this.units.map((u) => u.position).filter((p) => p != null))].sort((a, b) => a - b);
        return positions;
    }

    /** Floors top-down; units without a parsable floor/position fall into an "Unplaced" row. */
    get rows() {
        const cols = this.columns;
        const byFloor = new Map();
        const unplaced = [];
        this.units.forEach((u) => {
            if (u.floorNumber == null || u.position == null) {
                unplaced.push(u);
                return;
            }
            if (!byFloor.has(u.floorNumber)) {
                byFloor.set(u.floorNumber, new Map());
            }
            byFloor.get(u.floorNumber).set(u.position, u);
        });
        const floors = [...byFloor.keys()].sort((a, b) => b - a);
        const rows = floors.map((f) => ({
            key: `f${f}`,
            label: f === 0 ? 'G' : String(f),
            cells: cols.map((c) => this.toCell(byFloor.get(f).get(c), `f${f}c${c}`))
        }));
        if (unplaced.length) {
            rows.push({ key: 'unplaced', label: '—', cells: unplaced.map((u) => this.toCell(u, u.id)) });
        }
        return rows;
    }

    get headers() {
        return this.columns.map((c) => {
            const bhks = this.units.filter((u) => u.position === c).map((u) => u.bhk);
            const top = bhks.sort((a, b) => bhks.filter((x) => x === b).length - bhks.filter((x) => x === a).length)[0];
            return { key: `h${c}`, label: `${String(c).padStart(2, '0')}${top ? ' · ' + top : ''}` };
        });
    }

    get gridStyle() {
        const n = Math.max(this.columns.length, 1);
        return `grid-template-columns: 34px repeat(${n}, minmax(74px, 1fr));`;
    }

    isSelectable(u) {
        return !this.isSelectMode || u.status === 'Available' || u.id === this.currentUnitId;
    }

    toCell(u, key) {
        if (!u) {
            return { key, empty: true, cls: 'cell empty' };
        }
        const match = this.matches(u);
        const selectable = this.isSelectable(u);
        const cls = [
            'cell',
            STATUS_CLASS[u.status] || 's-other',
            match ? '' : 'dim',
            selectable ? 'clickable' : 'locked',
            u.id === this.selectedId ? 'sel' : '',
            u.id === this.currentUnitId ? 'current' : ''
        ]
            .filter(Boolean)
            .join(' ');
        // Status is carried by the cell colour (see legend), so the cell only shows the unit type.
        const rate = u.allInPerSqft != null ? `₹${u.allInPerSqft.toLocaleString('en-IN')}/sft` : '';
        const price = u.allInPrice != null ? `₹${crore(u.allInPrice)}` : '';
        return {
            key,
            id: u.id,
            empty: false,
            cls,
            label: u.name,
            sub: u.bhk || '—',
            title: [u.name, u.bhk, u.status, price, rate, selectable ? '' : 'not selectable'].filter(Boolean).join(' · ')
        };
    }

    handleCell(event) {
        const id = event.currentTarget.dataset.id;
        const unit = this.units.find((u) => u.id === id);
        if (!unit || !this.isSelectable(unit)) {
            return;
        }
        if (id !== this.selectedId) {
            this.resetTag();
        }
        this.selectedId = id;
        this.dispatchEvent(new CustomEvent('unitselect', { detail: { unitId: id, unitName: unit.name } }));
    }

    // ---------- unit panel ----------

    get panel() {
        const u = this.selectedUnit;
        if (!u) {
            return null;
        }
        const line = (label, value) => ({ label, value: formatInr(value), key: label });
        const baseLabel = u.baseFromRate
            ? `Base · ${sqft(u.chargeableArea)} × ₹${Number(this.tower.ratePerSqft).toLocaleString('en-IN')}`
            : 'Base price';
        const lines = [line(baseLabel, u.basePrice)];
        [
            ['Construction charges', u.constructionCharges],
            ['Land charges', u.landCharges],
            ['Club membership', u.clubCharges],
            ['Legal fees', u.legalFees],
            ['BESCOM / BWSSB', u.utilityCharges],
            ['Maintenance deposit / corpus', u.maintenanceDeposit]
        ].forEach(([label, value]) => {
            if (value) {
                lines.push(line(label, value));
            }
        });
        return {
            name: u.name,
            status: u.status || '—',
            chipCls: `chip ${STATUS_CLASS[u.status] || 's-other'}`,
            meta: [u.bhk, u.floorName ? `Floor ${u.floorName}` : null, this.tower.towerName, u.rera ? `RERA ${u.rera}` : null]
                .filter(Boolean)
                .join(' · '),
            specs: [
                { key: 'c', label: 'Carpet', value: sqft(u.carpetArea) },
                { key: 's', label: 'Saleable', value: sqft(u.saleableArea) },
                { key: 'b', label: 'Super built-up', value: sqft(u.sbaArea) },
                { key: 'd', label: 'Balcony / deck', value: sqft(u.balconyArea) },
                { key: 'p', label: 'Car parks', value: u.carParks ?? '—' },
                { key: 'r', label: '₹/sft all-in', value: u.allInPerSqft != null ? u.allInPerSqft.toLocaleString('en-IN') : '—' }
            ],
            chargeableNote: this.tower.chargeableAreaType ? `Priced on ${this.tower.chargeableAreaType.toLowerCase()}` : null,
            hasPrice: u.allInPrice != null,
            lines,
            allIn: formatInr(u.allInPrice),
            isCurrent: u.id === this.currentUnitId,
            tags: (u.tags || []).map((t) => ({ ...t, meta: [t.customer, t.stage].filter(Boolean).join(' · ') })),
            hasTags: !!u.tags?.length,
            canTag: u.status === 'Available'
        };
    }

    get noRateWarning() {
        return this.tower && this.tower.ratePerSqft == null;
    }

    handleOpenRecord() {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: this.selectedId, objectApiName: 'Unit__c', actionName: 'view' }
        });
    }

    handleClosePanel() {
        this.selectedId = this.isSelectMode ? this.selectedId : undefined;
        this.resetTag();
    }

    // ---------- tagging (browse mode) ----------

    get hasTagResults() {
        return this.tagResults.length > 0;
    }

    get tagNoResults() {
        return this.tagTerm.trim().length >= 2 && !this.tagResults.length;
    }

    resetTag() {
        clearTimeout(this.searchTimer);
        this.tagTerm = '';
        this.tagResults = [];
        this.tagSearching = false;
        this.tagOpp = undefined;
        this.tagError = undefined;
    }

    handleTagSearch(event) {
        this.tagTerm = event.target.value || '';
        this.tagError = undefined;
        clearTimeout(this.searchTimer);
        const term = this.tagTerm.trim();
        if (term.length < 2) {
            this.tagResults = [];
            this.tagSearching = false;
            return;
        }
        this.tagSearching = true;
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this.searchTimer = setTimeout(() => this.runTagSearch(term), SEARCH_DELAY);
    }

    async runTagSearch(term) {
        try {
            const rows = await searchOpportunities({ term, projectId: this.projectId });
            if (term === this.tagTerm.trim()) {
                this.tagResults = rows.map((o) => ({ ...o, meta: this.oppMeta(o) }));
            }
        } catch (e) {
            this.tagError = errorMessage(e);
            this.tagResults = [];
        } finally {
            if (term === this.tagTerm.trim()) {
                this.tagSearching = false;
            }
        }
    }

    oppMeta(o) {
        return [o.customer, o.stage, o.unitName ? `currently ${o.unitName}` : 'no unit yet'].filter(Boolean).join(' · ');
    }

    handlePickTagOpp(event) {
        this.tagOpp = this.tagResults.find((o) => o.id === event.currentTarget.dataset.id);
    }

    handleClearTagOpp() {
        this.tagOpp = undefined;
    }

    async handleTag() {
        const unit = this.selectedUnit;
        if (!unit || !this.tagOpp) {
            return;
        }
        this.tagging = true;
        this.tagError = undefined;
        try {
            await tagUnit({ opportunityId: this.tagOpp.id, unitId: unit.id });
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Unit tagged',
                    message: `${unit.name} is now tagged to ${this.tagOpp.name} and reserved.`,
                    variant: 'success'
                })
            );
            this.resetTag();
        } catch (e) {
            this.tagError = errorMessage(e);
        } finally {
            this.tagging = false;
            // Show the new status (or whoever took the unit meanwhile).
            await this.loadTower(this.towerId, true);
        }
    }

    handleOpenTag(event) {
        event.preventDefault();
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: event.currentTarget.dataset.id, objectApiName: 'Opportunity', actionName: 'view' }
        });
    }

    get legend() {
        return LEGEND;
    }

    get rootCls() {
        return `te-root${this.isSelectMode ? ' te-select-root' : ''}`;
    }

    get showBackdrop() {
        return !this.isSelectMode;
    }

    get showBrowseActions() {
        return !this.isSelectMode;
    }
}