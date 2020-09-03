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
        prefixes: [
          "cloud-platform-network",
          "cloud-platform",
          "cloud-platform-eks",
          "cloud-platform-environments",
        ],
        cache_dir: "state-files"
      )

      {
        hosted_zones: hosted_zones,
        internet_gateways: internet_gateways,
        subnets: subnets,
        nat_gateways: nat_gateways,
        vpcs: vpcs,
        route_tables: route_tables,
        route_table_associations: route_table_associations,
      }
    end

    private

    def hosted_zones
      (@aws.hosted_zones - @terraform.hosted_zones).sort
    end

    def internet_gateways
      (@aws.internet_gateways - @terraform.internet_gateways).sort
    end

    def subnets
      (@aws.subnets - @terraform.subnets).sort
    end

    def nat_gateways
      (@aws.nat_gateway_ids - @terraform.nat_gateway_ids).sort
    end

    def vpcs
      (@aws.vpc_ids - @terraform.vpc_ids).sort
    end

    def route_tables
      (@aws.route_tables - @terraform.route_tables).sort
    end

    def route_table_associations
      (@aws.route_table_associations - @terraform.route_table_associations).sort
    end
  end
end
