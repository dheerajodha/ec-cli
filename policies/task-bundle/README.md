# Tekton Task Bundle Validation POC

This directory contains Rego policies for validating Tekton task bundles as OCI artifacts.

## Overview

This POC demonstrates running existing task policy checks against Tekton task bundles when executing `ec validate image`. The policies detect task bundles, extract task definitions, and validate them.

## Components

### 1. `task_bundle_detector.rego`
Detects if an image is a Tekton task bundle by checking for `dev.tekton.image.*` annotations on OCI manifest layers.

**Key functions:**
- `is_task_bundle` - Returns true if image is a task bundle
- `bundle_info` - Returns metadata about the bundle (resource count, kinds, names)

### 2. `task_extractor.rego`
Extracts task definitions from task bundle layers using EC's OCI built-ins.

**Key functions:**
- `task_definitions` - Returns array of parsed task objects
- Uses `ec.oci.blob_files()` to extract YAML from bundle layers

### 3. `task_validation.rego`
Validates extracted task definitions against Tekton task schema.

**Current validations:**
- `kind` field is "Task"
- Required fields: `apiVersion`, `metadata.name`, `spec`
- Task has at least one step
- Each step has `name` and `image`

## Usage

### Using the ECP config

```bash
ec validate image \
  --image <task-bundle-image-ref> \
  --policy policies/task-bundle/policy.yaml
```

### Using in a snapshot

Create a snapshot with a task bundle component:

```yaml
apiVersion: appstudio.redhat.com/v1alpha1
kind: ApplicationSnapshot
spec:
  components:
    - name: my-task-bundle
      containerImage: quay.io/my-org/my-task-bundle:v1.0
```

Then validate:

```bash
ec validate image \
  --snapshot snapshot.yaml \
  --policy policies/task-bundle/policy.yaml
```

## How it Works

1. **Detection**: For each component image, `task_bundle_detector` checks the OCI manifest for Tekton annotations
2. **Extraction**: If it's a task bundle, `task_extractor` fetches blob content and extracts task YAML
3. **Validation**: `task_validation` runs checks on extracted task definitions
4. **Results**: Violations, warnings, and successes are reported per-component

## Rego-Heavy Approach

This POC uses a **Rego-heavy architecture**:
- **No Go code changes** required for detection or extraction
- **OCI operations** handled by existing `ec.oci.*` built-ins:
  - `ec.oci.image_manifest()` - Get manifest with layer annotations  
  - `ec.oci.blob_files()` - Extract YAML/JSON from blob tar archives
  - `ec.oci.blob()` - Get raw blob content
- **Policy-driven** - All logic in Rego, easy to extend/modify

## Extending

To add more task validations:

1. Create new Rego files in this directory
2. Import `data.task_extractor` to access `task_definitions`
3. Write `deny` rules that validate each task
4. Update `policy.yaml` to include new modules

Example:

```rego
package task_advanced_validation

import rego.v1
import data.task_extractor

deny contains result if {
    some task in task_extractor.task_definitions
    # Your validation logic here
    result := {"code": "...", "msg": "..."}
}
```

## Testing

To test with a real task bundle:

```bash
# Example with a Konflux task bundle
ec validate image \
  --image quay.io/konflux-ci/tekton-catalog/task-buildah:0.1 \
  --policy policies/task-bundle/policy.yaml
```

## Future Enhancements

- Import and adapt policies from `github.com/conforma/policy/tree/main/policy/task`
- Add step image registry validation
- Add trusted artifacts pattern validation
- Add annotation format validation
- Support for rule data configuration
