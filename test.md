# ZTC Generator

Generate Zero Touch Configuration (`.yml`) files from a Jinja2 template and a CSV input file.

`ztc_generator.py` renders one YAML file per CSV row, making it easy to produce device-specific ZTC files from a shared template.

## Requirements

- Python 3.9 or later
- `jinja2`
- `ruamel.yaml`

Install dependencies:

```powershell
pip install jinja2 ruamel.yaml
```

## Project Files

| File | Description |
|------|-------------|
| `ztc_generator.py` | Main generator script |
| `spoke-ec10106.j2` | Jinja2 template for spoke appliances |
| `spoke-ec10106-inputs.csv` | Reference CSV input for use with the template |
| `ztc_inputs.xlsx` | Source spreadsheet for building the CSV |
| `output/` | Default directory for generated YAML files |

## Usage

```powershell
python ztc_generator.py <template> <csv> [-o <output-directory>]
```

### Arguments

| Argument | Description |
|----------|-------------|
| `<template>` | Path to the Jinja2 template file (`.j2`) |
| `<csv>` | Path to the CSV input file |
| `-o`, `--output` | Output directory for generated files (default: `output`) |

### Example

```powershell
python ztc_generator.py spoke-ec10106.j2 spoke-ec10106-inputs.csv -o output
```

On Windows you can also use `py` in place of `python`.

## How It Works

For each row in the CSV, the script:

1. Reads the row as a set of template variables
2. Renders the Jinja2 template with those variables
3. Writes the result to a YAML file named:

```
<hostname>-ztc-YYYY-MM-DD.yml
```

**Example output filename:**

```
ops-test1-router-ztc-2026-04-16.yml
```

The output directory is created automatically if it does not already exist.

## CSV Requirements

The input CSV must:

- Include a header row
- Use column names that match the variable names referenced in the template
- Include a `hostname` column — this is used to build the output filename

### Required columns (for `spoke-ec10106.j2`)

| Column | Description |
|--------|-------------|
| `serial` | Device serial number |
| `hostname` | Device hostname (used in output filename) |
| `softwareVersion` | Target software version |
| `group` | Orchestrator group name |
| `site` | Site name |
| `siteCode` | Numeric site code (used in IP addressing and BGP ASN) |
| `address`, `address2`, `city`, `state`, `zipCode`, `country` | Physical address fields |
| `latitude`, `longitude` | Optional GPS coordinates |
| `name`, `email` | Contact details |
| `totalOutboundBandwidth`, `totalInboundBandwidth` | WAN bandwidth in kbps |
| `secWanInterfaceName` | Secondary WAN interface name — leave blank to omit the secondary WAN block |
| `secWanInterfaceLabel`, `secWanInterfaceComment` | Secondary WAN labels |
| `secWanIpAddressMask`, `secWanNextHop` | Secondary WAN IP configuration |
| `secWanOutboundMaxBandwidth`, `secWanInboundMaxBandwidth` | Secondary WAN bandwidth in kbps |
| `secWanFirewallMode`, `secWanBehindNat`, `secWanZone` | Secondary WAN firewall settings |

## Template Overview

`spoke-ec10106.j2` is a YAML file with Jinja2 expressions embedded. The template produces a ZTC file structured as:

| Section | Description |
|---------|-------------|
| `applianceInfo` | Hostname, software version, group, site, location, and contact |
| `templateGroups` | Template group assignments |
| `businessIntentOverlays` | Overlay membership |
| `deploymentInfo` | WAN/LAN interfaces, bandwidth, and DHCP relay |
| `ecLicensing` | Licensing tier settings |
| `segmentLocalRoutes` | Route advertisement behaviour |
| `segmentBgpSystems` | BGP ASN and router ID |
| `linkAggregation` | LAN bond (LACP) configuration |
| `poE` | PoE port settings |

### Variable substitution

CSV column values are injected using standard Jinja2 expressions:

