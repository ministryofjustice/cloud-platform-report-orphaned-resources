module StatelessResources
  class TerraformStateManager
    attr_reader :s3client, :bucket, :prefix, :dir

    def initialize(args)
      @s3client = args.fetch(:s3client)
      @bucket = args.fetch(:bucket)
      @prefix = args.fetch(:prefix)
      @dir = args.fetch(:dir)
    end

    def download_files
      keys = s3client.bucket("cloud-platform-terraform-state").objects(prefix: "cloud-platform-network/", delimiter: "").collect(&:key)

      keys.map do |key|
        name = key.split("/")[1] # e.g. "cloud-platform-network/live-1/terraform.tfstate" -> "live-1"
        outfile = "#{dir}/#{name}.tfstate"
        unless FileTest.exists?(outfile)
          s3client.bucket(bucket).object(key).get(response_target: outfile)
        end
        outfile
      end
    end
  end
end
