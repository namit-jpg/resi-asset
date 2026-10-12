import { LightningElement, track } from "lwc";
import getUnits from "@salesforce/apex/StockTabController.getUnits";
import getAvailableStatuses from "@salesforce/apex/StockTabController.getAvailableStatuses";
import { loadStyle } from "lightning/platformResourceLoader";
import STOCK_CSS from "@salesforce/resourceUrl/StockStyles";

const PAGE_SIZE = 15;

export default class StockTab extends LightningElement {
  @track isLoading = false;
  @track units = [];
  @track filterOptions = [];
  @track selectedFilter = "All";
  @track searchKey = "";
  @track showNoData = false;

  offset = 0;
  allDataLoaded = false;

  columns = [
    {
      label: "Name",
      fieldName: "recordLink",
      type: "url",
      typeAttributes: { label: { fieldName: "Name" }, target: "_blank" },
      cellAttributes: { class: { fieldName: "rowClass" }, pinned: true },
      initialWidth: 300, pinned: true
    },
    { label: "BHK Configuration", fieldName: "BHK_Configuration__c", cellAttributes: { class: { fieldName: "rowClass" } }, initialWidth: 200, pinned: true },
    { label: "Built Up Area (SBA) (Sq/ft)", fieldName: "Built_Up_Area_SBA__c", type: "number", cellAttributes: { class: { fieldName: "rowClass" } }, initialWidth: 200, pinned: true },
    { label: "Carpet Area (Sq/ft)", fieldName: "Carpet_Area__c", type: "number", cellAttributes: { class: { fieldName: "rowClass" } }, initialWidth: 200, pinned: true },
    { label: "Deck/Balcony Area (Sq/ft)", fieldName: "Deck_Balcony__c", type: "number", cellAttributes: { class: { fieldName: "rowClass" } }, initialWidth: 200, pinned: true },
    { label: "Garden Area (Sq/ft)", fieldName: "Garden_Area__c", type: "number", cellAttributes: { class: { fieldName: "rowClass" } }, initialWidth: 200, pinned: true },
    { label: "Net Area Aggregate (Sq/ft)", fieldName: "Net_Area_Aggregate__c", type: "number", cellAttributes: { class: { fieldName: "rowClass" } }, initialWidth: 200, pinned: true },
    { label: "Private Lobby (Sft)", fieldName: "Private_Lobby__c", type: "number", cellAttributes: { class: { fieldName: "rowClass" } }, initialWidth: 200, pinned: true },
    { label: "Terrace Area (Sq/ft)", fieldName: "Terrace_Area__c", type: "number", cellAttributes: { class: { fieldName: "rowClass" } }, initialWidth: 200, pinned: true },
    { label: "Total area of villa/unit (Sq/ft)", fieldName: "Total_area_of_villa_unit__c", type: "number", cellAttributes: { class: { fieldName: "rowClass" } }, initialWidth: 200, pinned: true },
    { label: "Saleable Area (Sq/ft)", fieldName: "Saleable_Area__c", type: "number", cellAttributes: { class: { fieldName: "rowClass" } }, initialWidth: 200 },
    { label: "Control Code", fieldName: "Control_Code__c", cellAttributes: { class: { fieldName: "rowClass" } }, initialWidth: 200 },

    {
      label: "Customer Account",
      fieldName: "customerAccountLink",
      type: "url",
      typeAttributes: { label: { fieldName: "customerAccountName" }, target: "_blank" },
      cellAttributes: { class: { fieldName: "rowClass" } },
      initialWidth: 200
    },

    {
      label: "Floor",
      fieldName: "floorLink",
      type: "url",
      typeAttributes: { label: { fieldName: "floorName" }, target: "_blank" },
      cellAttributes: { class: { fieldName: "rowClass" } },
      initialWidth: 200, wrapText: true
    },
    {
      label: "Project",
      fieldName: "projectLink",
      type: "url",
      typeAttributes: { label: { fieldName: "projectName" }, target: "_blank" },
      cellAttributes: { class: { fieldName: "rowClass" } },
      initialWidth: 200, wrapText: true
    },
    { label: "Status", fieldName: "Status__c", cellAttributes: { class: { fieldName: "rowClass" } }, initialWidth: 200 },
    {
      label: "Tower",
      fieldName: "towerLink",
      type: "url",
      typeAttributes: { label: { fieldName: "towerName" }, target: "_blank" },
      cellAttributes: { class: { fieldName: "rowClass" } },
      initialWidth: 200
    }
  ];

