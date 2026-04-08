package task_bundle_detector

import rego.v1

# METADATA
# title: Tekton Task Bundle Detection
# description: Detects if an image is a Tekton task bundle by checking for Tekton annotations
# custom:
#   short_name: is_task_bundle

# Check if the current image is a Tekton task bundle
is_task_bundle if {
	manifest := ec.oci.image_manifest(input.image.ref)
	manifest != null
	some layer in manifest.layers
	_is_tekton_layer(layer)
}

# Helper: Check if a layer has Tekton annotations
_is_tekton_layer(layer) if {
	layer.annotations["dev.tekton.image.kind"]
	layer.annotations["dev.tekton.image.name"]
	layer.annotations["dev.tekton.image.apiVersion"]
}

# Get bundle metadata
bundle_info := info if {
	manifest := ec.oci.image_manifest(input.image.ref)
	manifest != null

	# Collect all Tekton resources in the bundle
	resources := [resource |
		some layer in manifest.layers
		_is_tekton_layer(layer)
		resource := {
			"kind": layer.annotations["dev.tekton.image.kind"],
			"name": layer.annotations["dev.tekton.image.name"],
			"apiVersion": layer.annotations["dev.tekton.image.apiVersion"],
			"digest": layer.digest,
		}
	]

	info := {
		"is_bundle": count(resources) > 0,
		"resources": resources,
		"total_resources": count(resources),
	}
}

# Warn if not a task bundle (for visibility during testing)
warn contains result if {
	not is_task_bundle
	result := {
		"code": "task_bundle_detector.not_a_bundle",
		"msg": sprintf("Image %s is not a Tekton task bundle", [input.image.ref]),
	}
}

# Info message when bundle is detected
warn contains result if {
	is_task_bundle
	info := bundle_info
	result := {
		"code": "task_bundle_detector.bundle_detected",
		"msg": sprintf("Detected Tekton bundle with %d resources: %v", [info.total_resources, info.resources]),
	}
}
