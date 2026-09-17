// Vendored from https://github.com/Korin123/naming-convention (src/) so this repo builds without a
// private module registry. Same function and names as br/core:naming. To use a shared registry
// instead, add its alias to bicepconfig.json and change the imports back to br/<alias>:naming:<tag>.

// ============================================================================
// Azure Resource Naming Convention - User-Defined Functions
// 
// Pattern: {abbreviation}-{workload}-{env}-{instance}
// Example: st-magauto-prod-001 (or stmagautoprod001 for no-hyphen resources)
//
// Author: Korin Taunton
// ============================================================================

import { resourceAbbreviations } from './abbreviations.bicep'

// ----------------------------------------------------------------------------
// Core naming function
// Generates a resource name following the convention:
//   {prefix}-{workload}-{environment}-{instance}
// Automatically strips hyphens for resources that don't support them
// Automatically truncates to max length using uniqueString if needed
// ----------------------------------------------------------------------------
@export()
func getResourceName(resourceType string, workload string, environment string, instance string) string =>
  _buildName(resourceType, workload, environment, instance)

// ----------------------------------------------------------------------------
// Simplified naming function (no instance number)
// For resources where you only deploy one of that type per workload
// ----------------------------------------------------------------------------
@export()
func getResourceNameSimple(resourceType string, workload string, environment string) string =>
  _buildName(resourceType, workload, environment, '')

// ----------------------------------------------------------------------------
// Internal: build the name
// ----------------------------------------------------------------------------
func _buildName(resourceType string, workload string, environment string, instance string) string =>
  _applyMaxLength(
    resourceType,
    _applyHyphens(
      resourceType,
      resourceAbbreviations[resourceType].prefix,
      toLower(workload),
      toLower(environment),
      instance
    )
  )

// ----------------------------------------------------------------------------
// Internal: join segments with or without hyphens based on resource type
// ----------------------------------------------------------------------------
func _applyHyphens(resourceType string, prefix string, workload string, environment string, instance string) string =>
  resourceAbbreviations[resourceType].allowHyphens
    ? _joinWithHyphens(prefix, workload, environment, instance)
    : _joinWithoutHyphens(prefix, workload, environment, instance)

func _joinWithHyphens(prefix string, workload string, environment string, instance string) string =>
  empty(instance)
    ? '${prefix}-${workload}-${environment}'
    : '${prefix}-${workload}-${environment}-${instance}'

func _joinWithoutHyphens(prefix string, workload string, environment string, instance string) string =>
  empty(instance)
    ? '${prefix}${workload}${environment}'
    : '${prefix}${workload}${environment}${instance}'

// ----------------------------------------------------------------------------
// Internal: truncate name if it exceeds max length
// Uses a hash suffix to maintain uniqueness when truncated
// ----------------------------------------------------------------------------
func _applyMaxLength(resourceType string, name string) string =>
  length(name) > resourceAbbreviations[resourceType].maxLength
    ? take(name, resourceAbbreviations[resourceType].maxLength)
    : name
