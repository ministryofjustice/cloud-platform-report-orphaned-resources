module OrphanedResources
  class Reporter
    def run
      s3 = Aws::S3::Resource.new(region: "eu-west-1", profile: ENV["AWS_PROFILE"])
      ec2 = Aws::EC2::Client.new(region: "eu-west-2", profile: ENV["AWS_PROFILE"])
      route53 = Aws::Route53::Client.new(region: "eu-west-2", profile: ENV["AWS_PROFILE"])

      @aws_resources = OrphanedResources::AwsResources.new(
        s3client: s3,
        ec2client: ec2,
        route53client: route53,
      )

      @network_tf = OrphanedResources::TerraformStateManager.new(
        s3client: s3,
        bucket: "cloud-platform-terraform-state",
        prefixes: ["cloud-platform-network"],
        cache_dir: "state-files"
      )

      # @main_tf = OrphanedResources::TerraformStateManager.new(
      #   s3client: s3,
      #   bucket: "cloud-platform-terraform-state",
      #   prefixes: ["cloud-platform"],
      #   cache_dir: "state-files"
      # )

      {
        internet_gateways: internet_gateways,
        subnets: subnets,
        nat_gateways: nat_gateways,
        vpcs: vpcs,
        route_tables: route_tables,
        route_table_associations: route_table_associations,
      }
    end

    private

    def internet_gateways
      (@aws_resources.internet_gateways - @network_tf.internet_gateways).sort
    end

    def subnets
      (@aws_resources.subnets - @network_tf.subnets).sort
    end

    def nat_gateways
      (@aws_resources.nat_gateway_ids - @network_tf.nat_gateway_ids).sort
    end

    def vpcs
      (@aws_resources.vpc_ids - @network_tf.vpc_ids).sort
    end

    def route_tables
      (@aws_resources.route_tables - @network_tf.route_tables).sort
    end

    def route_table_associations
      (@aws_resources.route_table_associations - @network_tf.route_table_associations).sort
    end
  end
end
