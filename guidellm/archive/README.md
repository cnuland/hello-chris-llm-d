# Archived GuideLLM Files

This directory contains deprecated or outdated GuideLLM configuration files that were created during development and testing but are no longer actively used.

## Files in Archive

### TaskRun Iterations

These files represent various iterations of TaskRun configurations that were created during debugging and testing:

- **`guidellm-taskrun.yaml`** - Original TaskRun with incorrect shell syntax (`$(shell date +%s)`)
- **`guidellm-taskrun-corrected.yaml`** - Fixed version with hardcoded timestamp `1753973075`
- **`guidellm-taskrun-fixed.yaml`** - Another iteration with hardcoded timestamp `1753973032`
- **`guidellm-taskrun-simple-fixed.yaml`** - Simplified version with hardcoded timestamp `1753973105`

## Why Archived

These files are preserved for historical reference but are not recommended for use because:

1. **Hardcoded Timestamps**: They contain hardcoded timestamps that make them unsuitable as reusable templates
2. **Syntax Issues**: Some contain incorrect Kubernetes/shell syntax
3. **Superseded**: They have been replaced by better, more maintainable templates in the `utils/` directory

## Current Alternatives

Instead of these archived files, use:

- **`utils/taskrun-template.yaml`** - Template with proper dynamic naming
- **`utils/taskrun-text-prompts.yaml`** - Template for text-based prompt testing
- **`utils/guidellm-job-advanced.yaml`** - Advanced Job configuration

## Cleanup

These files can be safely deleted if historical reference is not needed:

```bash
rm -rf guidellm/archive/
```

However, they are kept as documentation of the development process and troubleshooting steps.
