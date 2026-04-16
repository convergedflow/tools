# ZTC Variable Reference

This document lists every field produced in the ZTC output YAML, showing whether each value comes from the CSV input, is derived from CSV data inside the template, or is hardcoded in the template.

**Source key**

| Source | Meaning |
|--------|---------|
| CSV | Value is read directly from a CSV column of the same name |
| Derived | Value is computed inside the template using one or more CSV columns |
| Fixed | Value is hardcoded in the template and does not vary per device |

---

## applianceInfo

| Field | Source | Value / Expression | Notes |
|-------|--------|--------------------|-------|
| `softwareVersion` | CSV | `{{ softwareVersion }}` | |
| `hostname` | CSV | `{{ hostname }}` | Also used (lowercased) in the output filename |
| `group` | CSV | `{{ group }}` | |
| `site` | CSV | `{{ site }}` | |
| `clusterProfile` | Fixed | *(empty)* | |
| `networkRole` | Fixed | `non-hub` | |
| `region` | Fixed | *(empty)* | |
| `address` | CSV | `{{ address }}` | Street address line 1 |
| `address2` | CSV | `{{ address2 }}` | Street address line 2 — may be blank |
| `city` | CSV | `{{ city }}` | |
| `state` | CSV | `{{ state }}` | |
| `zipCode` | CSV | `{{ zipCode }}` | |
| `country` | CSV | `{{ country }}` | |
| `latitude` | CSV | `{{ latitude }}` | May be blank |
| `longitude` | CSV | `{{ longitude }}` | May be blank |
| `name` | CSV | `{{ name }}` | Contact name |
| `email` | CSV | `{{ email }}` | Contact email address |

---

## templateGroups

| Field | Source | Value | Notes |
|-------|--------|-------|-------|
| `groups[0]` | Fixed | `Default Template Group` | |
| `groups[1]` | Fixed | `Spoke Defaults` | |

---

## businessIntentOverlays

| Field | Source | Value | Notes |
|-------|--------|-------|-------|
| `overlays[0]` | Fixed | `RealTime` | |
| `overlays[1]` | Fixed | `CriticalApps` | |
| `overlays[2]` | Fixed | `DefaultOverlay` | |

---

## deploymentInfo

### Top-level

| Field | Source | Value / Expression | Notes |
|-------|--------|--------------------|-------|
| `deploymentMode` | Fixed | `inline-router` | |
| `serverPerSegment` | Fixed | `false` | |
| `totalOutboundBandwidth` | CSV | `{{ totalOutboundBandwidth }}` | In kbps |
| `totalInboundBandwidth` | CSV | `{{ totalInboundBandwidth }}` | In kbps |

### deploymentInterfaces — LAN (fixed per-site, IP derived from siteCode)

| Field | Interface | Source | Value / Expression | Notes |
|-------|-----------|--------|--------------------|-------|
| `interfaceName` | Operations LAN | Fixed | `blan0.175` | |
| `interfaceType` | Operations LAN | Fixed | `lan` | |
| `interfaceComment` | Operations LAN | Fixed | `Operations` | |
| `ipAddressMask` | Operations LAN | Derived | `10.{{ siteCode }}.175.50/24` | Third octet is always 175 |
| `nextHop` | Operations LAN | Fixed | *(empty)* | |
| `segment` | Operations LAN | Fixed | `Default` | |
| `zone` | Operations LAN | Fixed | `Operations` | |
| `interfaceName` | Management LAN | Fixed | `blan0.190` | |
| `interfaceType` | Management LAN | Fixed | `lan` | |
| `interfaceComment` | Management LAN | Fixed | `Management` | |
| `ipAddressMask` | Management LAN | Derived | `10.{{ siteCode }}.190.50/24` | Third octet is always 190 |
| `nextHop` | Management LAN | Fixed | *(empty)* | |
| `segment` | Management LAN | Fixed | `Default` | |
| `zone` | Management LAN | Fixed | `Management` | |
| `interfaceName` | Staff LAN | Fixed | `blan0.242` | |
| `interfaceType` | Staff LAN | Fixed | `lan` | |
| `interfaceComment` | Staff LAN | Fixed | `Staff` | |
| `ipAddressMask` | Staff LAN | Derived | `10.{{ siteCode }}.242.50/24` | Third octet is always 242 |
| `nextHop` | Staff LAN | Fixed | *(empty)* | |
| `segment` | Staff LAN | Fixed | `Default` | |
| `zone` | Staff LAN | Fixed | `Staff` | |
| `interfaceName` | Contractors LAN | Fixed | `blan0.243` | |
| `interfaceType` | Contractors LAN | Fixed | `lan` | |
| `interfaceComment` | Contractors LAN | Fixed | `Contractors` | |
| `ipAddressMask` | Contractors LAN | Derived | `10.{{ siteCode }}.243.50/24` | Third octet is always 243 |
| `nextHop` | Contractors LAN | Fixed | *(empty)* | |
| `segment` | Contractors LAN | Fixed | `Default` | |
| `zone` | Contractors LAN | Fixed | `Staff` | |

### deploymentInterfaces — Primary WAN (Radio WAN, always present)

