# vcn
resource "oci_core_vcn" "spoke_vcn" {
  count = length(local.spoke_name)
  cidr_blocks = [local.spoke_vcn_cidr[count.index]]
  dns_label = "${local.region}${local.spoke_name[count.index]}${local.virtual_cloud_network}"
  compartment_id = var.compartment_ocid
  display_name   = "${local.region}-${local.spoke_name[count.index]}-${local.virtual_cloud_network}"
}
# lpg
resource "oci_core_local_peering_gateway" "spoke_to_hub_lpg" {
  count = length(local.spoke_name)
  compartment_id = var.compartment_ocid
  vcn_id = oci_core_vcn.spoke_vcn[count.index].id
  display_name = "${local.region}-${local.spoke_name[count.index]}-to-${local.hub_name}-${local.local_peering_gateway}"
  peer_id = oci_core_local_peering_gateway.hub_to_spoke_lpg[count.index].id
}
# pub rt
resource "oci_core_route_table" "spoke_pub_rt" {
  count = length(local.spoke_name)
  compartment_id = var.compartment_ocid
  vcn_id = oci_core_vcn.spoke_vcn[count.index].id
  display_name = "${local.region}-${local.spoke_name[count.index]}-${local.public}-${local.route_table}"
  # lpg (local peering to hub)
  route_rules {
    network_entity_id = oci_core_local_peering_gateway.spoke_to_hub_lpg[count.index].id
    destination       = local.hub_vcn_cidr
    destination_type  = "CIDR_BLOCK"
  }
  # ngw
  dynamic route_rules {
    for_each = local.spoke_use_ngw == true ? [1] : []
    content {
      network_entity_id = oci_core_nat_gateway.spoke_ngw[count.index].id
      destination       = "0.0.0.0/0"
      destination_type  = "CIDR_BLOCK"
    }
  }
  # sgw
  dynamic route_rules {
    for_each = local.spoke_use_sgw == true ? [1] : []
    content {
    network_entity_id = oci_core_service_gateway.spoke_sgw[count.index].id
    destination       = data.oci_core_services.available_services.services.0.cidr_block
    destination_type  = "SERVICE_CIDR_BLOCK"
    }
  }
}
# priv rt
resource "oci_core_route_table" "spoke_priv_rt" {
  count = length(local.spoke_name)
  compartment_id = var.compartment_ocid
  vcn_id = oci_core_vcn.spoke_vcn[count.index].id
  display_name = "${local.region}-${local.spoke_name[count.index]}-${local.private}-${local.route_table}"
  # lpg (local peering to hub)
  route_rules {
    network_entity_id = oci_core_local_peering_gateway.spoke_to_hub_lpg[count.index].id
    destination       = local.hub_vcn_cidr
    destination_type  = "CIDR_BLOCK"
  }
  # ngw
  dynamic route_rules {
    for_each = local.spoke_use_ngw == true ? [1] : []
    content {
      network_entity_id = oci_core_nat_gateway.spoke_ngw[count.index].id
      destination       = "0.0.0.0/0"
      destination_type  = "CIDR_BLOCK"
    }
  }
  # sgw
  dynamic route_rules {
    for_each = local.spoke_use_sgw == true ? [1] : []
    content {
    network_entity_id = oci_core_service_gateway.spoke_sgw[count.index].id
    destination       = data.oci_core_services.available_services.services.0.cidr_block
    destination_type  = "SERVICE_CIDR_BLOCK"
    }
  }
}
# public sub
resource "oci_core_subnet" "spoke_pub_sub" {
  count = length(local.spoke_name)
  prohibit_public_ip_on_vnic = false
  cidr_block = local.spoke_pub_sub_cidr[count.index]
  compartment_id = var.compartment_ocid
  vcn_id = oci_core_vcn.spoke_vcn[count.index].id
  display_name = "${local.region}-${local.spoke_name[count.index]}-${local.public}-${local.subnet}"
  dns_label = "${local.public}${local.subnet}"
  security_list_ids = [oci_core_security_list.spoke_pub_sl[count.index].id]
  route_table_id = oci_core_route_table.spoke_pub_rt[count.index].id
}
# private sub
resource "oci_core_subnet" "spoke_priv_sub" {
  count = length(local.spoke_name)
  prohibit_public_ip_on_vnic = true
  cidr_block = local.spoke_priv_sub_cidr[count.index]
  compartment_id = var.compartment_ocid
  vcn_id = oci_core_vcn.spoke_vcn[count.index].id
  display_name = "${local.region}-${local.spoke_name[count.index]}-${local.private}-${local.subnet}"
  dns_label = "${local.private}${local.subnet}"
  security_list_ids = [oci_core_security_list.spoke_priv_sl[count.index].id]
  route_table_id = oci_core_route_table.spoke_priv_rt[count.index].id
}
# ngw
resource "oci_core_nat_gateway" "spoke_ngw" {
  count = length(local.spoke_name) * (local.spoke_use_ngw == true ? 1 : 0)
  compartment_id = var.compartment_ocid
  vcn_id = oci_core_vcn.spoke_vcn[count.index].id
  display_name   = "${local.region}-${local.spoke_name[count.index]}-${local.nat_gateway}"
  block_traffic = false
}
# sgw
resource "oci_core_service_gateway" "spoke_sgw" {
  count = length(local.spoke_name) * (local.spoke_use_sgw == true ? 1 : 0)
  #Required
  compartment_id = var.compartment_ocid
  services {
    service_id = data.oci_core_services.available_services.services[0]["id"]
  }
  vcn_id = oci_core_vcn.spoke_vcn[count.index].id
  #Optional
  display_name = "${local.region}-${local.spoke_name[count.index]}-${local.service_gateway}"
}
# public sl
resource "oci_core_security_list" "spoke_pub_sl" {
  count = length(local.spoke_name)
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.spoke_vcn[count.index].id
  display_name   = "${local.region}-${local.spoke_name[count.index]}-${local.public}-${local.security_list}"

  # outbound traffic
  egress_security_rules {
    destination      = "0.0.0.0/0"
    protocol         = "all"
  }
  # inbound traffic
  ingress_security_rules {
    protocol = 6
    source   = local.hub_vcn_cidr

    tcp_options {
      max = 22
      min = 22
    }
  }
  ingress_security_rules {
    protocol = 1
    source   = local.hub_vcn_cidr
    icmp_options {
      type = 8
    }
  }
}
# private sl
resource "oci_core_security_list" "spoke_priv_sl" {
  count = length(local.spoke_name)
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.spoke_vcn[count.index].id
  display_name   = "${local.region}-${local.spoke_name[count.index]}-${local.private}-${local.security_list}"

  # outbound traffic
  egress_security_rules {
    destination      = "0.0.0.0/0"
    protocol         = "all"
  }
  # inbound traffic
  ingress_security_rules {
    protocol = 6
    source   = local.spoke_pub_sub_cidr[count.index]

    tcp_options {
      max = 22
      min = 22
    }
  }
  ingress_security_rules {
    protocol = 1
    source   = local.spoke_pub_sub_cidr[count.index]
    icmp_options {
      type = 8
    }
  }
  ingress_security_rules {
    protocol = 6
    source   = local.spoke_priv_sub_cidr[count.index]

    tcp_options {
      max = 22
      min = 22
    }
  }
  ingress_security_rules {
    protocol = 1
    source   = local.spoke_priv_sub_cidr[count.index]
    icmp_options {
      type = 8
    }
  }
}
