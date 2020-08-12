module Aws

    #binding.pry
    # returns a aws client e.g ec2, s3 etc
    def get_aws_client(resource, region)
        case resource
        when "ec2"
            client = Aws::EC2::Client.new(region:region, profile: ENV["AWS_PROFILE"])
        when "s3"
            client = Aws::S3::Resource.new(region:region, profile: ENV["AWS_PROFILE"])
        when "route53"
            client = Aws::Route53::Client.new(region:region, profile: ENV["AWS_PROFILE"])
        when "asg"
            client = Aws::AutoScaling::Client.new(region:region, profile: ENV["AWS_PROFILE"])
        else
          pp resource+" Invalid resource provided"
        end
        return client 
    end

    #*******Methods to get resource data directly from AWS using ruby sdk***************

    def asg_for_arn(asg, auto_scaling_group_arn)
        filter = [ { name: "auto_scaling_group_arn", values: [auto_scaling_group_arn] } ]
        data = asg.describe_auto_scaling_groups(filter: filter)
        data.auto_scaling_groups.map { |each_asg| each_asg.auto_scaling_group_name }.sort
    end

    def get_hosted_zones(route53)
        hosted_zones = []
        data = route53.list_hosted_zones
        hosted_zones = data.hosted_zones.map { |zone| zone.name }.sort
        return hosted_zones 
    end
    
end