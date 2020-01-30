provider "azurerm" {
  subscription_id = "{{ required "azure.subscriptionID is required" .Values.azure.subscriptionID }}"
  tenant_id       = "{{ required "azure.tenantID is required" .Values.azure.tenantID }}"
  client_id       = "${var.CLIENT_ID}"
  client_secret   = "${var.CLIENT_SECRET}"
}

{{ if .Values.create.resourceGroup -}}
resource "azurerm_resource_group" "rg" {
  name     = "{{ required "resourceGroup.name is required" .Values.resourceGroup.name }}"
  location = "{{ required "azure.region is required" .Values.azure.region }}"
}
{{- else -}}
data "azurerm_resource_group" "rg" {
  name     = "{{ required "resourceGroup.name is required" .Values.resourceGroup.name }}"
}
{{- end}}

#=====================================================================
#= VNet, Subnets, Route Table, Security Groups
#=====================================================================

{{ if .Values.create.vnet -}}
resource "azurerm_virtual_network" "vnet" {
  name                = "{{ required "resourceGroup.vnet.name is required" .Values.resourceGroup.vnet.name }}"
  {{ if .Values.create.resourceGroup -}}
  resource_group_name = "${azurerm_resource_group.rg.name}"
  {{- else -}}
  resource_group_name = "${data.azurerm_resource_group.rg.name}"
  {{- end}}
  location            = "{{ required "azure.region is required" .Values.azure.region }}"
  address_space       = ["{{ required "resourceGroup.vnet.cidr is required" .Values.resourceGroup.vnet.cidr }}"]
}
{{- else -}}
data "azurerm_virtual_network" "vnet" {
  name                = "{{ required "resourceGroup.vnet.name is required" .Values.resourceGroup.vnet.name }}"
  resource_group_name = "{{ required "resourceGroup.vnet.resourceGroup is required" .Values.resourceGroup.vnet.resourceGroup }}"
}
{{- end }}

resource "azurerm_subnet" "workers" {
  name                      = "{{ required "clusterName is required" .Values.clusterName }}-nodes"
  {{ if .Values.create.vnet -}}
  virtual_network_name      = "${azurerm_virtual_network.vnet.name}"
  resource_group_name       = "${azurerm_virtual_network.vnet.resource_group_name}"
  {{- else -}}
  virtual_network_name      = "${data.azurerm_virtual_network.vnet.name}"
  resource_group_name       = "${data.azurerm_virtual_network.vnet.resource_group_name}"
  {{- end }}
  address_prefix            = "{{ required "networks.worker is required" .Values.networks.worker }}"
  service_endpoints         = [{{range $index, $serviceEndpoint := .Values.resourceGroup.subnet.serviceEndpoints}}{{if $index}},{{end}}"{{$serviceEndpoint}}"{{end}}]
  route_table_id            = "${azurerm_route_table.workers.id}"
  network_security_group_id = "${azurerm_network_security_group.workers.id}"
}

resource "azurerm_route_table" "workers" {
  name                = "worker_route_table"
  location            = "{{ required "azure.region is required" .Values.azure.region }}"
  {{ if .Values.create.resourceGroup -}}
  resource_group_name = "${azurerm_resource_group.rg.name}"
  {{- else -}}
  resource_group_name = "${data.azurerm_resource_group.rg.name}"
  {{- end}}
}

resource "azurerm_network_security_group" "workers" {
  name                = "{{ required "clusterName is required" .Values.clusterName }}-workers"
  location            = "{{ required "azure.region is required" .Values.azure.region }}"
  {{ if .Values.create.resourceGroup -}}
  resource_group_name = "${azurerm_resource_group.rg.name}"
  {{- else -}}
  resource_group_name = "${data.azurerm_resource_group.rg.name}"
  {{- end}}
}

{{ if .Values.create.availabilitySet -}}
#=====================================================================
#= Availability Set
#=====================================================================

resource "azurerm_availability_set" "workers" {
  name                         = "{{ required "clusterName is required" .Values.clusterName }}-avset-workers"
  {{ if .Values.create.resourceGroup -}}
  resource_group_name          = "${azurerm_resource_group.rg.name}"
  {{- else -}}
  resource_group_name          = "${data.azurerm_resource_group.rg.name}"
  {{- end}}
  location                     = "{{ required "azure.region is required" .Values.azure.region }}"
  platform_update_domain_count = "{{ required "azure.countUpdateDomains is required" .Values.azure.countUpdateDomains }}"
  platform_fault_domain_count  = "{{ required "azure.countFaultDomains is required" .Values.azure.countFaultDomains }}"
  managed                      = true
}
{{- end}}

//=====================================================================
//= Output variables
//=====================================================================

output "{{ .Values.outputKeys.resourceGroupName }}" {
{{ if .Values.create.resourceGroup -}}
  value = "${azurerm_resource_group.rg.name}"
{{- else -}}
  value = "${data.azurerm_resource_group.rg.name}"
{{- end}}
}

{{ if .Values.create.vnet -}}
output "{{ .Values.outputKeys.vnetName }}" {
  value = "${azurerm_virtual_network.vnet.name}"
}
{{- else -}}
output "{{ .Values.outputKeys.vnetName }}" {
  value = "${data.azurerm_virtual_network.vnet.name}"
}

output "{{ .Values.outputKeys.vnetResourceGroup }}" {
  value = "${data.azurerm_virtual_network.vnet.resource_group_name}"
}
{{- end}}

output "{{ .Values.outputKeys.subnetName }}" {
  value = "${azurerm_subnet.workers.name}"
}

output "{{ .Values.outputKeys.routeTableName }}" {
  value = "${azurerm_route_table.workers.name}"
}

output "{{ .Values.outputKeys.securityGroupName }}" {
  value = "${azurerm_network_security_group.workers.name}"
}

{{ if .Values.create.availabilitySet -}}
output "{{ .Values.outputKeys.availabilitySetID }}" {
  value = "${azurerm_availability_set.workers.id}"
}

output "{{ .Values.outputKeys.availabilitySetName }}" {
  value = "${azurerm_availability_set.workers.name}"
}
{{- end}}