| Field | Source | Value / Expression | Notes |
|-------|--------|--------------------|-------|
| `interfaceName` | Fixed | `lan2.3003` | |
| `interfaceLabel` | Fixed | `RWAN` | |
| `interfaceType` | Fixed | `wan` | |
| `interfaceComment` | Fixed | `Radio WAN` | |
| `ipAddressMask` | Derived | `10.254.254.{{ siteCode }}/26` | Fourth octet equals `siteCode` |
| `nextHop` | Fixed | `10.254.254.1` | |
| `outboundMaxBandwidth` | Fixed | `50000` | kbps |
| `inboundMaxBandwidth` | Fixed | `50000` | kbps |
| `firewallMode` | Fixed | `stateful` | |
| `behindNat` | Fixed | `none` | |
| `zone` | Fixed | `RadioWAN` | |

### deploymentInterfaces — Secondary WAN (optional, included only when `secWanInterfaceName` is not blank)

| Field | Source | Value / Expression | Notes |
|-------|--------|--------------------|-------|
| `interfaceName` | CSV | `{{ secWanInterfaceName }}` | Leave blank in CSV to omit this entire block |
| `interfaceLabel` | CSV | `{{ secWanInterfaceLabel }}` | |
| `interfaceType` | Fixed | `wan` | |
| `interfaceComment` | CSV | `{{ secWanInterfaceComment }}` | |
| `ipAddressMask` | CSV | `{{ secWanIpAddressMask }}` | Full CIDR notation, e.g. `192.0.2.10/30` |
| `nextHop` | CSV | `{{ secWanNextHop }}` | |
| `outboundMaxBandwidth` | CSV | `{{ secWanOutboundMaxBandwidth }}` | kbps |
| `inboundMaxBandwidth` | CSV | `{{ secWanInboundMaxBandwidth }}` | kbps |
| `firewallMode` | CSV | `{{ secWanFirewallMode }}` | e.g. `statefulSNAT` |
| `behindNat` | CSV | `{{ secWanBehindNat }}` | e.g. `auto` or `none` |
| `zone` | CSV | `{{ secWanZone }}` | e.g. `Internet` |

### dhcpInfo (DHCP relay, same for all four LAN interfaces)

| Field | Source | Value | Notes |
|-------|--------|-------|-------|
| `dhcpInterfaceName` | Fixed | `blan0.175`, `blan0.190`, `blan0.242`, `blan0.243` | One entry per LAN interface |
| `dhcpType` | Fixed | `relay` | |
| `dhcpProxyServers[0]` | Fixed | `10.160.90.1` | |
| `dhcpProxyServers[1]` | Fixed | `10.7.190.10` | |

---

## ecLicensing

| Field | Source | Value | Notes |
|-------|--------|-------|-------|
| `useDefaultAccount` | Fixed | `true` | |
| `bandwidthLevel` | Fixed | `1000000` | kbps (1 Gbps licence tier) |
| `boost` | Fixed | `0` | |

---

## segmentLocalRoutes

| Field | Source | Value | Notes |
|-------|--------|-------|-------|
| `segment` | Fixed | `Default` | |
| `useSharedSubnetInfo` | Fixed | `true` | |
| `advertiseLocalLanSubnets` | Fixed | `true` | |
| `advertiseLocalWanSubnets` | Fixed | `false` | |
| `localMetric` | Fixed | `50` | |
| `localCommunities` | Fixed | *(empty)* | |
| `redistOspfToSubnetShare` | Fixed | `false` | |
| `ospfRedistMetric` | Fixed | `0` | |
| `ospfRedistTag` | Fixed | `0` | |
| `filterRoutesWithLocalASN` | Fixed | `true` | |
| `redistToSDwanFabricRouteMap` | Fixed | `LoopbacksOnly` | |

---

## segmentBgpSystems

| Field | Source | Value / Expression | Notes |
|-------|--------|--------------------|-------|
| `segment` | Fixed | `Default` | |
| `enable` | Fixed | `true` | |
| `asn` | Derived | `650{{ "%02d" \| format(siteCode \| int) }}` | `siteCode` 5 → `65005`; `siteCode` 12 → `65012` |
| `routerId` | Fixed | `172.25.25.172` | |
| `propagateAsPath` | Fixed | `true` | |

---

## linkAggregation

| Field | Source | Value | Notes |
|-------|--------|-------|-------|
| `channelGroup` | Fixed | `blan0` | |
| `interfaces` | Fixed | `lan0, lan1` | |
| `mtu` | Fixed | `1500` | |
| `mode` | Fixed | `4` | LACP (802.3ad) |
| `lacpRate` | Fixed | `slow` | |
| `lacpSystemPriority` | Fixed | `65535` | |
| `lacpComment` | Fixed | `LACP bond for LAN Access` | |
| `isForceDelete` | Fixed | `true` | |

---

## poE

| Field | Source | Value | Notes |
|-------|--------|-------|-------|
| `powerMode` | Fixed | `2` | |
| `interfaces[lan0].priority` | Fixed | `0` | |
| `interfaces[lan0].enable` | Fixed | `false` | |
| `interfaces[lan1].priority` | Fixed | `0` | |
| `interfaces[lan1].enable` | Fixed | `false` | |

---

## Output filename (not a YAML field)

| Component | Source | Value / Expression | Notes |
|-----------|--------|--------------------|-------|
| Device prefix | Derived | `{{ hostname \| lower }}` | `hostname` CSV value, lowercased |
| Suffix | Fixed | `-ztc-` | |
| Date | Fixed (runtime) | `YYYY-MM-DD` | Current date at time of generation |
| Extension | Fixed | `.yml` | |
