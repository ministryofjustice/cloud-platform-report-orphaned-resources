# DEPRECATED Orphaned AWS Reporter

This code has been moved [here](https://github.com/ministryofjustice/cloud-platform-how-out-of-date-are-we)

[![Releases](https://img.shields.io/github/release/ministryofjustice/cloud-platform-report-orphaned-resources/all.svg?style=flat-square)](https://github.com/ministryofjustice/cloud-platform-report-orphaned-resources/releases)

Output a JSON document, suitable for posting to [How Out Of Date Are We],
listing all the AWS resources which exist but are not mentioned in any of the
`terraform.tfstate` files in the Cloud Platform terraform state S3 bucket.

## Running

See the `makefile` for an example of how to use the docker image this project
creates.

## Updating

This project contains a github action which pushes a new, tagged image to
Docker Hub whenever a new project release is created.

To update the docker image, merge your changes and then create a new release.

[How Out Of Date Are We]: https://github.com/ministryofjustice/cloud-platform-how-out-of-date-are-we