```jinja2
hostname: {{ hostname }}
site: {{ site }}
```

### Derived values

Some values are computed from CSV data inside the template. For example, LAN IP addresses are built from `siteCode`:

```jinja2
ipAddressMask: 10.{{ siteCode }}.175.50/24
```

The BGP ASN is derived by zero-padding `siteCode` to two digits:

```jinja2
asn: 650{{ "%02d" | format(siteCode | int) }}
```

So `siteCode` of `5` produces ASN `65005`, and `12` produces `65012`.

### Conditional sections

The secondary WAN interface block is only included when `secWanInterfaceName` has a value:

```jinja2
{% if secWanInterfaceName %}
    - interfaceName: {{ secWanInterfaceName }}
      ...
{% endif %}
```

Leave the `secWanInterfaceName` column blank in the CSV to omit this block entirely.

## Example Workflow

1. Populate device data in `spoke-ec10106-inputs.csv` (or export from `ztc_inputs.xlsx`)
2. Update `spoke-ec10106.j2` if the template needs changes
3. Run the generator:
   ```powershell
   python ztc_generator.py spoke-ec10106.j2 spoke-ec10106-inputs.csv -o output
   ```
4. Review the generated files in `output/`

### Example console output

```
Created output directory: output
Generated: output\ops-test1-router-ztc-2026-04-16.yml
Generated: output\ops-test2-router-ztc-2026-04-16.yml
Generated: output\ops-hd-router-ztc-2026-04-16.yml
```

## Error Handling

The script exits with a non-zero status and prints an error message if:

- The template file does not exist
- The CSV file does not exist
- A template variable references a column that is missing from the CSV

**Example:**

```
Error: Template file not found: spoke-ec10106.j2
```

## Notes

- Output filenames use the lowercase value of `hostname` plus the current date
- YAML output is written directly from the rendered template rather than being re-serialised, which preserves comments and formatting from the template file
- `ruamel.yaml` is imported but not used for output serialisation — it is available for future use if parsed YAML manipulation is needed

# ZTC Variable Reference

This document lists every field produced in the ZTC output YAML, showing whether each value comes from the CSV input, is derived from CSV data inside the template, or is hardcoded in the template.

**Source key**

| Source  | Meaning                                                             |
|---------|---------------------------------------------------------------------|
| CSV     | Value is read directly from a CSV column of the same name           |
| Derived | Value is computed inside the template using one or more CSV columns |
| Fixed   | Value is hardcoded in the template and does not vary per device     |

---

## Special CSV inputs

These two CSV columns are not mapped directly to a named YAML field. `serial` is rendered as a comment at the top of the output file; `siteCode` is used only inside derived expressions and never appears as a standalone field.

| Variable    | Source | Purpose                                          | Notes                                                                              |
|-------------|--------|--------------------------------------------------|------------------------------------------------------------------------------------|
| `serial`    | CSV    | Written as a YAML comment at the top of the file | Rendered as `# Serial: {{ serial }}` before the `applianceInfo` block              |
| `siteCode`  | CSV    | Drives all derived IP addresses and the BGP ASN  | Integer site number — used in LAN/WAN IPs and `asn: 650XX`; never output directly |

---

## applianceInfo

