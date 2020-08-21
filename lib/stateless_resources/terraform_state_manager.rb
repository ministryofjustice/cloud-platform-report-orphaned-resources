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
      keys.map { |key| download_terraform_state(key) }
    end

    def download_terraform_states_for_prefixes(prefixes)
      objects_matching_prefixes(prefixes)
        .map { |object| download_terraform_state(object.key) }
    end

    private

    def download_terraform_state(key)
      name = key.split("/")[-2] # e.g. "cloud-platform-network/live-1/terraform.tfstate" -> "live-1"
      outfile = "#{dir}/#{name}.tfstate"
      unless FileTest.exists?(outfile)
        s3client.bucket(bucket).object(key).get(response_target: outfile)
      end
      outfile
    end

    def objects_matching_prefixes(prefixes)
      objects = s3client.bucket(bucket).objects

      objects.filter do |object|
        prefix = object.key.split("/").first
        prefixes.include?(prefix)
      end
    end

  end
end
