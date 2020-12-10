# vcn
resource "oci_core_vcn" "hub_vcn" {
  cidr_block = local.hub_vcn_cidr
  dns_label      = "${local.region}${local.hub_name}${local.virtual_cloud_network}"
  compartment_id = var.compartment_ocid
  display_name   = "${local.region}-${local.hub_name}-${local.virtual_cloud_network}"
}
# lpg
resource "oci_core_local_peering_gateway" "hub_to_spoke_lpg" {
    count = length(local.spoke_name)
    compartment_id = var.compartment_ocid
    vcn_id         = oci_core_vcn.hub_vcn.id
    display_name   = "${local.region}-${local.hub_name}-to-${local.spoke_name[count.index]}-${local.local_peering_gateway}"
}
# rt for public subnet
resource "oci_core_route_table" "hub_pub_rt" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.hub_vcn.id
  display_name   = "${local.region}-${local.hub_name}-${local.public}-${local.route_table}"
  # igw
  route_rules {
    network_entity_id = oci_core_internet_gateway.hub_igw.id
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
  }
  # lpg - local peering to spoke
  dynamic route_rules {
    for_each = range(length(local.spoke_name))
    content { 
      network_entity_id = oci_core_local_peering_gateway.hub_to_spoke_lpg[route_rules.key].id
      destination       = local.spoke_vcn_cidr[route_rules.key]
      destination_type  = "CIDR_BLOCK"
    }
  }
}
# rt for private subnet
resource "oci_core_route_table" "hub_priv_rt" {
  compartment_id  = var.compartment_ocid
  vcn_id          = oci_core_vcn.hub_vcn.id
  display_name    = "${local.region}-${local.hub_name}-${local.private}-${local.route_table}"
  # ngw
  route_rules {
    network_entity_id = oci_core_nat_gateway.hub_ngw.id
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
  }
  # drg
  route_rules {
    network_entity_id = oci_core_drg.hub_drg.id
    destination       = local.client_premises_cidr
    destination_type  = "CIDR_BLOCK"
  }
  # lpg - local peering to spoke
  dynamic route_rules {
    for_each = range(length(local.spoke_name))
    content { 
      network_entity_id = oci_core_local_peering_gateway.hub_to_spoke_lpg[route_rules.key].id
      destination       = local.spoke_vcn_cidr[route_rules.key]
      destination_type  = "CIDR_BLOCK"
    }
  }
}
# public subnet
resource "oci_core_subnet" "hub_pub_sub" {
  prohibit_public_ip_on_vnic = false
  cidr_block        = local.hub_pub_sub_cidr
  compartment_id    = var.compartment_ocid
  vcn_id            = oci_core_vcn.hub_vcn.id
  display_name      = "${local.region}-${local.hub_name}-${local.public}-${local.subnet}"
  security_list_ids = [oci_core_security_list.hub_pub_sl.id]
  route_table_id    = oci_core_route_table.hub_pub_rt.id
}
# private subnet
resource "oci_core_subnet" "hub_priv_sub" {
  prohibit_public_ip_on_vnic = true
  cidr_block        = local.hub_priv_sub_cidr
  compartment_id    = var.compartment_ocid
  vcn_id            = oci_core_vcn.hub_vcn.id
  display_name      = "${local.region}-${local.hub_name}-${local.private}-${local.subnet}"
  security_list_ids = [oci_core_security_list.hub_priv_sl.id]
  route_table_id    = oci_core_route_table.hub_priv_rt.id
}
#igw
resource "oci_core_internet_gateway" "hub_igw" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.hub_vcn.id
  enabled        = true
  display_name   = "${local.region}-${local.hub_name}-${local.internet_gateway}"
}
# ngw
resource "oci_core_nat_gateway" "hub_ngw" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.hub_vcn.id
  display_name   = "${local.region}-${local.hub_name}-${local.nat_gateway}"
  block_traffic  = false
}
# public sl
resource "oci_core_security_list" "hub_pub_sl" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.hub_vcn.id
  display_name   = "${local.region}-${local.hub_name}-${local.public}-${local.security_list}"

  # outbound traffic
  egress_security_rules {
    destination      = "0.0.0.0/0"
    protocol         = "all"
  }
  # inbound traffic
  ingress_security_rules {
    protocol = 6
    source   = "0.0.0.0/0"

    tcp_options {
      max = 22
      min = 22
    }
  }
  ingress_security_rules {
    protocol = 1
    source   = "0.0.0.0/0"
    icmp_options {
      type = 8
    }
  }
}
# private sl
resource "oci_core_security_list" "hub_priv_sl" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.hub_vcn.id
  display_name   = "${local.region}-${local.hub_name}-${local.private}-${local.security_list}"

  # outbound traffic
  egress_security_rules {
    destination      = "0.0.0.0/0"
    protocol         = "all"
  }
  # inbound traffic
  ingress_security_rules {
    protocol = 6
    source   = local.client_premises_cidr

    tcp_options {
      max = 22
      min = 22
    }
  }
  ingress_security_rules {
    protocol = 1
    source   = local.client_premises_cidr
    icmp_options {
      type = 8
    }
  }
}
# drg
resource "oci_core_drg" "hub_drg" {
  compartment_id = var.compartment_ocid
  display_name   = "${local.region}-${local.hub_name}-${local.dynamic_routing_gateway}"
}
resource "oci_core_drg_attachment" "hub_drg_attachment" {
  #Required
  drg_id = oci_core_drg.hub_drg.id
  vcn_id = oci_core_vcn.hub_vcn.id

  #Optional
  display_name = "${local.region}-${local.hub_name}-${local.dynamic_routing_gateway}-attachment"
}
