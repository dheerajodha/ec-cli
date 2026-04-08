package task_validation

import rego.v1
import data.task_bundle_detector
import data.task_extractor

# METADATA
# title: Tekton Task Validation
# description: Validates task definitions extracted from task bundles
# custom:
#   short_name: validate_tasks

# Validate task kind field
deny contains result if {
	task_bundle_detector.is_task_bundle
	some task in task_extractor.task_definitions

	# Check kind field exists
	not task.kind
	result := {
		"code": "task_validation.kind_missing",
		"msg": sprintf("Task is missing 'kind' field: %s", [_task_identifier(task)]),
		"term": task,
	}
}

deny contains result if {
	task_bundle_detector.is_task_bundle
	some task in task_extractor.task_definitions

	# Check kind is "Task"
	task.kind
	task.kind != "Task"
	result := {
		"code": "task_validation.kind_invalid",
		"msg": sprintf("Task has invalid kind '%s', expected 'Task': %s", [task.kind, _task_identifier(task)]),
		"term": task.kind,
	}
}

# Validate task has metadata.name
deny contains result if {
	task_bundle_detector.is_task_bundle
	some task in task_extractor.task_definitions

	not task.metadata.name
	result := {
		"code": "task_validation.name_missing",
		"msg": sprintf("Task is missing metadata.name: %v", [task]),
	}
}

# Validate task has apiVersion
deny contains result if {
	task_bundle_detector.is_task_bundle
	some task in task_extractor.task_definitions

	not task.apiVersion
	result := {
		"code": "task_validation.apiversion_missing",
		"msg": sprintf("Task is missing apiVersion: %s", [_task_identifier(task)]),
	}
}

# Validate task has spec
deny contains result if {
	task_bundle_detector.is_task_bundle
	some task in task_extractor.task_definitions

	not task.spec
	result := {
		"code": "task_validation.spec_missing",
		"msg": sprintf("Task is missing spec: %s", [_task_identifier(task)]),
	}
}

# Validate task has at least one step
deny contains result if {
	task_bundle_detector.is_task_bundle
	some task in task_extractor.task_definitions

	task.spec
	not task.spec.steps
	result := {
		"code": "task_validation.steps_missing",
		"msg": sprintf("Task spec is missing steps: %s", [_task_identifier(task)]),
	}
}

deny contains result if {
	task_bundle_detector.is_task_bundle
	some task in task_extractor.task_definitions

	task.spec.steps
	count(task.spec.steps) == 0
	result := {
		"code": "task_validation.steps_empty",
		"msg": sprintf("Task spec has no steps: %s", [_task_identifier(task)]),
	}
}

# Validate each step has a name and image
deny contains result if {
	task_bundle_detector.is_task_bundle
	some task in task_extractor.task_definitions
	task.spec.steps

	some i, step in task.spec.steps
	not step.name
	result := {
		"code": "task_validation.step_name_missing",
		"msg": sprintf("Task %s step[%d] is missing name", [_task_identifier(task), i]),
	}
}

deny contains result if {
	task_bundle_detector.is_task_bundle
	some task in task_extractor.task_definitions
	task.spec.steps

	some i, step in task.spec.steps
	not step.image
	result := {
		"code": "task_validation.step_image_missing",
		"msg": sprintf("Task %s step[%d] '%s' is missing image", [_task_identifier(task), i, step.name]),
	}
}

# Helper to create a task identifier for error messages
_task_identifier(task) := name if {
	name := task.metadata.name
}

_task_identifier(task) := "<unnamed>" if {
	not task.metadata.name
}

# Success check - report when tasks are valid
warn contains result if {
	task_bundle_detector.is_task_bundle
	some task in task_extractor.task_definitions

	# Task is valid if it has all required fields
	task.kind == "Task"
	task.apiVersion
	task.metadata.name
	task.spec.steps
	count(task.spec.steps) > 0

	# All steps have name and image
	_all_steps_valid(task)

	result := {
		"code": "task_validation.task_valid",
		"msg": sprintf("Task %s passed basic validation", [task.metadata.name]),
	}
}

_all_steps_valid(task) if {
	every step in task.spec.steps {
		step.name
		step.image
	}
}
