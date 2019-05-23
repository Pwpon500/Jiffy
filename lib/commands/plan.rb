module Commands
    # Command to be called when the user wants to see the plan for resource creation
    class Plan < Commands::Base
        def plan
            File.write("#{@conf['name']}.tf", @tf_conf)
            system('terraform init')
            detect_resources
            system('terraform plan')
        end
    end
end
