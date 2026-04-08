package task_extractor

import rego.v1
import data.task_bundle_detector

# METADATA
# title: Tekton Task Bundle Extractor
# description: Extracts task definitions from Tekton task bundle layers
# custom:
#   short_name: extract_tasks

# Extract all task definitions from the bundle
# Returns an array of task objects
task_definitions := tasks if {
	task_bundle_detector.is_task_bundle
	manifest := ec.oci.image_manifest(input.image.ref)
	manifest != null

	# Build repo reference from input
	repo := _repo_from_ref(input.image.ref)

	# Extract tasks from all task layers
	tasks := [task |
		some layer in manifest.layers
		layer.annotations["dev.tekton.image.kind"] == "task"
		task_name := layer.annotations["dev.tekton.image.name"]

		# Build blob reference: repo@digest
		blob_ref := sprintf("%s@%s", [repo, layer.digest])

		# Try to extract task definition from blob
		# Tekton bundles store tasks as YAML/JSON in tar archives
		# Try common file paths within the tar
		task := _extract_task_from_blob(blob_ref, task_name)
		task != null
	]
}

# Helper to extract task from blob, trying multiple common paths
_extract_task_from_blob(blob_ref, task_name) := task if {
	# Try: {taskname}.yaml
	path := sprintf("%s.yaml", [task_name])
	files := ec.oci.blob_files(blob_ref, [path])
	task := files[path]
}

_extract_task_from_blob(blob_ref, _) := task if {
	# Try: task.yaml
	files := ec.oci.blob_files(blob_ref, ["task.yaml"])
	task := files["task.yaml"]
}

_extract_task_from_blob(blob_ref, _) := task if {
	# Try: Task.yaml
	files := ec.oci.blob_files(blob_ref, ["Task.yaml"])
	task := files["Task.yaml"]
}

_extract_task_from_blob(blob_ref, _) := task if {
	# Try: tekton.yaml
	files := ec.oci.blob_files(blob_ref, ["tekton.yaml"])
	task := files["tekton.yaml"]
}

# If all else fails, try to parse blob content directly as JSON
_extract_task_from_blob(blob_ref, _) := task if {
	blob_content := ec.oci.blob(blob_ref)
	blob_content != null
	# Try to parse as JSON directly (in case blob is raw JSON)
	task := json.unmarshal(blob_content)
}

# Helper to extract repository from image reference
_repo_from_ref(ref) := repo if {
	parts := split(ref, "@")
	repo := parts[0]
}

_repo_from_ref(ref) := repo if {
	not contains(ref, "@")
	parts := split(ref, ":")
	repo := parts[0]
}

# Provide task count for debugging
task_count := count(task_definitions)

# Warn if bundle has no tasks (should not happen for valid bundles)
warn contains result if {
	task_bundle_detector.is_task_bundle
	task_count == 0
	result := {
		"code": "task_extractor.no_tasks_found",
		"msg": sprintf("Task bundle detected but no tasks extracted from %s", [input.image.ref]),
	}
}

# Info message with task count
warn contains result if {
	task_bundle_detector.is_task_bundle
	task_count > 0
	result := {
		"code": "task_extractor.tasks_extracted",
		"msg": sprintf("Extracted %d task(s) from bundle", [task_count]),
	}
}
