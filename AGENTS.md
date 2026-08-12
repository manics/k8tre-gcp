Do not attempt to run anything on Google Cloud Platform as credentials are not yet available.

Run `prek` (a modern version of pre-commit, configured in `.pre-commit-config.yaml`) to format and lint the code. Add `tflint-ignore` exclusions where it is the most efficient option, do not fix every possible tflint problem unless it is a meaningful improvement. Make sure `terraform validate` passes. These executables are under `/home/ubuntu/miniforge3/envs/cloud/bin`. Run `terraform init` (but without a remote backend) if needed for these checks.

