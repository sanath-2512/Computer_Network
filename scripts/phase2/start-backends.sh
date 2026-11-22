#!/bin/bash
set -e
"$(dirname "$0")/start-backend-A.sh"
"$(dirname "$0")/start-backend-B.sh"
