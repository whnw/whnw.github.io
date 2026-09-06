# Handoff: Build metadata for multi-project BBA repositories

## Current context

- Working repository: `/Volumes/D/workspace/bba_platform`
- No repository files were changed in this conversation.
- The user asked how to provide build information to an AI agent so that, after modifying code, it can run an appropriate incremental build instead of always performing a full build.
- The user has multiple projects. Each project root is a Git repository.
- Each project has `platform/build` as the build directory, a top-level `Makefile`, and a `makes/` directory containing module Makefiles.
- Builds require explicit `MODEL=XXX` and `SPEC=XXX`.
- `platform/build/${MODEL}/${SPEC}/config.bba` contains application-layer macro definitions.
- `platform/build/${MODEL}/${SPEC}/config.kernel` contains kernel macro definitions.
- Different projects have different models, specs, and Docker containers; the remaining build conventions are shared.
- Example full build command supplied by the user:
  ```sh
  docker exec -u bba -t nx505 bash -c "cd ${TOP}/platform/build && make MODEL=NX505V2 SPEC=EU env_build boot_build kernel_build modules_build apps_build fs_build image_build supplier_flash_build"
  ```

## Recommendation already provided

Use repository-local agent instructions plus a checked-in build wrapper:

1. Put project-specific build metadata and incremental-target rules in the project-root `AGENTS.md` (or `.github/copilot-instructions.md`).
2. Optionally put shared conventions in the user-level Copilot instructions file.
3. Add a wrapper such as `tools/ai-build.sh` that:
   - requires `MODEL`, `SPEC`, and `TOP`;
   - accepts an explicit Docker container override;
   - verifies both configuration files exist;
   - runs `docker exec` and `make` from the container build directory;
   - lets the model invoke a short, stable command rather than reconstructing the full Docker command.
4. In `AGENTS.md`, instruct the agent to inspect `git diff`, select the smallest sufficient target, and avoid a full build unless requested or required by dependencies.

Suggested incremental mapping from the previous response:

| Changed area | Target |
|---|---|
| environment code | `env_build` |
| bootloader code | `boot_build` |
| kernel code or `config.kernel` | `kernel_build` |
| module code or module Makefiles | `modules_build` |
| application code or `config.bba` | `apps_build` |
| filesystem files | `fs_build` |
| image packaging | `image_build` |
| supplier flashing scripts | `supplier_flash_build` |

Example wrapper invocation:

```sh
MODEL=NX505V2 SPEC=EU TOP="$PWD" \
  ./tools/ai-build.sh apps_build modules_build
```

Example full build:

```sh
MODEL=NX505V2 SPEC=EU TOP="$PWD" \
  ./tools/ai-build.sh \
  env_build boot_build kernel_build modules_build apps_build \
  fs_build image_build supplier_flash_build
```

## Important follow-up

The previous response proposed a conceptual wrapper but did not create it. If the user now wants implementation, inspect the repository’s existing scripts, Docker path conventions, Makefiles, and any current instruction files before editing. In particular, confirm whether the host path `$TOP` is valid inside the container; the example command uses `${TOP}` in the container shell, while the proposed wrapper assumed `/workspace` as the container-side project root, which must not be hard-coded without checking the project setup.

The next implementation should preferably:

- preserve each project’s existing Docker/container conventions;
- keep project-specific values in a config file or `AGENTS.md`;
- validate the model/spec configuration files before invoking Make;
- use safe shell quoting;
- document how to select incremental targets and when a full build is necessary;
- run the smallest existing validation relevant to any changed scripts.

## Suggested skills

- `customize-cloud-agent`: call this only if the user expands the request to configure Copilot cloud-agent setup, `copilot-setup-steps.yml`, runners, or preinstalled build dependencies.
- No additional installed skill is required for the current repository-local `AGENTS.md` and build-wrapper design.