| Field             | Source | Value / Expression      | Notes                                         |
|-------------------|--------|-------------------------|-----------------------------------------------|
| `softwareVersion` | CSV    | `{{ softwareVersion }}` | Optional                                      |
| `hostname`        | CSV    | `{{ hostname }}`        | Mandatory                                     |
| `group`           | CSV    | `{{ group }}`           | Mandatory                                     |
| `site`            | CSV    | `{{ site }}`            | Mandatory                                     |
| `clusterProfile`  | Fixed  | *(empty)*               |                                               |
| `networkRole`     | Fixed  | `non-hub`               |                                               |
| `region`          | Fixed  | *(empty)*               |                                               |
| `address`         | CSV    | `{{ address }}`         | Optional if latitude and longitude used       |
| `address2`        | CSV    | `{{ address2 }}`        | Optional                                      |
| `city`            | CSV    | `{{ city }}`            | Optional if latitude and longitude used       |
| `state`           | CSV    | `{{ state }}`           | Optional if latitude and longitude used       |
| `zipCode`         | CSV    | `{{ zipCode }}`         | Optional if latitude and longitude used       |
| `country`         | CSV    | `{{ country }}`         | Optional if latitude and longitude used       |
| `latitude`        | CSV    | `{{ latitude }}`        | Optional if address etc. used                 |
| `longitude`       | CSV    | `{{ longitude }}`       | Optional if address etc. used                 |
| `name`            | CSV    | `{{ name }}`            | Optional                                      |
| `email`           | CSV    | `{{ email }}`           | Optional                                      |

---

## templateGroups

| Field       | Source | Value                    | Notes |
|-------------|--------|--------------------------|-------|
| `groups[0]` | Fixed  | `Default Template Group` |       |
| `groups[1]` | Fixed  | `Spoke Defaults`         |       |

---

## businessIntentOverlays

| Field         | Source | Value            | Notes |
|---------------|--------|------------------|-------|
| `overlays[0]` | Fixed  | `RealTime`       |       |
| `overlays[1]` | Fixed  | `CriticalApps`   |       |
| `overlays[2]` | Fixed  | `DefaultOverlay` |       |

---

## deploymentInfo

### Top-level

| Field                    | Source | Value / Expression             | Notes               |
|--------------------------|--------|--------------------------------|---------------------|
| `deploymentMode`         | Fixed  | `inline-router`                |                     |
| `serverPerSegment`       | Fixed  | `false`                        |                     |
| `totalOutboundBandwidth` | CSV    | `{{ totalOutboundBandwidth }}` | Mandatory - In kbps |
| `totalInboundBandwidth`  | CSV    | `{{ totalInboundBandwidth }}`  | Mandatory - In kbps |

### deploymentInterfaces — LAN (fixed per-site, IP derived from siteCode)

| Field              | Interface       | Source  | Value / Expression            | Notes                     |
|--------------------|-----------------|---------|-------------------------------|---------------------------|
| `interfaceName`    | Operations LAN  | Fixed   | `blan0.175`                   |                           |
| `interfaceType`    | Operations LAN  | Fixed   | `lan`                         |                           |
| `interfaceComment` | Operations LAN  | Fixed   | `Operations`                  |                           |
| `ipAddressMask`    | Operations LAN  | Derived | `10.{{ siteCode }}.175.50/24` | Third octet is always 175 |
| `nextHop`          | Operations LAN  | Fixed   | *(empty)*                     |                           |
| `segment`          | Operations LAN  | Fixed   | `Default`                     |                           |
| `zone`             | Operations LAN  | Fixed   | `Operations`                  |                           |
| `interfaceName`    | Management LAN  | Fixed   | `blan0.190`                   |                           |
| `interfaceType`    | Management LAN  | Fixed   | `lan`                         |                           |
| `interfaceComment` | Management LAN  | Fixed   | `Management`                  |                           |
| `ipAddressMask`    | Management LAN  | Derived | `10.{{ siteCode }}.190.50/24` | Third octet is always 190 |
| `nextHop`          | Management LAN  | Fixed   | *(empty)*                     |                           |
| `segment`          | Management LAN  | Fixed   | `Default`                     |                           |
| `zone`             | Management LAN  | Fixed   | `Management`                  |                           |
| `interfaceName`    | Staff LAN       | Fixed   | `blan0.242`                   |                           |
| `interfaceType`    | Staff LAN       | Fixed   | `lan`                         |                           |
| `interfaceComment` | Staff LAN       | Fixed   | `Staff`                       |                           |
| `ipAddressMask`    | Staff LAN       | Derived | `10.{{ siteCode }}.242.50/24` | Third octet is always 242 |
| `nextHop`          | Staff LAN       | Fixed   | *(empty)*                     |                           |
| `segment`          | Staff LAN       | Fixed   | `Default`                     |                           |
| `zone`             | Staff LAN       | Fixed   | `Staff`                       |                           |
| `interfaceName`    | Contractors LAN | Fixed   | `blan0.243`                   |                           |
| `interfaceType`    | Contractors LAN | Fixed   | `lan`                         |                           |
| `interfaceComment` | Contractors LAN | Fixed   | `Contractors`                 |                           |
| `ipAddressMask`    | Contractors LAN | Derived | `10.{{ siteCode }}.243.50/24` | Third octet is always 243 |
| `nextHop`          | Contractors LAN | Fixed   | *(empty)*                     |                           |
| `segment`          | Contractors LAN | Fixed   | `Default`                     |                           |
| `zone`             | Contractors LAN | Fixed   | `Staff`                       |                           |

