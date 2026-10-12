import { LightningElement, track } from 'lwc';
import ROOMS_LAYOUT_SVG from '@salesforce/resourceUrl/availability_map_assets';

export default class UnitAvailabilityMap extends LightningElement {
    fiveRoomSVG = ROOMS_LAYOUT_SVG + '/5_rooms_layout.svg';
    fourRoomSVG = ROOMS_LAYOUT_SVG + '/4_rooms_layout.svg';
    liftSVG = ROOMS_LAYOUT_SVG + '/lift_layout.svg';

    availableColor = '#4CAF50'; // Green
    bookedColor = '#F44336'; // Red
    unavailableColor = '#9E9E9E'; // Grey
    underConstructionColor = '#FFC107'; // Yellow
    liftColor = '#2196F3'; // Blue
    isLoading = false;
    isDataPresent = false;

    @track selectedTower = '';
    @track selectedFloor = '';

    towerOptions = [
        { label: 'Tower A', value: 'A' },
        { label: 'Tower B', value: 'B' },
        { label: 'Tower C', value: 'C' }
    ];

    floorOptions = [
        { label: 'Ground Floor', value: '0' },
        { label: '1st Floor', value: '1' },
        { label: '2nd Floor', value: '2' },
        { label: '3rd Floor', value: '3' }
    ];

    handleTowerChange(event) {
        this.selectedTower = event.detail.value;
        this.handleLoadData();

    }

    handleFloorChange(event) {
        this.selectedFloor = event.detail.value;
        this.handleLoadData();
    }

    handleLoadData () {
        if(this.selectedTower && this.selectedFloor) {
            this.isLoading = true;
            setTimeout(() => {
                this.isLoading = false;
                this.isDataPresent = true;
            }, 1000);
        }
    }
}