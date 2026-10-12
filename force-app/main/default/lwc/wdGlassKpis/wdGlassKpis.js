import { LightningElement, api } from 'lwc';
import { toKpiCard } from 'c/wdGlassFormat';

export default class WdGlassKpis extends LightningElement {
    @api kpis = [];

    get cards() {
        return (this.kpis || []).map(toKpiCard);
    }
}