  legendList = [
    { label: "Available", style: "background-color: #a1febb; color: #000;" },   // light green
    { label: "Leased", style: "background-color: #b2d0fe; color: #000;" },     // light blue
    { label: "Booked", style: "background-color: #f8e7ae; color: #000;" },     // light yellow
    { label: "Blocked", style: "background-color: #bda8e8; color: #000;" },    // light purple
    { label: "Reserved", style: "background-color: #f7c6a6; color: #000;" },   // light orange
    { label: "Partner Share", style: "background-color: #e4cfa9; color: #000;" }, // light beige
    { label: "Management Hold", style: "background-color: #f9b7b7; color: #000;" }, // very light red
    { label: "Sold", style: "background-color: #adadad; color: #000;" }        // light grey
  ];

  connectedCallback() {
    this.loadStatusOptions();
    this.loadData();

    loadStyle(this, STOCK_CSS).catch((error) => {
      console.error("Failed to load static resource CSS", error);
    });
  }

  get hasData() {
    return this.units.length > 0;
  }

  // 🔹 Load distinct statuses into dropdown
  loadStatusOptions() {
    getAvailableStatuses()
      .then((data) => {
        let opts = [{ label: "All", value: "All" }];
        data.forEach((st) => {
          opts.push({ label: st, value: st });
        });
        this.filterOptions = opts;
      })
      .catch((err) => {
        console.error("Error fetching statuses", err);
      });
  }

  // 🔹 Load paginated data
  loadData() {
    if (this.allDataLoaded || this.isLoading) return;

    this.isLoading = true;
    this.showNoData = false;

    getUnits({
      offsetSize: this.offset,
      limitSize: PAGE_SIZE,
      statusFilter: this.selectedFilter,
      searchKey: this.searchKey
    })
      .then((data) => {
        if (!data || data.length === 0) {
          if (this.offset === 0) {
            this.showNoData = true; // only show after first load
            this.units = [];
          }
          this.allDataLoaded = true;
          return;
        }

        const formatted = data.map((unit) => ({
          ...unit,
          recordLink: "/" + unit.Id,
          rowClass: this.getRowClass(unit.Status__c),

          // 🔹 Lookups
          customerAccountName: unit.Customer_Account__r?.Name || "",
          customerAccountLink: unit.Customer_Account__c ? "/" + unit.Customer_Account__c : null,

          projectName: unit.Property__r?.Name || "",
          projectLink: unit.Property__c ? "/" + unit.Property__c : null,

          profitCenterName: unit.Profit_Center__r?.Name || "",
          profitCenterLink: unit.Profit_Center__c ? "/" + unit.Profit_Center__c : null,

          floorName: unit.Floor__r?.Name || "",
          floorLink: unit.Floor__c ? "/" + unit.Floor__c : null,

          towerName: unit.Tower__r?.Name || "",
          towerLink: unit.Tower__c ? "/" + unit.Tower__c : null,

          ownerLink: unit.OwnerId ? "/" + unit.OwnerId : null,
          createdByLink: unit.CreatedById ? "/" + unit.CreatedById : null,
          lastModifiedByLink: unit.LastModifiedById ? "/" + unit.LastModifiedById : null
        }));

        if (formatted.length < PAGE_SIZE) {
          this.allDataLoaded = true;
        }

        this.units = [...this.units, ...formatted];
        this.offset += PAGE_SIZE;
        this.showNoData = false;
      })
      .catch((error) => {
        console.error("Error loading data", error);
        this.showNoData = true;
      })
      .finally(() => {
        this.isLoading = false;
      });
  }

  handleLoadMore() {
    if (this.isLoading || this.allDataLoaded) return;
    this.loadData();
  }

  // 🔹 Reset state and reload
  handleRefresh() {
    this.offset = 0;
    this.units = [];
    this.allDataLoaded = false;
    this.showNoData = false;
    this.loadData();
  }

  // 🔹 Handle search input
  handleSearchChange(event) {
    this.searchKey = event.target.value;
    this.handleRefresh();
  }

  // 🔹 Handle status dropdown change
  handleFilterChange(event) {
    this.selectedFilter = event.detail.value;
    this.handleRefresh();
  }

  // 🔹 Row color class
  getRowClass(status) {
    switch (status) {
      case "Available": 
        return "row-available";
      case "Leased": 
        return "row-leased";
      case "Booked": 
        return "row-booked";
      case "Blocked": 
        return "row-blocked";
      case "Reserved": 
        return "row-reserved";
      case "Partner Share": 
        return "row-partner";
      case "Management Hold": 
        return "row-hold";
      case "Sold": 
        return "row-sold";
      default: 
        return "row-unknown";  // fallback class
    }
  }
}