### deploymentInterfaces — Primary WAN (Radio WAN, always present)

| Field                  | Source  | Value / Expression             | Notes                          |
|------------------------|---------|--------------------------------|--------------------------------|
| `interfaceName`        | Fixed   | `lan2.3003`                    |                                |
| `interfaceLabel`       | Fixed   | `RWAN`                         |                                |
| `interfaceType`        | Fixed   | `wan`                          |                                |
| `interfaceComment`     | Fixed   | `Radio WAN`                    |                                |
| `ipAddressMask`        | Derived | `10.254.254.{{ siteCode }}/26` | Fourth octet equals `siteCode` |
| `nextHop`              | Fixed   | `10.254.254.1`                 |                                |
| `outboundMaxBandwidth` | Fixed   | `50000`                        | kbps                           |
| `inboundMaxBandwidth`  | Fixed   | `50000`                        | kbps                           |
| `firewallMode`         | Fixed   | `stateful`                     |                                |
| `behindNat`            | Fixed   | `none`                         |                                |
| `zone`                 | Fixed   | `RadioWAN`                     |                                |

### deploymentInterfaces — Secondary WAN (optional, included only when `secWanInterfaceName` is not blank. ALL CSV items are Mandatory if `secWanInterfaceName` is not blank.)

| Field                  | Source | Value / Expression                 | Notes                                                   |
|------------------------|--------|------------------------------------|---------------------------------------------------------|
| `interfaceName`        | CSV    | `{{ secWanInterfaceName }}`        | Optional - Leave blank in CSV to omit this entire block |
| `interfaceLabel`       | CSV    | `{{ secWanInterfaceLabel }}`       |                                                         |
| `interfaceType`        | Fixed  | `wan`                              |                                                         |
| `interfaceComment`     | CSV    | `{{ secWanInterfaceComment }}`     |                                                         |
| `ipAddressMask`        | CSV    | `{{ secWanIpAddressMask }}`        | Full CIDR notation, e.g. `192.0.2.10/30`                |
| `nextHop`              | CSV    | `{{ secWanNextHop }}`              |                                                         |
| `outboundMaxBandwidth` | CSV    | `{{ secWanOutboundMaxBandwidth }}` | kbps                                                    |
| `inboundMaxBandwidth`  | CSV    | `{{ secWanInboundMaxBandwidth }}`  | kbps                                                    |
| `firewallMode`         | CSV    | `{{ secWanFirewallMode }}`         | e.g. `statefulSNAT`                                     |
| `behindNat`            | CSV    | `{{ secWanBehindNat }}`            | e.g. `auto` or `none`                                   |
| `zone`                 | CSV    | `{{ secWanZone }}`                 | e.g. `Internet`                                         |

### dhcpInfo (DHCP relay, same for all four LAN interfaces)

