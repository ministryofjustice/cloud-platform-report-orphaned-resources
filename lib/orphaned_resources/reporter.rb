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
        nat_gateways: compare2(:nat_gateways),
        hosted_zones: compare2(:hosted_zones),
        internet_gateways: compare2(:internet_gateways),
        subnets: compare2(:subnets),
        vpcs: compare2(:vpcs),
        security_groups: compare2(:security_groups),
        route_tables: compare(:route_tables),
        route_table_associations: compare(:route_table_associations),
      }
    end

    private

    def compare(method)
      (@aws.send(method) - @terraform.send(method)).sort
    end

    def compare2(method)
      ResourceTuple.subtract_lists(
        @aws.send(method),
        @terraform.send(method)
      ).sort
    end
  end
end
