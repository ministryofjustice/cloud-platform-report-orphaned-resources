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
      s3_keys_list = s3client.bucket("cloud-platform-terraform-state").objects(prefix:'cloud-platform-network/', delimiter: '').collect(&:key)

      s3_keys_list.each do |each_key|
        begin
          #extract the name from the key
          each_key_list = each_key.split('/')
          statefile_name_output = "#{dir}/vpc-network-"+each_key_list[1]+".tfstate"
          download_state_from_s3(s3client, bucket, each_key, statefile_name_output)
        rescue => e
        end
      end
    end

  end
end
