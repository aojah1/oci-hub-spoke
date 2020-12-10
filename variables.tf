variable "tenancy_ocid" {}
variable "user_ocid" {}
variable "fingerprint" {}
variable "private_key_path" {}
variable "region" {}
variable "compartment_ocid" {}
data "oci_identity_regions" "available_regions" {
  filter {
    name = "name"
    values = [var.region]
    regex = false
  }
}
data "oci_core_services" "available_services" {
  filter {
    name   = "name"
    values = ["All .* Services In Oracle Services Network"]
    regex  = true
  }
}
output "services" {
  value = [data.oci_core_services.available_services.services]
}
locals {
  # hub values
  hub_name = "hub"
  hub_vcn_cidr = "10.17.0.0/23"
  hub_pub_sub_cidr = "10.17.0.0/24"
  hub_priv_sub_cidr = "10.17.1.0/24"
  # spoke values
  spoke_use_ngw = true
  spoke_use_sgw = true
  spoke_name = ["dept1", "dept2"] # , "otherdept"
  spoke_vcn_cidr = ["10.15.0.0/16", "10.16.0.0/16"] # , "10.17.2.0/23"
  spoke_pub_sub_cidr = ["10.15.0.0/17", "10.16.0.0/17"] # , "10.17.2.0/24"
  spoke_priv_sub_cidr = ["10.15.128.0/17", "10.16.128.0/17"] # , "10.17.3.0/24"
}
locals {
  # shorthand values
  region = lower(data.oci_identity_regions.available_regions.regions.0.key)
  private = "priv"
  public = "pub"
  subnet = "sub"
  route_table = "rt"
  security_list = "sl"
  virtual_cloud_network = "vcn"
  dynamic_routing_gateway = "drg"
  service_gateway = "sgw"
  internet_gateway = "igw"
  nat_gateway = "ngw"
  local_peering_gateway = "lpg"
}
locals {
  # other
  client_premises_cidr = "172.1.0.0/16" # change to actual
}