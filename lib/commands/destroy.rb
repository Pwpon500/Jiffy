module Commands
    # Command to be called when the user wants to destroy created resources
    class Destroy < Commands::Base
        def destroy
            File.write("#{@conf['name']}.tf", @tf_conf)
            system('terraform init')
            detect_resources
            system('terraform destroy')
        end
    end
end
