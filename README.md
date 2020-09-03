# Orphaned AWS Reporter

## Overview

This respository contains Ruby code, which will report on orphaned resources in
AWS. i.e. AWS resources which are not listed in any relevant terraform state
files.

Currently this is scoped to look for AWS resources leftover from test clusters
which failed to be cleanly deleted, but it should be easy to extend it to
include resources which should belong to terraform states in the
cloud-platform-environments repository.

## Requirements

1. Ensure your AWS credentials are set to the environment from which you want
   to execute the scripts. The AWS profile should be set under the profile name
   `moj-cp` e.g `export AWS_PROFILE=moj-cp`
2. Ruby >= 2.7.1