| Field                 | Source | Value                                              | Notes                       |
|-----------------------|--------|----------------------------------------------------|-----------------------------|
| `dhcpInterfaceName`   | Fixed  | `blan0.175`, `blan0.190`, `blan0.242`, `blan0.243` | One entry per LAN interface |
| `dhcpType`            | Fixed  | `relay`                                            |                             |
| `dhcpProxyServers[0]` | Fixed  | `10.160.90.1`                                      |                             |
| `dhcpProxyServers[1]` | Fixed  | `10.7.190.10`                                      |                             |

---

## ecLicensing

| Field               | Source | Value     | Notes                      |
|---------------------|--------|-----------|----------------------------|
| `useDefaultAccount` | Fixed  | `true`    |                            |
| `bandwidthLevel`    | Fixed  | `1000000` | kbps (1 Gbps licence tier) |
| `boost`             | Fixed  | `0`       |                            |

---

## segmentLocalRoutes

| Field                         | Source | Value           | Notes |
|-------------------------------|--------|-----------------|-------|
| `segment`                     | Fixed  | `Default`       |       |
| `useSharedSubnetInfo`         | Fixed  | `true`          |       |
| `advertiseLocalLanSubnets`    | Fixed  | `true`          |       |
| `advertiseLocalWanSubnets`    | Fixed  | `false`         |       |
| `localMetric`                 | Fixed  | `50`            |       |
| `localCommunities`            | Fixed  | *(empty)*       |       |
| `redistOspfToSubnetShare`     | Fixed  | `false`         |       |
| `ospfRedistMetric`            | Fixed  | `0`             |       |
| `ospfRedistTag`               | Fixed  | `0`             |       |
| `filterRoutesWithLocalASN`    | Fixed  | `true`          |       |
| `redistToSDwanFabricRouteMap` | Fixed  | `LoopbacksOnly` |       |

---

## segmentBgpSystems

| Field             | Source  | Value / Expression                           | Notes                                           |
|-------------------|---------|----------------------------------------------|-------------------------------------------------|
| `segment`         | Fixed   | `Default`                                    |                                                 |
| `enable`          | Fixed   | `true`                                       |                                                 |
| `asn`             | Derived | `650{{ "%02d" \| format(siteCode \| int) }}` | `siteCode` 5 → `65005`; `siteCode` 12 → `65012` |
| `routerId`        | Fixed   | `172.25.25.172`                              |                                                 |
| `propagateAsPath` | Fixed   | `true`                                       |                                                 |

---

## linkAggregation

| Field                | Source | Value                      | Notes          |
|----------------------|--------|----------------------------|----------------|
| `channelGroup`       | Fixed  | `blan0`                    |                |
| `interfaces`         | Fixed  | `lan0, lan1`               |                |
| `mtu`                | Fixed  | `1500`                     |                |
| `mode`               | Fixed  | `4`                        | LACP (802.3ad) |
| `lacpRate`           | Fixed  | `slow`                     |                |
| `lacpSystemPriority` | Fixed  | `65535`                    |                |
| `lacpComment`        | Fixed  | `LACP bond for LAN Access` |                |
| `isForceDelete`      | Fixed  | `true`                     |                |

---

## poE

| Field                       | Source | Value   | Notes |
|-----------------------------|--------|---------|-------|
| `powerMode`                 | Fixed  | `2`     |       |
| `interfaces[lan0].priority` | Fixed  | `0`     |       |
| `interfaces[lan0].enable`   | Fixed  | `false` |       |
| `interfaces[lan1].priority` | Fixed  | `0`     |       |
| `interfaces[lan1].enable`   | Fixed  | `false` |       |

---

## Output filename (not a YAML field)

| Component     | Source          | Value / Expression        | Notes                              |
|---------------|-----------------|---------------------------|------------------------------------|
| Device prefix | Derived         | `{{ hostname \| lower }}` | `hostname` CSV value, lowercased   |
| Suffix        | Fixed           | `-ztc-`                   |                                    |
| Date          | Fixed (runtime) | `YYYY-MM-DD`              | Current date at time of generation |
| Extension     | Fixed           | `.yml`                    |                                    |
