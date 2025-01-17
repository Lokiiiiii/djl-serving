#!/usr/bin/env bash
set -e

# Function to validate numeric variables
validate_numeric_variable() {
  local var_name="$1"
  local var_value="$2"

  if [[ "${var_value}" =~ ^[0-9]+$ ]]; then
    echo "${var_name} is valid: ${var_value}"
  else
    echo "${var_name} is invalid: ${var_value}"
    exit 1
  fi
}

# Delay for start of profile capture to avoid profiling unintended setup steps
NSYS_PROFILE_DELAY=${NSYS_PROFILE_DELAY:-30}
# Security Validation
validate_numeric_variable "NSYS_PROFILE_DELAY" "${NSYS_PROFILE_DELAY}"

# Duration for profile capture to avoid diluting the profile.
NSYS_PROFILE_DURATION=${NSYS_PROFILE_DURATION:-600}
# Security Validation
validate_numeric_variable "NSYS_PROFILE_DURATION" "${NSYS_PROFILE_DURATION}"

# Duration for profile capture to avoid diluting the profile.
NSYS_PROFILE_TRACE=${NSYS_PROFILE_TRACE:-"cuda,nvtx,osrt,cudnn,cublas,mpi,python-gil"}
# Security Validation
if [[ "$NSYS_PROFILE_TRACE" =~ ^[a-z0-9,-]+$ ]]; then
  echo "NSYS_PROFILE_TRACE is valid: ${NSYS_PROFILE_TRACE}"
else
  echo "NSYS_PROFILE_TRACE is invalid: ${NSYS_PROFILE_TRACE}"
  echo "Only lowercase letters, numbers, commas, and hyphens are allowed."
  exit 1
fi

if [ -n "${S3_DEBUG_PATH}" ]; then
  # Validate the S3 path format
  if [[ ! "$S3_DEBUG_PATH" =~ ^s3://[a-z0-9.\-]+(/([a-zA-Z0-9.\-_]+)*)?/$ ]]; then
    echo "Error: S3_DEBUG_PATH must be of the format s3://bucket/key/"
    exit 1
  fi
fi

nsys profile \
  --kill=sigkill \
  --wait=primary \
  --show-output true \
  --osrt-threshold 10000 \
  --delay "${NSYS_PROFILE_DELAY}" \
  --duration "${NSYS_PROFILE_DURATION}" \
  --python-backtrace=cuda \
  --trace "${NSYS_PROFILE_TRACE}" \
  --cudabacktrace all:10000 \
  --output "$(hostname).nsys-rep" \
  -- djl-serving "$@" || true   # Nsys exits with non-zero code when the application is terminated due to a timeout which is expected

if [ -n "${S3_DEBUG_PATH}" ]; then
  s5cmd cp /opt/djl/*.nsys-rep "$S3_DEBUG_PATH"
fi