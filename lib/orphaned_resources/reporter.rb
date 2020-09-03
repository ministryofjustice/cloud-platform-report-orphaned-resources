module OrphanedResources
  class Reporter
    def run
      s3 = Aws::S3::Resource.new(region: "eu-west-1", profile: ENV["AWS_PROFILE"])
      ec2 = Aws::EC2::Client.new(region: "eu-west-2", profile: ENV["AWS_PROFILE"])
      route53 = Aws::Route53::Client.new(region: "eu-west-2", profile: ENV["AWS_PROFILE"])

      @aws = OrphanedResources::AwsResources.new(
        s3client: s3,
        ec2client: ec2,
        route53client: route53,
      )

      @terraform = OrphanedResources::TerraformStateManager.new(
        s3client: s3,
        bucket: "cloud-platform-terraform-state",
        cache_dir: "state-files"
      )

      {
        hosted_zones: compare(:hosted_zones),
        internet_gateways: compare(:internet_gateways),
        subnets: compare(:subnets),
        nat_gateways: compare(:nat_gateways),
        vpcs: compare(:vpcs),
        security_groups: compare(:security_groups),
        route_tables: compare(:route_tables),
        route_table_associations: compare(:route_table_associations),
      }
    end

    private

    def compare(method)
      (@aws.send(method) - @terraform.send(method)).sort
    end
  end
end
